# ha-azure-ddns

Home Assistant add-on repository. The `azure-ddns` add-on keeps an Azure DNS A record in sync with your
public IP address. It references a pre-built Docker image
(`ghcr.io/classonconsultingab/ha-azure-ddns`) rather than building from a local Dockerfile — updating
the add-on means pushing a new image tag and bumping `version` in `azure-ddns/config.yaml` to match.

## Publishing a new image version

1. Make your code changes under `src/` (or the `Dockerfile`) and commit them.
2. Set a GitHub token with `write:packages` access as an environment variable:
   ```pwsh
   $env:GH_TOKEN = '<token>'
   ```
3. Build and push the image:
   ```pwsh
   ./scripts/build.ps1
   ```
   This computes the version with GitVersion (based on your commits), builds a `linux/arm64` image
   (matching the Home Assistant Yellow), and pushes it to
   `ghcr.io/classonconsultingab/ha-azure-ddns:<version>`.
   - Use `-Version <x.y.z>` to force a specific version instead of the GitVersion-computed one.
   - Use `-SkipPush` to build and load the image locally without pushing (for local testing only —
     add `-Platform linux/amd64` too if testing on a non-arm64 dev machine).
4. The script prints the pushed image tag at the end, e.g.:
   ```
   Image: ghcr.io/classonconsultingab/ha-azure-ddns:0.1.8
   Remember to set 'version: "0.1.8"' in azure-ddns/config.yaml to match.
   ```
   Update `version` in [`azure-ddns/config.yaml`](azure-ddns/config.yaml) to that exact value — Home
   Assistant requires it to match the image tag exactly.
5. Commit and push the `config.yaml` change.

## Installing/updating the add-on in Home Assistant

- **First-time setup**: In Home Assistant, go to Settings → Add-ons → Add-on store → ⋮ (top right) →
  Repositories, and add this repository's URL (`https://github.com/ClassonConsultingAB/ha-azure-ddns`).
  Then find "Azure DDNS" under the newly added repository and click Install.
- **Updating after a new image push**: Once `config.yaml`'s `version` is bumped and pushed to GitHub,
  go to the add-on store, click ⋮ → Check for updates, and an update button will appear on the add-on.
  Click it — Home Assistant pulls the new image tag and restarts the add-on.
- **Verifying it's working**: Open the add-on's Logs tab and confirm the DNS record sync log output.

