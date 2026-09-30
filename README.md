# ha-azure-ddns

Home Assistant add-on repository. The `azure-ddns` add-on keeps an Azure DNS A record in sync with your public IP address. It references a pre-built Docker image (`ghcr.io/classonconsultingab/ha-azure-ddns`) rather than building from a local Dockerfile.

## Branches

- **`main`** — source code, build scripts, and CI. This is the development branch; open PRs against it (note that GitHub will default new PRs' base branch to `publish` since that's the repository's default branch — remember to switch it to `main`).
- **`publish`** — the repository's default branch (what `https://github.com/ClassonConsultingAB/ha-azure-ddns` shows, and what Home Assistant's add-on store fetches). It's intentionally unprotected and has no history in common with `main` — every publish adds a normal commit on top of it, updating only the published channel's add-on folder (`azure-ddns/` or `azure-ddns-beta/`) plus `LICENSE`, `README.md`, `repository.yaml`, and `.github/dependabot.yml`. This keeps version-bump commits off `main` entirely, so they never conflict with branch protection there and never affect GitVersion's commit-based version calculation. The branch also holds the [scheduler workflow](#scheduled-builds), which is maintained manually.

## Two add-on channels

The repository publishes two independent Home Assistant add-ons from the same `publish` branch:

- **`azure-ddns`** ("Azure DDNS") — the stable channel, bumped only by pushes to `main` (or a manual `workflow_dispatch` run against `main`).
- **`azure-ddns-beta`** ("Azure DDNS (Beta)") — bumped by pull request and feature-branch builds, so it always reflects the latest in-progress change. Only the channel being published is updated each run — the other channel's `config.yaml` is carried forward unchanged from the current `publish` branch.

## Updating the changelog

[`home-assistant/unreleased.json`](home-assistant/unreleased.json) holds the not-yet-released changes (see [keepachangelog.com](https://keepachangelog.com/en/1.1.0/) for the category conventions). It's a JSON object with all six standard categories always present as arrays — `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security` — leave a category's array empty if there's nothing to report under it:

```json
{
  "Added": [],
  "Changed": [],
  "Deprecated": [],
  "Removed": ["Something removed."],
  "Fixed": [],
  "Security": []
}
```

When publishing, `build.ps1` merges this delta with the published `CHANGELOG.md` on the `publish` branch. A changelog entry is only required when [production code](#what-triggers-a-release) has changed: a beta publish fails if `unreleased.json` is unchanged since the last stable release while human commits touching production paths exist. Dependabot commits touching production paths are added to `Changed` automatically.

## What triggers a release

A release (image push and `publish` branch update) only happens when something that affects production has changed since the last stable release (the commit recorded in `CHANGELOG.sha` on `publish`):

| Production (triggers release) | Non-production (never triggers release)                                                        |
| ----------------------------- | ---------------------------------------------------------------------------------------------- |
| `src/**`                      | `specs/**`                                                                                     |
| `Dockerfile`                  | `scripts/**`, `infra/**`                                                                       |
| `home-assistant/config.yaml`  | `.github/**` (workflows, Dependabot config)                                                    |
| `home-assistant/DOCS.md`      | `README.md`, `GitVersion.yml`, `AzureDdns.slnx`, `NuGet.Config`, `.gitignore`, `.dockerignore` |
| `home-assistant/icon.png`     | `home-assistant/unreleased.json`                                                               |

The list lives in `$productionPathSpecs` in [`scripts/build.ps1`](scripts/build.ps1); update it when adding files that end up in the image or the published add-on. When nothing in production has changed, `build.ps1 -Publish` still runs the tests and builds the image, but skips the registry login, the image push, and the `publish` branch update. Pass `-Force` (or tick **force** when running the workflow manually) to publish anyway. If there's no previous release commit, or it can't be found in history, production is assumed to have changed.

## Publishing a new image version

Publishing is automated by [`.github/workflows/build-and-publish.yml`](.github/workflows/build-and-publish.yml): every push, pull request, and manual dispatch computes the version with GitVersion, runs the tests, builds the `linux/arm64` image (matching the Home Assistant Yellow) and — if [production code changed](#what-triggers-a-release) — pushes it to `ghcr.io/classonconsultingab/ha-azure-ddns:<version>` and commits the updated `publish` branch, updating the `stable` channel when the ref is `main`, otherwise the `beta` channel. A manual dispatch has a **force** input to publish even without production changes.

To publish locally instead:

1. Make your code changes under `src/` (or the `Dockerfile`) and commit them to `main`.
2. Set a GitHub token with `write:packages` access as an environment variable:
   ```pwsh
   $env:GH_TOKEN = '<token>'
   ```
3. Build, push, and publish:
   ```pwsh
   ./scripts/build.ps1 -Publish -Channel beta
   ```
   - Omit `-Publish` to just build and test locally without pushing anything (the default).
   - Add `-Force` to publish even if no [production code](#what-triggers-a-release) has changed.
   - `-Channel` is `beta` by default (so a local `-Publish` never accidentally bumps the stable channel); pass `-Channel stable` deliberately to publish the stable add-on.
   - Use `-Version <x.y.z>` to force a specific version instead of the GitVersion-computed one.
   - Add `-Platform linux/amd64` too if testing on a non-arm64 dev machine.

### Scheduled builds

GitHub suppresses push-triggered runs caused by `GITHUB_TOKEN` (such as Dependabot auto-merges), so a weekly scheduled run picks those up. GitHub only runs scheduled workflows from the default branch (`publish`), so the scheduler (`.github/workflows/scheduled-build.yml`) lives only there and dispatches `build-and-publish.yml` on `main` (a stable channel run). It's maintained by hand on `publish`; `build.ps1` never touches it, since pushes made with `GITHUB_TOKEN` can't change workflow files.

## Installing/updating the add-on in Home Assistant

- **First-time setup**: In Home Assistant, go to Settings → Add-ons → Add-on store → ⋮ (top right) → Repositories, and add this repository's URL (`https://github.com/ClassonConsultingAB/ha-azure-ddns`). Then find "Azure DDNS" under the newly added repository and click Install.
- **Updating after a new image push**: Once a new version has been published, go to the add-on store, click ⋮ → Check for updates, and an update button will appear on the add-on. Click it — Home Assistant pulls the new image tag and restarts the add-on.
- **Verifying it's working**: Open the add-on's Logs tab and confirm the DNS record sync log output.

## Local development / integration tests

The integration tests in `specs/Specs/Integration` run against a real Azure DNS zone. The zone and its seed records are defined in the `infra` folder.

Example scenario:

```pwsh
./scripts/infra-up.ps1
dotnet test
./scripts/infra-down.ps1
```

- `infra-up.ps1` creates `rg-dns` and the zone, and resets the seed records. It is safe to re-run.
- `infra-down.ps1` deletes the whole `rg-dns` resource group and waits for the deletion to finish.
