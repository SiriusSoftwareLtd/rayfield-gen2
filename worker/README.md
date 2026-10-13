# gen2-loadstring

The Worker behind the two loadstring URLs.

| URL | Serves |
|---|---|
| `sirius.menu/gen2` | the current stable release |
| `sirius.menu/gen2-preview` | the rolling preview build, cut from `dev` |

Both read a release asset from GitHub. Stable reads `releases/latest`, which GitHub
defines as the newest release that is **not** a prerelease. Previews are published as
prereleases, so a preview can never become `latest` and can never reach the stable URL.

Deploy from this directory:

    npx wrangler deploy

The routes are declared in `wrangler.jsonc`, so deploying takes them with it.

## Skipping the cache

`?__fresh=1` skips the edge cache so a release can be confirmed live straight away. It
only works with the `x-cache-bypass` header set to the `CACHE_BYPASS_SECRET` Worker
secret; without the header the parameter is ignored. With the secret unset the bypass
is off entirely.

    npx wrangler secret put CACHE_BYPASS_SECRET
    curl -H "x-cache-bypass: $CACHE_BYPASS_SECRET" "https://sirius.menu/gen2?__fresh=1"
