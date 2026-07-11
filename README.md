# ha-azure-ddns

Home Assistant add-on repository. The `azure-ddns` add-on keeps an Azure DNS A record in sync with your
public IP address. It references a pre-built Docker image
(`ghcr.io/classonconsultingab/ha-azure-ddns`) rather than building from a local Dockerfile.

## Branches

- **`main`** — source code, build scripts, and CI. This is the development branch; open PRs against it
  (note that GitHub will default new PRs' base branch to `publish` since that's the repository's default
  branch — remember to switch it to `main`).
- **`publish`** — the repository's default branch (what `https://github.com/ClassonConsultingAB/ha-azure-ddns`
  shows, and what Home Assistant's add-on store fetches). It's intentionally unprotected and has no
  history in common with `main` — every publish force-pushes a brand-new single commit containing only
  `LICENSE`, `README.md`, `repository.yaml`, and both add-ons' `config.yaml` files (`azure-ddns/` and
  `azure-ddns-beta/`). This keeps version-bump commits off `main` entirely, so they never conflict with
  branch protection there and never affect GitVersion's commit-based version calculation.

## Two add-on channels

The repository publishes two independent Home Assistant add-ons from the same `publish` branch:

- **`azure-ddns`** ("Azure DDNS") — the stable channel, bumped only by pushes to `main`
  (or a manual `workflow_dispatch` run against `main`).
- **`azure-ddns-beta`** ("Azure DDNS (Beta)") — bumped by pull request and feature-branch builds, so
  it always reflects the latest in-progress change. Only the channel being published is updated each
  run — the other channel's `config.yaml` is carried forward unchanged from the current `publish` branch.

## Publishing a new image version

Publishing is automated by [`.github/workflows/build-and-publish.yml`](.github/workflows/build-and-publish.yml):
every push, pull request, and manual dispatch computes the version with GitVersion, builds and pushes
the `linux/arm64` image (matching the Home Assistant Yellow) to
`ghcr.io/classonconsultingab/ha-azure-ddns:<version>`, and force-pushes the updated `publish` branch —
updating the `stable` channel when the ref is `main`, otherwise the `beta` channel.

To publish locally instead:

1. Make your code changes under `src/` (or the `Dockerfile`) and commit them to `main`.
2. Set a GitHub token with `write:packages` access as an environment variable:
   ```pwsh
   $env:GH_TOKEN = '<token>'
   ```
3. Build, push, and publish:
   ```pwsh
   ./scripts/build.ps1 -Push -Channel beta
   ```
   - Omit `-Push` to just build and test locally without pushing anything (the default).
   - `-Channel` is `beta` by default (so a local `-Push` never accidentally bumps the stable channel);
     pass `-Channel stable` deliberately to publish the stable add-on.
   - Use `-Version <x.y.z>` to force a specific version instead of the GitVersion-computed one.
   - Add `-Platform linux/amd64` too if testing on a non-arm64 dev machine.

## Installing/updating the add-on in Home Assistant

- **First-time setup**: In Home Assistant, go to Settings → Add-ons → Add-on store → ⋮ (top right) →
  Repositories, and add this repository's URL (`https://github.com/ClassonConsultingAB/ha-azure-ddns`).
  Then find "Azure DDNS" under the newly added repository and click Install.
- **Updating after a new image push**: Once a new version has been published, go to the add-on store,
  click ⋮ → Check for updates, and an update button will appear on the add-on. Click it — Home Assistant
  pulls the new image tag and restarts the add-on.
- **Verifying it's working**: Open the add-on's Logs tab and confirm the DNS record sync log output.


