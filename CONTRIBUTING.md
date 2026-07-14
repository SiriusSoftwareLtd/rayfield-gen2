# Contributing to Rayfield Gen 2

Thank you for helping improve Rayfield Gen 2. This guide takes a new contributor from a clean checkout to a pull request that is ready for review.

## Before you start

Use the repository's `dev` branch as the base for normal development. Search the [existing issues](https://github.com/SiriusSoftwareLtd/rayfield-gen2/issues) and pull requests before starting work. For a substantial change, open or discuss an issue first so the approach can be agreed before implementation.

### Prerequisites

You need:

- [Git](https://git-scm.com/).
- [Rokit](https://github.com/rojo-rbx/rokit), which installs the pinned command-line tools from `rokit.toml`.
- Bash and `curl`. On Windows, Git Bash is suitable.
- [Roblox Studio](https://create.roblox.com/docs/studio/setup) for changes that require runtime or visual validation.

Do not install separate versions of Rojo, Lune, Darklua, StyLua, Selene, or luau-lsp for this project. Rokit pins compatible versions.

## Set up a clean checkout

```bash
git clone https://github.com/SiriusSoftwareLtd/rayfield-gen2.git
cd rayfield-gen2
git switch dev
git pull --ff-only
```

Trust the tool sources declared by the repository, then install them:

```bash
rokit trust rojo-rbx/rojo
rokit trust lune-org/lune
rokit trust seaofvoices/darklua
rokit trust JohnnyMorganz/StyLua
rokit trust Kampfkarren/selene
rokit trust JohnnyMorganz/luau-lsp
rokit install
```

Create a focused branch from the updated `dev` branch:

```bash
git switch -c <issue-number>-<short-description>
```

For example: `git switch -c 42-fix-dropdown-focus`.

To open the project in Studio, start Rojo from the repository root:

```bash
rojo serve default.project.json
```

Then open Roblox Studio, connect the Rojo plugin to the server, and use Play mode to exercise `example.client.luau` and the affected behavior.

## Repository structure

| Path | Purpose |
| --- | --- |
| `src/init.luau` | Rayfield's module entry point. |
| `src/components/` | UI components and their behavior. |
| `src/themes/` | Built-in theme definitions. |
| `src/utility/` | Shared runtime, filesystem, asset, persistence, and other helpers. |
| `src/types.luau` | Shared Luau type definitions. |
| `tests/spec.luau` | Roblox-hosted tests for pure utilities. |
| `example.client.luau` | Example client and manual validation surface. |
| `scripts/check.sh` | The formatting, linting, and type-checking gate used by CI. |
| `default.project.json` | Rojo project used for Studio development. |
| `wax.project.json` | Project definition used for release bundling. |
| `assets/` | Repository-managed visual assets. |
| `.github/` | GitHub Actions and community configuration. |

Files such as `roblox.yml`, `globalTypes.d.luau`, `sourcemap.json`, and `build/` are generated locally and ignored by Git. Do not commit them.

## Required checks

Before every pull request, run the same gate as GitHub Actions:

```bash
bash scripts/check.sh
```

This command is required. It performs:

```bash
stylua --syntax Luau --check src
selene src
luau-lsp analyze --sourcemap=sourcemap.json --defs=globalTypes.d.luau --no-strict-dm-types src
```

The script generates Selene's Roblox standard library, the Rojo source map, and the luau-lsp Roblox definitions when necessary. Run the script itself instead of trying to reproduce its setup manually.

To apply formatting before running the required check:

```bash
stylua --syntax Luau src
```

### Tests

`tests/spec.luau` contains tests that depend on Roblox globals. They run in a Roblox host, not in the current static CI gate. For changes to covered utilities, update these tests and run them in Studio or the Roblox test runner used for the change. The module documents its invocation:

```luau
local passed, failed, report = require(path.to.spec)(game.ReplicatedStorage.Rayfield)
assert(failed == 0, report)
print(`{passed} tests passed`)
```

For component, theme, interaction, or executor-specific changes, test the affected path in Roblox Studio and describe the scenarios and results in the pull request. Tests and relevant manual validation are required for behavior changes; explain in the pull request when an automated test is not practical.

### Build checks

A local Rojo build is an optional but recommended project-mapping check:

```bash
rojo build default.project.json -o "Rayfield Gen2.rbxlx"
```

The release bundle is created automatically only for eligible changes on `main`. If your change affects bundling, you can validate it locally with:

```bash
lune run wax bundle output="build/bundled.luau" input="wax.project.json" minify=true
```

Neither optional build command replaces the required `bash scripts/check.sh` gate.

## Coding and documentation conventions

- Write Luau that follows the surrounding module's organization and naming.
- Use the repository's StyLua configuration: four spaces, Unix line endings, a 120-column width, and double quotes where StyLua selects a quote style.
- Keep the code compatible with the nonstrict Luau configuration in `.luaurc`. Add or preserve useful types where the surrounding API uses them.
- Do not bypass Selene warnings without a documented project-level reason.
- Keep components focused and place shared behavior in `src/utility/` rather than duplicating it.
- Preserve fallback behavior and capability checks for executor-specific globals.
- Document public API changes and update `example.client.luau` when contributors need an example.
- Update relevant comments, types, tests, and user-facing documentation in the same pull request as the behavior change.
- Avoid unrelated formatting or refactoring in a focused fix.

## Report a bug or propose a feature

Do not use a blank issue when a form applies:

- [Report a bug](https://github.com/SiriusSoftwareLtd/rayfield-gen2/issues/new?template=bug_report.yml)
- [Propose a feature](https://github.com/SiriusSoftwareLtd/rayfield-gen2/issues/new?template=feature_request.yml)
- [Open the issue-form chooser](https://github.com/SiriusSoftwareLtd/rayfield-gen2/issues/new/choose)

Include a minimal reproduction, environment details, relevant logs, and screenshots or recordings for visual bugs. Feature proposals should describe the problem, desired behavior, alternatives, and expected user impact.

Do not report security vulnerabilities in a public issue.

## Security vulnerabilities

Report suspected vulnerabilities privately through [GitHub's private vulnerability reporting form](https://github.com/SiriusSoftwareLtd/rayfield-gen2/security/advisories/new). Include reproduction steps, affected versions or commits, impact, and any suggested mitigation. Allow the maintainers time to investigate before public disclosure.

## Commits and pull requests

1. Branch from an up-to-date `dev` branch and keep the branch limited to one issue or coherent change.
2. Write concise, imperative commit subjects, such as `Fix dropdown focus handling`. Split unrelated changes into separate commits or pull requests.
3. Rebase or merge the latest `dev` branch when needed to resolve conflicts, without rewriting other contributors' work.
4. Run `bash scripts/check.sh` and all applicable tests and manual checks.
5. Open the pull request against `dev`. Complete the description with the change, motivation, user impact, validation, screenshots for UI changes, and any follow-up work.
6. Link the pull request to its issue with a closing keyword, for example `Closes #42`. Use `Refs #42` when the pull request should not close the issue.
7. Respond to review feedback and keep CI passing. Prefer follow-up commits during active review; maintainers may squash when merging.

Every behavior change must include tests where practical and documentation when it changes public APIs, configuration, examples, or user-visible behavior. Documentation-only changes should still verify links and commands against the current repository.

## Licensing and attribution

Rayfield Gen2 is licensed under the Mozilla Public License 2.0. By contributing, you agree your contributions are licensed under the same terms.

The repository does not currently define a Contributor License Agreement or Developer Certificate of Origin sign-off requirement. No additional contributor sign-off is required at this time.

Only submit work that you have the right to contribute. Do not copy code, assets, fonts, or other material with incompatible terms. Identify third-party material and its license or required attribution in the pull request, and preserve existing copyright and attribution notices. Maintainers may request licensing clarification before accepting a contribution.

By submitting a pull request, you represent that the contribution is your original work or that you have permission to submit it for inclusion in the project.
