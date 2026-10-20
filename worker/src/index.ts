// sirius.menu/gen2          -> the pinned stable release
// sirius.menu/gen2-preview  -> the rolling preview build
//
// Both channels fetch a release asset from GitHub and hand it back as plain text for a
// Roblox HTTP client to loadstring. Every executor that loads Rayfield Gen2 runs whatever
// this Worker returns, so what it fetches is pinned and checked:
//
//   GEN2_TAG               the release tag stable serves, e.g. "1.2.0". The asset is read
//                          from releases/download/<tag>/bundled.luau.
//   GEN2_SHA256_ALLOWLIST  comma-separated SHA-256 hex digests of the bundles allowed out.
//                          A body that hashes to anything else is never served or cached.
//   CACHE_BYPASS_SECRET    (secret) ?__fresh=1 only skips the cache when the
//                          x-cache-bypass header carries this value.
//
// Both vars live in wrangler.jsonc, so a release only reaches players once the pin there
// moves and the Worker is deployed. A set var that cannot be used (a malformed tag, an
// allowlist with no valid digest) fails closed: the last verified copy is served, or
// nothing is. Only with both vars unset does stable fall back to `releases/latest`, the
// newest release that is not a prerelease, with a warning logged on every origin fetch.
//
// Preview reads a rolling `preview` tag whose assets are replaced on every build, so it
// cannot be pinned. It gets the same shape check and says it is unverified in a header.
// The bundle stamps its version and commit into its header, so a report from a preview
// user still points at an exact commit.

interface Env {
  GEN2_TAG?: string;
  GEN2_SHA256_ALLOWLIST?: string;
  // Gates the ?__fresh=1 cache bypass. Unset, the bypass is off entirely.
  CACHE_BYPASS_SECRET?: string;
}

const OWNER_REPO = "SiriusSoftwareLtd/rayfield-gen2";
const RELEASES = `https://github.com/${OWNER_REPO}/releases`;

// How long a copy is served before GitHub is asked again.
const FRESH_SECONDS = 300;
// How long the last good copy stays usable once GitHub starts failing.
const STALE_SECONDS = 60 * 60 * 24 * 30;

// Bump to orphan every cache entry when the shape or lifetime of one changes. An entry is
// served back verbatim, so one written under older rules keeps them until it expires.
const CACHE_EPOCH = 3;

// The header that has to accompany ?__fresh=1, carrying CACHE_BYPASS_SECRET.
const BYPASS_HEADER = "x-cache-bypass";

// A release tag such as 1.2.0 or v1.2.0-rc.1. Anything else is refused rather than
// spliced into the upstream URL.
const TAG_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/;

const SECURITY_HEADERS: Record<string, string> = {
  "content-security-policy": "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
  "strict-transport-security": "max-age=31536000",
  "x-content-type-options": "nosniff",
  "x-frame-options": "DENY",
  "referrer-policy": "no-referrer",
};

type Plan =
  // fetch this asset; `allowlist` null means the body is served unverified
  | { ok: true; asset: string; ref: string; source: string; allowlist: Set<string> | null }
  // the config is set but unusable: never fetch, serve the last verified copy or nothing
  | { ok: false; ref: string; source: string; reason: string };

type ChannelName = "stable" | "preview";

const PATHS: Record<string, ChannelName> = {
  "/gen2": "stable",
  "/gen2-preview": "preview",
};

/**
 * Reads the allowlist var. Unset or blank is "no allowlist". Set but holding no valid
 * digest is a broken config, reported as an empty set so the caller fails closed instead
 * of treating a typo as permission to serve anything.
 */
function parseAllowlist(value: string | undefined): Set<string> | null {
  if (value === undefined || value.trim() === "") return null;
  const digests = value
    .split(",")
    .map((d) => d.trim().toLowerCase())
    .filter((d) => /^[0-9a-f]{64}$/.test(d));
  return new Set(digests);
}

function planStable(env: Env): Plan {
  const tagVar = env.GEN2_TAG?.trim() ?? "";
  const allowlist = parseAllowlist(env.GEN2_SHA256_ALLOWLIST);

  if (tagVar === "" && allowlist === null) {
    console.warn(JSON.stringify({ msg: "gen2 stable not pinned; serving releases/latest unverified" }));
    return { ok: true, asset: `${RELEASES}/latest/download/bundled.luau`, ref: "latest", source: "releases/latest", allowlist: null };
  }

  if (tagVar !== "" && !TAG_PATTERN.test(tagVar)) {
    return { ok: false, ref: "invalid", source: "releases/invalid", reason: "GEN2_TAG is malformed" };
  }
  if (allowlist !== null && allowlist.size === 0) {
    const ref = tagVar || "latest";
    return { ok: false, ref, source: `releases/${ref}`, reason: "GEN2_SHA256_ALLOWLIST has no valid digest" };
  }

  if (tagVar === "") {
    // An allowlist without a tag still checks whatever `latest` is.
    return { ok: true, asset: `${RELEASES}/latest/download/bundled.luau`, ref: "latest", source: "releases/latest", allowlist };
  }

  if (allowlist === null) {
    console.warn(JSON.stringify({ msg: "gen2 stable pinned without an allowlist; serving unverified", tag: tagVar }));
  }
  return {
    ok: true,
    asset: `${RELEASES}/download/${encodeURIComponent(tagVar)}/bundled.luau`,
    ref: tagVar,
    source: `releases/${tagVar}`,
    allowlist,
  };
}

function planPreview(): Plan {
  return { ok: true, asset: `${RELEASES}/download/preview/bundled.luau`, ref: "preview", source: "releases/preview", allowlist: null };
}

async function sha256Hex(body: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(body));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * Whether this request may skip the cache. Unauthenticated, ?__fresh=1 let anyone send every
 * request straight to GitHub - an easy way to burn our unauthenticated rate limit there and turn
 * the loader into a 502 for everyone. Both sides are hashed first so the comparison is constant-time
 * and fixed-length: timingSafeEqual throws on unequal lengths, which would leak the secret's length.
 */
async function bypassAllowed(request: Request, env: Env): Promise<boolean> {
  const secret = env.CACHE_BYPASS_SECRET;
  const presented = request.headers.get(BYPASS_HEADER);
  if (!secret || presented === null) return false;

  const encoder = new TextEncoder();
  const [a, b] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(presented)),
    crypto.subtle.digest("SHA-256", encoder.encode(secret)),
  ]);
  return crypto.subtle.timingSafeEqual(a, b);
}

/**
 * Every failure seen on loader paths has been HTML: a redirect body, a rate-limit notice,
 * a GitHub error page. The real bundle is hundreds of KB opening with a Lua comment.
 */
function looksLikeLuau(body: string): boolean {
  return body.length > 1024 && !body.trimStart().startsWith("<");
}

function withSecurityHeaders(response: Response): Response {
  const secured = new Response(response.body, response);
  for (const [name, value] of Object.entries(SECURITY_HEADERS)) secured.headers.set(name, value);
  return secured;
}

function plain(body: string, status: number, extra: Record<string, string> = {}): Response {
  return new Response(body, {
    status,
    headers: { "content-type": "text/plain; charset=utf-8", "cache-control": "no-store", ...extra },
  });
}

type Fetched = { body: string; digest: string } | { body: null; status: number };

async function fetchAsset(asset: string): Promise<Fetched> {
  let res: Response;
  try {
    // no-store: the response cache below is the only cache, and it only ever holds a body
    // that passed the checks. The subrequest cache would store a 404 or an error page too.
    res = await fetch(asset, { redirect: "follow", cache: "no-store" });
  } catch {
    return { body: null, status: 0 };
  }
  if (!res.ok) return { body: null, status: res.status };
  const body = await res.text();
  if (!looksLikeLuau(body)) return { body: null, status: -1 };
  return { body, digest: await sha256Hex(body) };
}

async function serve(channel: ChannelName, env: Env, ctx: ExecutionContext, bypass: boolean): Promise<Response> {
  const plan = channel === "stable" ? planStable(env) : planPreview();
  const integrity = plan.ok && plan.allowlist ? "sha256-allowlist" : "unverified";
  const allowlist = plan.ok ? plan.allowlist : parseAllowlist(env.GEN2_SHA256_ALLOWLIST);

  // A fixed host, so www and the apex share one entry. The ref is part of the key, so
  // moving the pin never serves a copy fetched under the old one.
  const cache = caches.default;
  const key = new Request(`https://sirius.menu/__gen2/${CACHE_EPOCH}/${channel}/${encodeURIComponent(plan.ref)}`, {
    method: "GET",
  });

  // Read even on the bypass path: bypass only skips serving it as fresh, so a bad origin
  // answer during a forced refresh still falls back to the last good copy.
  let cached = await cache.match(key);

  // An entry is only as good as the allowlist it is checked against now. One stored before
  // the list was set, or since dropped from it, is treated as absent. A broken allowlist
  // (set, no valid digest) matches nothing.
  if (cached && allowlist !== null && !allowlist.has(cached.headers.get("x-sha256") ?? "")) {
    console.log(JSON.stringify({ msg: "cached bundle not on allowlist", channel, ref: plan.ref }));
    cached = undefined;
  }

  const respond = (body: string, freshness: "fresh" | "stale", digest: string) =>
    new Response(body, {
      headers: {
        "content-type": "text/plain; charset=utf-8",
        "cache-control": `public, max-age=${FRESH_SECONDS}`,
        "x-rayfield-source": plan.source,
        "x-rayfield-cache": freshness,
        "x-rayfield-integrity": integrity,
        "x-rayfield-sha256": digest,
      },
    });

  const fetchedAt = cached ? Number(cached.headers.get("x-fetched-at") ?? 0) : 0;
  if (cached && !bypass && (Date.now() - fetchedAt) / 1000 < FRESH_SECONDS) {
    return respond(await cached.text(), "fresh", cached.headers.get("x-sha256") ?? "");
  }

  let upstreamStatus = "config";
  if (plan.ok) {
    const fetched = await fetchAsset(plan.asset);
    if (fetched.body !== null) {
      if (plan.allowlist && !plan.allowlist.has(fetched.digest)) {
        // Not a build we signed off. Treated exactly like an origin failure.
        console.error(JSON.stringify({ msg: "bundle failed allowlist check", channel, ref: plan.ref, sha256: fetched.digest }));
        upstreamStatus = "digest";
      } else {
        const entry = new Response(fetched.body, {
          headers: {
            "content-type": "text/plain; charset=utf-8",
            "cache-control": `public, max-age=${STALE_SECONDS}`,
            "x-fetched-at": String(Date.now()),
            "x-sha256": fetched.digest,
          },
        });
        ctx.waitUntil(cache.put(key, entry));
        return respond(fetched.body, "fresh", fetched.digest);
      }
    } else {
      upstreamStatus = fetched.status === -1 ? "shape" : String(fetched.status);
    }
  } else {
    console.error(JSON.stringify({ msg: "gen2 config unusable; not fetching", channel, reason: plan.reason }));
  }

  console.log(JSON.stringify({ msg: "origin fetch failed", channel, ref: plan.ref, upstream: upstreamStatus, servingStale: !!cached }));

  // GitHub is down, rate-limiting us, or served something that is not an allowed build.
  // The last good copy beats breaking every launch.
  if (cached) return respond(await cached.text(), "stale", cached.headers.get("x-sha256") ?? "");

  // Never cached: an outage that caches itself outlives the outage. Preview says which
  // channel is missing, because a preview tag that hasn't been cut yet looks identical to
  // GitHub being down.
  const what = channel === "preview" ? "No Rayfield Gen2 preview build is published" : "Rayfield Gen2 is unavailable right now";
  return plain(`-- ${what}, try again shortly\n`, 502, { "x-rayfield-upstream": upstreamStatus });
}

async function route(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return plain("-- Method not allowed\n", 405, { allow: "GET, HEAD" });
  }

  const url = new URL(request.url);
  // Trailing slashes only, no nesting: this Worker serves two fixed paths and anything
  // else is a typo to say no to, not one to serve the stable bundle for.
  const path = url.pathname.replace(/\/+$/, "") || "/";
  const channel = PATHS[path];
  if (!channel) return plain("-- Not found\n", 404);

  // ?__fresh=1 skips the cache read so a release can be confirmed live straight away. It
  // only counts with the x-cache-bypass header set to CACHE_BYPASS_SECRET; without it the
  // parameter is ignored and the request is served like any other.
  const bypass = url.searchParams.get("__fresh") === "1" && (await bypassAllowed(request, env));
  return serve(channel, env, ctx, bypass);
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    return withSecurityHeaders(await route(request, env, ctx));
  },
};
