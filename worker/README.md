# gen2-loadstring

The Worker behind the two loadstring URLs.

| URL | Serves |
|---|---|
| `sirius.menu/gen2` | the stable release pinned in `wrangler.jsonc` |
| `sirius.menu/gen2-preview` | the rolling preview build, cut from `dev` |

Both read `bundled.luau` from a GitHub release. `www.sirius.menu` serves the same paths
and shares the same cache entries.

Stable reads `releases/download/<GEN2_TAG>/bundled.luau` and only serves a body whose
SHA-256 is in `GEN2_SHA256_ALLOWLIST`. Both are vars in `wrangler.jsonc`. If GitHub fails
or sends anything else, the Worker serves the last copy that passed the check (kept for
30 days) or a 502. It never serves an unchecked body while either var is set: a malformed
tag or an allowlist with no valid digest is treated as a failure, not as "no check".
With both vars unset it falls back to `releases/latest` and logs a warning on every
fetch.

Preview reads the rolling `preview` prerelease. It can't be pinned because its assets
change on every green commit to `dev`, so its responses carry
`x-rayfield-integrity: unverified`.

Both channels refuse a body under 1 KB or one that starts with `<` (a GitHub error page).
Every response carries `nosniff`, a `default-src 'none'` CSP, `frame-ancestors 'none'`
and HSTS.

## Releasing a stable version

A new GitHub release no longer reaches players by itself. Landing a new `version.txt` on
`main` builds and publishes the release as before, then:

1. Open the Release Bundle run in the Actions tab. Its summary gives the bundle's SHA-256
   and the two var values.
2. Set `GEN2_TAG` and `GEN2_SHA256_ALLOWLIST` in `wrangler.jsonc` to those values.
3. Deploy, then check the live copy:

       npx wrangler deploy
       curl -s https://sirius.menu/gen2 | shasum -a 256

To roll back, put the previous tag and digest back and deploy.

## Deploying

Deploy from this directory:

    npx wrangler deploy

The routes and vars are declared in `wrangler.jsonc`, so deploying takes them with it.

Tests run on Node 24 with no install, from the repository root:

    node --test "worker/test/*.test.ts"

## Skipping the cache

`?__fresh=1` skips the edge cache so a release can be confirmed live straight away. It
only works with the `x-cache-bypass` header set to the `CACHE_BYPASS_SECRET` Worker
secret; without the header the parameter is ignored. With the secret unset the bypass
is off entirely. A bypassed request still falls back to the last good copy if GitHub
fails.

    npx wrangler secret put CACHE_BYPASS_SECRET
    curl -H "x-cache-bypass: $CACHE_BYPASS_SECRET" "https://sirius.menu/gen2?__fresh=1"
