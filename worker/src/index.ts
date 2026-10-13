// sirius.menu/gen2          -> the current stable release
// sirius.menu/gen2-preview  -> the rolling preview build
//
// Both channels are the same thing: fetch a release asset from GitHub and hand
// it back as plain text for a Roblox HTTP client to loadstring. The split is
// which release they read.
//
// Stable reads `releases/latest`, which GitHub defines as the newest release
// that is NOT a prerelease. That single rule is what keeps the two channels
// apart: a preview is published as a prerelease, so it can never become
// `latest` and can never reach anyone on the stable URL.
//
// Preview reads a rolling `preview` tag whose assets are replaced on every
// build. There is deliberately no history here - the bundle stamps its own
// version and commit into its header, so a report from a preview user still
// points at an exact commit.

interface Env {
  // Gates the ?__fresh=1 cache bypass. Unset, the bypass is off entirely.
  CACHE_BYPASS_SECRET?: string;
}

const OWNER_REPO = "SiriusSoftwareLtd/rayfield-gen2";
const EDGE_TTL = 300;
const CACHE_EPOCH = 2;

// The header that has to accompany ?__fresh=1, carrying CACHE_BYPASS_SECRET.
const BYPASS_HEADER = "x-cache-bypass";

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

type Channel = {
  asset: string;
  source: string;
};

const CHANNELS: Record<string, Channel> = {
  "/gen2": {
    asset: `https://github.com/${OWNER_REPO}/releases/latest/download/bundled.luau`,
    source: "releases/latest",
  },
  "/gen2-preview": {
    asset: `https://github.com/${OWNER_REPO}/releases/download/preview/bundled.luau`,
    source: "releases/preview",
  },
};

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("-- Method not allowed\n", {
        status: 405,
        headers: { "content-type": "text/plain; charset=utf-8" },
      });
    }

    // Trailing slashes only, no nesting: this Worker serves two fixed paths and
    // anything else is a typo we should say no to rather than quietly serve the
    // stable bundle for.
    const path = url.pathname.replace(/\/+$/, "") || "/";
    const channel = CHANNELS[path];

    if (!channel) {
      return new Response("-- Not found\n", {
        status: 404,
        headers: { "content-type": "text/plain; charset=utf-8" },
      });
    }

    // Keyed per channel. A shared key would let whichever channel was asked for
    // first answer for both until the entry expired.
    //
    // CACHE_EPOCH is part of the key so a deploy can orphan every existing entry. An
    // entry is served back verbatim, its own cache-control included, so one written
    // under an older TTL keeps re-asserting that TTL until it expires on its own terms
    // - a stale 4-hour entry outlived the 5-minute value here for hours. Bump this
    // whenever the shape or lifetime of a cached response changes.
    const cacheKey = new Request(`${url.origin}${path}?e=${CACHE_EPOCH}`, { method: "GET" });
    const cache = caches.default;

    // ?__fresh=1 skips the read so a release can be confirmed live immediately, rather
    // than waiting out a TTL and guessing which layer is holding the old copy. It only
    // counts with the x-cache-bypass header set to CACHE_BYPASS_SECRET; without it the
    // parameter is ignored and the request is served like any other.
    const bypass = url.searchParams.get("__fresh") === "1" && (await bypassAllowed(request, env));

    const cached = bypass ? undefined : await cache.match(cacheKey);
    if (cached) return cached;

    // No `cf.cacheEverything` here. The response cache below only ever stores a success,
    // whereas the subrequest cache stores whatever it gets - so a 404 from a preview tag that
    // hadn't been cut yet kept answering long after the release existed. One cache, successes only.
    const upstream = await fetch(channel.asset, { redirect: "follow" });

    if (!upstream.ok) {
      // Never cached: an outage that caches itself for five minutes outlives
      // the outage. Preview says which channel is missing, because a preview
      // tag that hasn't been cut yet looks identical to GitHub being down.
      const what = path === "/gen2-preview" ? "No Rayfield Gen2 preview build is published" : "Rayfield Gen2 is unavailable right now";
      return new Response(`-- ${what}, try again shortly\n`, {
        status: 502,
        headers: {
          "content-type": "text/plain; charset=utf-8",
          "cache-control": "no-store",
          // what GitHub actually said, so a failure can be diagnosed without a deploy
          "x-rayfield-upstream": String(upstream.status),
        },
      });
    }

    const response = new Response(await upstream.text(), {
      headers: {
        "content-type": "text/plain; charset=utf-8",
        "cache-control": `public, max-age=${EDGE_TTL}`,
        "x-rayfield-source": channel.source,
      },
    });

    ctx.waitUntil(cache.put(cacheKey, response.clone()));
    return response;
  },
};
