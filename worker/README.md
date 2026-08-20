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
