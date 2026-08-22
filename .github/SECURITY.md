# Security Policy

Quill is a small, actively-developed, pre-1.0 project maintained by one person. This policy sets expectations accordingly, not as a template copied from a larger project with a dedicated security team.

## Supported Versions

Only the **latest released version** (currently `v0.11.3`, see [Releases](https://github.com/imtamiliniyan/quill/releases)) is supported with security fixes. There is no long-term support branch — point releases ship frequently, and a fix lands in the next tagged version rather than being backported.

## Reporting a Vulnerability

Please **do not open a public GitHub issue** for a security vulnerability — that discloses it to everyone, including anyone who might exploit it, before a fix exists.

Instead, report privately using either of these:

- **GitHub's private vulnerability reporting**: use the [Report a vulnerability](https://github.com/imtamiliniyan/quill/security/advisories/new) button under this repo's Security tab (Security → Advisories → Report a vulnerability). This is the preferred path — it keeps the report and any discussion private until a fix ships.
- **Email**: [tamil@iniyan.pro](mailto:tamil@iniyan.pro), the same contact address used for Quill's in-app Feedback and the landing site's privacy/terms pages. Include what you found, how to reproduce it, and its potential impact.

You should expect an initial response within a few days. Quill is a side project, not a funded security team, so please be patient: a fix's timeline depends on severity and complexity, but confirmed vulnerabilities get prioritized over regular feature work.

## What's in Scope

Quill is a local-first macOS app. Realistic areas of concern:

- The dictation-cleanup/enhancement pipeline (`Sources/quill/Style/`) mishandling or leaking dictated text, especially anything that could send local-only data to a cloud provider without the user's explicit BYOK opt-in.
- API key handling (`Sources/quill/Settings/APIKeyStore.swift`) — keys are stored in the macOS Keychain, never written to disk in plain text; a bug that changes that is a real vulnerability, not a hardening suggestion.
- The auto-update mechanism (`AppUpdater.swift`, `appcast.xml`, Sparkle's EdDSA signing) — anything that could let an unsigned or tampered update be accepted.
- Text injection (`Sources/quill/Input/`) — anything that could inject into the wrong app/window, or be triggered without the user's own dictation.

## What's Out of Scope

- Quill is **not notarized** (no Apple Developer Program enrollment). Gatekeeper's warning on a direct `.dmg` download is expected, documented behavior, not a vulnerability to report.
- Denial-of-service reports against a local, single-user desktop app (e.g. "the app uses a lot of memory if you feed it a huge file") are generally not actionable the way they would be for a server.

Thank you for helping keep Quill and its users safe.
