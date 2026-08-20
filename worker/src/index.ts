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

interface Env {}

const OWNER_REPO = "SiriusSoftwareLtd/rayfield-gen2";
const EDGE_TTL = 300;

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
    const cacheKey = new Request(url.origin + path, { method: "GET" });
    const cache = caches.default;

    const cached = await cache.match(cacheKey);
    if (cached) return cached;

    const upstream = await fetch(channel.asset, {
      redirect: "follow",
      cf: { cacheEverything: true, cacheTtl: EDGE_TTL },
    });

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
