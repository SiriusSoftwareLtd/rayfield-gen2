<!--
Use this template for a new capability or public behavior change. Target `dev`.
Do not include vulnerability details here; report them privately at
https://github.com/SiriusSoftwareLtd/rayfield-gen2/security/advisories/new.
-->

## Summary

<!-- What feature is being added and what user or developer outcome does it provide? -->

## Related issue

<!-- Use "Closes #123" when merging should close the issue or "Refs #123" otherwise. -->

Closes #

## Problem

<!-- Describe the problem or limitation being addressed. -->

## Proposed behavior

<!-- Describe the user-facing behavior and the important implementation decisions. -->

## API or usage example

<!-- Show the intended Luau API or workflow. Write "Not applicable" when no public API changes. -->

```luau
-- Example
```

## Alternatives considered

<!-- What other approaches were considered, and why was this approach selected? -->

## Compatibility and migration

<!--
Cover existing public APIs, configuration, themes, persisted data, Roblox Studio,
supported executors, deprecations, and rollout concerns.
-->

- Breaking change: <!-- Yes or no -->
- Backward compatible: <!-- Yes or no -->
- Migration required: <!-- Yes or no; include instructions when applicable -->
- Compatibility notes:

## Validation

- [ ] I ran `bash scripts/check.sh`.
- [ ] I added or updated automated or Roblox-hosted tests where practical.
- [ ] I completed applicable manual testing in Roblox Studio or the affected environment.
- [ ] I tested existing behavior for regressions.
- [ ] I tested relevant compatibility paths.

### Test scenarios and results

<!-- Include commands, environments, scenarios, results, and known limitations. -->

-

## Documentation

<!-- List updated public documentation, examples, comments, and type definitions. -->

-

## UI evidence

<!-- UI features require before-and-after screenshots or recordings. Otherwise write "Not applicable." -->

| Before | After |
| --- | --- |
| <!-- Image or recording --> | <!-- Image or recording --> |

## Checklist

- [ ] This pull request targets `dev`.
- [ ] The feature is focused and contains no unrelated changes.
- [ ] I reviewed my own changes.
- [ ] Tests cover the new behavior and relevant regressions where practical.
- [ ] Public APIs, examples, types, and documentation match the resulting behavior.
- [ ] Breaking changes and migration steps are clearly documented.
- [ ] I did not commit generated files such as `roblox.yml`, `sourcemap.json`, `globalTypes.d.luau`, or `build/`.
- [ ] This pull request contains no publicly disclosed vulnerability details.
