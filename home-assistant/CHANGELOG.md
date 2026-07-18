# Changelog

This file only ever holds the not-yet-released changes under "Unreleased" (see
[keepachangelog.com](https://keepachangelog.com/en/1.1.0/)). When publishing, `build.ps1` files this section under a version heading and prepends it to whatever was already published for the channel, so the published `CHANGELOG.md` accumulates full history while this source file stays a small, mechanical "Unreleased" section — update it as part of any PR that changes user-facing behavior.

## Unreleased

### Added

### Fixed

- Dependabot config is now also published to the `publish` branch (the repository's default branch, which GitHub reads Dependabot configuration from) and targets `main` for dependency updates.
