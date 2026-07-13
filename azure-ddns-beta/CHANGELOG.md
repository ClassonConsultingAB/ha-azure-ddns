# Changelog

## [0.1.12-PullRequest0005-0004] - 2026-07-13

### Added

- Automated build-and-publish pipeline: pushing to `main` now builds, tests, builds/pushes the Docker image, and updates the `publish` branch with the new version automatically.
- A second, independently-versioned **Azure DDNS (Beta)** add-on that tracks pull request and feature-branch builds, installable side by side with the stable **Azure DDNS** add-on.
- Automated dependency updates via Dependabot (private NuGet feed and GitHub Actions), with auto-merge for minor/patch updates.

### Changed

- Docker image now built on Alpine for a smaller size, with APK dependencies updated when building the final stage.

## [0.1.12-PullRequest0005-0003] - 2026-07-13

### Added

- Automated build-and-publish pipeline: pushing to `main` now builds, tests, builds/pushes the Docker image, and updates the `publish` branch with the new version automatically.
- A second, independently-versioned **Azure DDNS (Beta)** add-on that tracks pull request and feature-branch builds, installable side by side with the stable **Azure DDNS** add-on.
- Automated dependency updates via Dependabot (private NuGet feed and GitHub Actions), with auto-merge for minor/patch updates.

### Changed

- Docker image now built on Alpine for a smaller size, with APK dependencies updated when building the final stage.
