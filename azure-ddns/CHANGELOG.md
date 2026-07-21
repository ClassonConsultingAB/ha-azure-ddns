# Changelog

## [0.1.17] - 2026-07-21

### Added

- Scheduled publish of dependency updates.

### Changed

- Bump Microsoft.NET.Test.Sdk from 18.7.0 to 18.8.1 (#9).
- Bump dependabot/fetch-metadata from 2 to 3 in the all group (#8).

## [0.1.14] - 2026-07-18

### Added

### Fixed

- Dependabot config is now also published to the `publish` branch (the repository's default branch, which GitHub reads Dependabot configuration from) and targets `main` for dependency updates.

## [0.1.13] - 2026-07-15

### Added

- Note in README.md about that source code live on the main branch of this repository.

## [0.1.12] - 2026-07-15

### Added

- Automated build-and-publish pipeline: pushing to `main` now builds, tests, builds/pushes the Docker image, and updates the `publish` branch with the new version automatically.
- A second, independently-versioned **Azure DDNS (Beta)** add-on that tracks pull request and feature-branch builds, installable side by side with the stable **Azure DDNS** add-on.
- Automated dependency updates via Dependabot (private NuGet feed and GitHub Actions), with auto-merge for minor/patch updates.

### Changed

- Docker image now built on Alpine for a smaller size, with APK dependencies updated when building the final stage.
