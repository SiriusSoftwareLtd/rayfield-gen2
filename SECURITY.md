# Security Policy

The Rayfield Gen 2 maintainers take security reports seriously. Thank you for reporting suspected vulnerabilities responsibly.

## Supported versions and branches

| Version or branch | Security support |
| --- | --- |
| `main` | Supported as the latest stable version |
| `dev` | Supported as the current development version |
| Older releases, tags, forks, and other branches | Not supported |

Security fixes may be developed privately before being applied to `dev` and `main`. Users should update to the newest supported revision after a security fix is released.

## Reporting a vulnerability

**Do not report security vulnerabilities through public GitHub issues, discussions, pull requests, comments, or other public channels.**

Submit suspected vulnerabilities through [GitHub's private vulnerability reporting form](https://github.com/SiriusSoftwareLtd/rayfield-gen2/security/advisories/new). Reports submitted there are visible only to authorized repository security managers and administrators.

If the private reporting form is unavailable, do not disclose vulnerability details publicly. Wait until the private reporting channel becomes available.

## What to include

Please provide as much of the following information as possible:

- A clear description of the vulnerability or detection.
- The affected version, branch, or commit.
- The environment in which the issue was observed.
- Steps required to reproduce the issue.
- Minimal proof-of-concept code, when appropriate.
- The potential security impact and who could be affected.
- Any known mitigations or workarounds.
- Whether the issue has been disclosed elsewhere.
- Your preferred contact method.
- The name or handle you would like used for public credit, or whether you prefer to remain anonymous.

For reports involving anti-cheat, platform-integrity, anti-malware, or other security-tool detections, also include as much of this information as possible:

- The name and version of the detecting system.
- The exact warning, detection name, message, or error code.
- The date and approximate time of the detection.
- Whether the detected code was an unmodified official Rayfield Gen 2 release.
- The Rayfield Gen 2 commit, release, or file that triggered the detection.
- A minimal reproduction that does not attempt to bypass the detecting system.
- Relevant logs or screenshots with credentials and personal information removed.
- Whether the detection can be reproduced without an executor, injector, modified fork, obfuscator, or unrelated third-party software.

Remove secrets, credentials, personal data, and unrelated sensitive information from submitted evidence.

## Response process and timelines

The maintainers will aim to:

- Acknowledge a report within five business days.
- Provide an initial assessment or request additional information within ten business days of acknowledgment.
- Provide a status update at least every fourteen calendar days while an actionable report remains unresolved.
- Notify the reporter if circumstances prevent the maintainers from meeting these targets.

Investigation and remediation time will depend on the issue's complexity, severity, affected versions, and coordination requirements.

Reports may be closed if they cannot be reproduced, are outside the scope of this policy, or do not present a meaningful security risk. The reason will be explained privately.

## Coordinated disclosure

Please allow the maintainers a reasonable opportunity to investigate and remediate the vulnerability before disclosing it publicly.

The maintainers and reporter should coordinate:

- The scope and severity of the vulnerability.
- Mitigations and release timing.
- The contents and timing of any public advisory.
- Reporter attribution.

There is no automatic disclosure deadline. A disclosure date should be agreed upon for each report based on its severity, remediation progress, and risk to users.

If coordination becomes difficult, both parties should continue communicating privately and make a good-faith effort to avoid exposing users to unnecessary risk.

## Vulnerabilities and detections that may qualify

Examples of potentially qualifying reports include:

- Unauthorized code execution or injection caused by Rayfield Gen 2.
- Unauthorized access to or modification of files, configuration, persisted data, or other protected resources.
- Exposure of credentials, tokens, personal data, or other sensitive information.
- Bypasses of intended trust or security boundaries within Rayfield Gen 2.
- A vulnerability in build, update, release, or dependency handling that could distribute malicious code.
- A denial-of-service condition with a practical and significant impact on supported use.
- A vulnerable dependency with a demonstrated, exploitable impact on Rayfield Gen 2.
- Unexpected behavior in an unmodified official release that causes a reproducible anti-cheat, platform-integrity, anti-malware, or security-tool detection.
- Evidence that official Rayfield Gen 2 code has been compromised, tampered with, or distributed from an unauthorized source.
- A detection indicating that an official release performs undocumented or unsafe operations.

A detection does not automatically establish that Rayfield Gen 2 contains a security vulnerability. The maintainers will investigate reproducible reports involving unmodified official code.

This list is not exhaustive. If you are uncertain whether an issue qualifies, report it privately.

## Out-of-scope reports

The following are generally outside the scope of this policy:

- Requests to bypass, disable, evade, or weaken anti-cheat, anti-tamper, moderation, anti-malware, platform-integrity, or other security controls.
- Requests to make Rayfield Gen 2, an executor, or another tool undetectable.
- Detection caused solely by an executor, injector, exploit, modified fork, obfuscator, loader, script hub, or unrelated third-party software.
- Account enforcement, moderation, suspensions, or bans without evidence that an unmodified official Rayfield Gen 2 release caused an unintended security issue.
- Reports that only state that software was detected, without the detection details and evidence needed to reproduce it.
- Ordinary bugs without a confidentiality, integrity, availability, or meaningful user-safety impact.
- Feature requests, usability concerns, compatibility problems, or documentation errors.
- Vulnerabilities that affect only unsupported versions or modified forks.
- Issues in Roblox, an executor, or another third-party service that are not caused by Rayfield Gen 2.
- Reports based solely on automated scanner output without evidence of an exploitable or reproducible impact.
- Theoretical concerns without a plausible attack scenario.
- Missing security hardening or best practices without a demonstrated vulnerability.
- Social engineering, phishing, physical attacks, or attacks against maintainers or users.
- Denial-of-service, resource-exhaustion, or high-volume testing performed without prior written authorization.
- Reports requiring prior compromise of the victim's environment when no additional security boundary is crossed.

Non-security bugs, feature requests, and ordinary compatibility problems should use the repository's public issue forms. Do not publicly post logs or screenshots that reveal sensitive security details.

## Security-testing boundaries

When researching a potential vulnerability or detection:

- Test only with accounts, systems, and data you own or have explicit permission to use.
- Limit testing to the minimum necessary to confirm the issue.
- Use an unmodified official Rayfield Gen 2 release whenever possible.
- Do not attempt to bypass, disable, evade, or interfere with anti-cheat, anti-tamper, moderation, anti-malware, or platform-integrity systems.
- Do not develop or distribute detection-evasion techniques as part of a report.
- Stop testing if you encounter personal data, credentials, secrets, or other information that is not yours.
- Do not retain, alter, delete, or disclose data obtained unintentionally.
- Do not degrade service availability or perform destructive, persistent, high-volume, or resource-exhaustion testing.
- Do not use social engineering, phishing, malware, or attacks against maintainers, contributors, or users.
- Do not test Roblox, GitHub, documentation hosts, package registries, anti-cheat providers, or other third-party systems under this policy.
- Comply with applicable laws and the terms governing any third-party platform involved.

If demonstrating impact would require crossing one of these boundaries, describe the suspected impact without performing that action and request guidance through the private reporting channel.

## Public credit

Reporters may receive public credit after remediation and coordinated disclosure. With the reporter's permission, the maintainers may include the reporter's chosen name or handle in a GitHub security advisory, release notes, or another public acknowledgment.

Reporters may remain anonymous or decline public credit. Attribution details will not be published without permission.

Public credit may be withheld when testing violated this policy, harmed users or systems, attempted to evade security controls, or involved public disclosure before reasonable coordination.
