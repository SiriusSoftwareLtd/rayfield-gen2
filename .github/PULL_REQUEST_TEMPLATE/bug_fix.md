<!--
Use this template for a defect or regression. Target `dev`.

Submit standalone documentation changes to https://github.com/SiriusSoftwareLtd/docs
and link companion documentation work below when this fix affects public documentation.

Do not include vulnerability details here; report them privately at
https://github.com/SiriusSoftwareLtd/rayfield-gen2/security/advisories/new.
-->

## Summary

<!-- What was broken, what does this fix, and who is affected? -->

## Related issue

<!-- Use "Closes #123" when merging should close the issue or "Refs #123" otherwise. -->

Closes #

## Reproduction

### Previous behavior

<!-- Include the smallest reproducible example and the actual result. -->

1.
2.
3.

### Expected behavior

<!-- What should happen instead? -->

## Root cause

<!-- Explain the underlying cause, not only the visible symptom. -->

## Fix

<!-- Describe the correction and why this approach was selected. -->

## Compatibility and risk

<!--
Cover public APIs, configuration, themes, persisted data, Roblox Studio,
supported executors, regressions, and any migration requirements.
-->

- Breaking change: <!-- Yes or no -->
- Migration required: <!-- Yes or no; include instructions when applicable -->
- Risk and compatibility notes:

## Validation

- [ ] I ran `make ci`, including the coverage threshold.
- [ ] I added or updated regression coverage where practical.
- [ ] I reproduced the previous failure and confirmed the corrected behavior.
- [ ] I completed applicable Roblox Studio or environment-specific manual testing.
- [ ] I tested relevant compatibility paths.

### Test scenarios and results

<!-- Include commands, environments, before-and-after results, and any limitations. -->

-

## Documentation coordination

<!--
Standalone public documentation changes belong in https://github.com/SiriusSoftwareLtd/docs.
Link the companion docs issue or pull request when this fix affects public documentation.
Note any code comments, examples, or type definitions updated here.
-->

- Public documentation impact: <!-- None or describe the required update -->
- Companion docs issue or pull request: <!-- Link or "Not applicable" -->
- In-repository comments, examples, or types updated:

## UI evidence

<!-- UI fixes require before-and-after screenshots or recordings. Otherwise write "Not applicable." -->

| Before | After |
| --- | --- |
| <!-- Image or recording --> | <!-- Image or recording --> |

## Checklist

- [ ] This pull request targets `dev`.
- [ ] The fix is focused and contains no unrelated changes.
- [ ] I reviewed my own changes.
- [ ] The regression is covered by tests where practical.
- [ ] Coverage did not drop below the enforced threshold.
- [ ] Public documentation is unaffected, or I linked companion work in `SiriusSoftwareLtd/docs`.
- [ ] Required code comments, examples, and types match the corrected behavior.
- [ ] I did not commit standalone documentation changes that belong in the docs repository.
- [ ] I did not commit generated files such as `roblox.yml`, `sourcemap.json`, `globalTypes.d.luau`, or `build/`.
- [ ] This pull request contains no publicly disclosed vulnerability details.
