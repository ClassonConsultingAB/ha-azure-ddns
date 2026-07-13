# Changelog

This file only ever holds the not-yet-released changes under "Unreleased" (see
[keepachangelog.com](https://keepachangelog.com/en/1.1.0/)). When publishing, `build.ps1` files this section under a version heading and prepends it to whatever was already published for the channel, so the published `CHANGELOG.md` accumulates full history while this source file stays a small, mechanical "Unreleased" section — update it as part of any PR that changes user-facing behavior.

## Unreleased

### Added

- Automated build-and-publish pipeline: pushing to `main` now builds, tests, builds/pushes the Docker image, and updates the `publish` branch with the new version automatically.
- A second, independently-versioned **Azure DDNS (Beta)** add-on that tracks pull request and feature-branch builds, installable side by side with the stable **Azure DDNS** add-on.
- Automated dependency updates via Dependabot (private NuGet feed and GitHub Actions), with auto-merge for minor/patch updates.

### Changed

- Docker image now built on Alpine for a smaller size, with APK dependencies updated when building the final stage.
