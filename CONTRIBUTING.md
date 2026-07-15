# Contributing to Rayfield Gen 2

Thank you for helping improve Rayfield Gen 2. This guide takes a new contributor from a clean checkout to a pull request that is ready for review.

## Before you start

Use the repository's `dev` branch as the base for normal development. Search the [existing issues](https://github.com/SiriusSoftwareLtd/rayfield-gen2/issues) and pull requests before starting work. For a substantial change, open or discuss an issue first so the approach can be agreed before implementation.

### Prerequisites

You need:

- [Git](https://git-scm.com/).
- [Rokit](https://github.com/rojo-rbx/rokit), which installs the pinned command-line tools from `rokit.toml`.
- GNU Make and `curl`.
- [Roblox Studio](https://create.roblox.com/docs/studio/setup) for changes that require runtime or visual validation.

Do not install separate versions of Rojo, Lune, Darklua, StyLua, Selene, luau-lsp, or TestEZ for this project. Rokit pins compatible versions.
On Windows, inspect `%USERPROFILE%\.rokit\tool-storage` when troubleshooting the Rokit-managed CLI tools instead of relying on system-wide installs.

## Set up a clean checkout

```bash
git clone https://github.com/SiriusSoftwareLtd/rayfield-gen2.git
cd rayfield-gen2
git switch dev
git pull --ff-only
```

Trust the tool sources declared by the repository, then install them:

```bash
make install
```

Enable the repository's Git hooks:

```bash
make hooks
```

The pre-commit hook runs `make check` and then refreshes `coverage-baseline.json` with `make coverage-baseline`.
If the baseline changes, stage the refreshed file and commit again.

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
| `tests/components/` | TestEZ specs for component behavior. |
| `tests/integration/` | Integration specs for Rayfield workflows. |
| `tests/runner/` | Specs for the local runner and coverage instrumentation. |
| `tests/utility/` | TestEZ specs for shared utility modules. |
| `tests/run.server.luau` | Roblox Studio TestEZ runner for the test project. |
| `scripts/run-tests.luau` | CI/local runner for the TestEZ-style spec files and coverage gate. |
| `coverage-baseline.json` | Current measured coverage baseline and known automation gaps. |
| `example.client.luau` | Example client and manual validation surface. |
| `Makefile` | Local development and CI command entry points. |
| `rokit.toml` | Pinned contributor and CI toolchain. |
| `default.project.json` | Rojo project used for Studio development. |
| `test.project.json` | Rojo project used for Roblox Studio test runs. |
| `wax.project.json` | Project definition used for release bundling. |
| `assets/` | Repository-managed visual assets. |
| `.github/` | GitHub Actions and community configuration. |

Files such as `build/`, `coverage/`, `sourcemap.json`, `roblox.yml`, `globalTypes.d.luau`, `Rayfield Gen2.rbxlx`, and `Rayfield Gen2 Tests.rbxlx` are generated locally and ignored by Git. Do not commit them.

## Required checks

Before every pull request, run the same gate as GitHub Actions:

```bash
make ci
```

This command is required. `make ci` is an alias for `make check`, and GitHub Actions runs it on every push and pull request after installing the Rokit toolchain. It performs:

```bash
stylua --syntax Luau --check src tests scripts
selene generate-roblox-std
selene src tests
rojo sourcemap default.project.json -o sourcemap.json
curl -fsSL -o globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
luau-lsp analyze --sourcemap=sourcemap.json --defs=globalTypes.d.luau --no-strict-dm-types src tests/components tests/integration tests/runner tests/utility
lune run scripts/run-tests.luau -- --coverage-threshold=70
```

The Makefile target generates Selene's Roblox standard library, the Rojo source map, the luau-lsp Roblox definitions, and coverage reports. The test runner receives a 70% minimum coverage threshold and also enforces the higher tracked line coverage in `coverage-baseline.json` for the current scope.

To apply formatting before running the required check:

```bash
make format
```

### Tests

Tests live under `tests/components/`, `tests/integration/`, `tests/runner/`, and `tests/utility/` as TestEZ-style `.spec.luau` ModuleScripts. Each spec returns a function and uses TestEZ's `describe`, `it`, `expect`, and lifecycle hooks. Keep spec names ending in `.spec` after Rojo maps them into Studio because the Avant Plugin discovers tests by that suffix.

Run the CI/local unit test path with:

```bash
make test
```

This uses Lune to execute the same spec modules with a small Roblox datatype/service shim, so it can run in CI without opening Roblox Studio.

To run the same path with Rayfield logs enabled:

```bash
make test-verbose
```

`make test` also writes:

```bash
coverage/coverage.txt
coverage/coverage-summary.json
```

The coverage report is generated from the default `src` scope tracked in `coverage-baseline.json`. Pull requests fail when tests fail or when line coverage for that scope drops below the effective threshold. To experiment with a stricter local threshold:

```bash
make test COVERAGE_THRESHOLD=80
```

Update `coverage-baseline.json` when the measured baseline or intentionally enforced scope changes. Do not commit generated files under `coverage/`.

Use the dedicated target when the tracked baseline intentionally needs to change:

```bash
make coverage-baseline
```

To produce coverage reports without changing the tracked baseline:

```bash
make coverage
```

To run tests in Roblox Studio without Avant, build the test place:

```bash
make test-place
```

Open `Rayfield Gen2 Tests.rbxlx` in Roblox Studio. The `ServerScriptService.RunTests` script requires `ReplicatedStorage.TestEZ`, runs `ReplicatedStorage.Tests`, and errors if any TestEZ test fails.

To run tests with the Avant Plugin, either open the place from `make test-place` or run `make testez-model` before serving `test.project.json` with Rojo. In Studio, use Avant's `Unit Tests` window. Avant currently supports TestEZ and lists every `ModuleScript` whose name ends with `.spec`.

The Studio test project downloads `build/TestEZ.rbxm` from the pinned TestEZ release when `make test-place` is run. The model is generated local output and must not be committed.

For component, theme, interaction, or executor-specific changes, test the affected path in Roblox Studio and describe the scenarios and results in the pull request. Tests and relevant manual validation are required for behavior changes; explain in the pull request when an automated test is not practical.

### Build checks

A local Rojo build is an optional but recommended project-mapping check:

```bash
make build
```

The release bundle is created automatically from published GitHub releases when the release tag matches `version.txt` and points to a commit on the repository default branch. If your change affects bundling, you can validate it locally with:

```bash
make bundle
```

Neither optional build command replaces the required `make ci` gate.

Use `make serve` for the normal Rojo development server, `make dev` to run Rojo serve alongside source map watching, and `make clean` to remove ignored local outputs.

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
2. Write every commit message using [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/): `<type>[optional scope][!]: <description>`. Keep descriptions concise and imperative. Use `feat` for features, `fix` for bug fixes, and other clear types such as `docs`, `test`, `refactor`, `perf`, `build`, `ci`, `style`, or `chore` when they describe the change. Split unrelated changes into separate commits or pull requests.

   Examples:

   - `fix: correct dropdown focus handling`
   - `feat(theme): add high contrast palette`
   - `docs: update contributor guide`
   - `refactor(window)!: remove legacy resize behavior`

   Mark breaking changes with `!` before the colon, as shown above, or with a `BREAKING CHANGE:` footer after the body.
3. Rebase or merge the latest `dev` branch when needed to resolve conflicts, without rewriting other contributors' work.
4. Run `make ci` and all applicable tests and manual checks.
5. Open the pull request against `dev`. Complete the selected pull request template with the change, motivation, user impact, validation, compatibility notes, UI evidence for UI changes, and any follow-up work.
6. Link the pull request to its issue with a closing keyword, for example `Closes #42`. Use `Refs #42` when the pull request should not close the issue.
7. Respond to review feedback and keep CI passing. Prefer follow-up commits during active review; maintainers may squash when merging.

Every behavior change must include tests where practical and documentation when it changes public APIs, configuration, examples, or user-visible behavior. Standalone public documentation changes belong in [`SiriusSoftwareLtd/docs`](https://github.com/SiriusSoftwareLtd/docs); link companion documentation work in the pull request when a code change affects public docs. Documentation-only changes should still verify links and commands against the current repository.

## Licensing and attribution

Rayfield Gen2 is licensed under the Mozilla Public License 2.0. By contributing, you agree your contributions are licensed under the same terms.

The repository does not currently define a Contributor License Agreement or Developer Certificate of Origin sign-off requirement. No additional contributor sign-off is required at this time.

Only submit work that you have the right to contribute. Do not copy code, assets, fonts, or other material with incompatible terms. Identify third-party material and its license or required attribution in the pull request, and preserve existing copyright and attribution notices. Maintainers may request licensing clarification before accepting a contribution.

By submitting a pull request, you represent that the contribution is your original work or that you have permission to submit it for inclusion in the project.
