# Azure DDNS

A Home Assistant add-on that keeps an Azure DNS A record in sync with your public IP address.

## Beta channel

A second add-on, **Azure DDNS (Beta)**, is also available from the same repository. It tracks builds
from pull requests and feature branches — useful for testing upcoming changes, but may be unstable.

It runs independently and can be installed side by side with this stable add-on.

## Updating

When a new version is published, go to the add-on store, click **⋮ → Check for updates**, and an update
button will appear on the add-on. Click it — Home Assistant pulls the new image and restarts the add-on.

## Configuration

- **`dns_zone_resource_id`** — the Azure Resource ID of the DNS zone to update. In the Azure Portal,
  open the DNS zone resource and copy its **Resource ID** from the **Properties** page.
- **`record_name`** — the name of the A record to keep in sync (relative to the zone), e.g. `home-assistant` for
  `home-assistant.example.com`.
- **`ttl_seconds`** — the TTL, in seconds, to set on the A record.
- **`ip_provider_endpoint`** — the URL used to determine the current public IP address. Defaults to
  `https://icanhazip.com`; change it only if you need a different IP lookup service.
- **`tenant_id`**, **`client_id`**, **`client_secret`** — the Entra ID (Azure AD) app registration's
  tenant ID, application (client) ID, and a client secret. Create/find these under **Entra ID → App
  registrations** in the Azure Portal: the tenant and application IDs are on the app registration's
  **Overview** page, and a client secret can be generated under **Certificates & secrets**.

## Permissions

The Entra ID app registration (service principal) used for `tenant_id`/`client_id`/`client_secret` must
be assigned the **DNS Zone Contributor** role on the target DNS zone (or on a resource group/subscription
scope containing it), so it's allowed to update the A record. Assign this under the DNS zone's (or
resource group's) **Access control (IAM) → Add role assignment** page in the Azure Portal.
