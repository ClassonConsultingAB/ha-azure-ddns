# Azure DDNS

An Home Assistant add-on that keeps an Azure DNS A record in sync with your public IP address.

## Installing

1. In Home Assistant, go to **Settings → Add-ons → Add-on store → ⋮ (top right) → Repositories**, and
   add `https://github.com/ClassonConsultingAB/ha-azure-ddns`.
2. Search for and install the **Azure DDNS** app.
3. Configure the app options (DNS zone resource ID, record name, service principal credentials, etc.)
   and start it.

## Updating

When a new version is published, go to the add-on store, click **⋮ → Check for updates**, and an update
button will appear on the add-on. Click it — Home Assistant pulls the new image and restarts the add-on.

## Source code

This branch only contains the files Home Assistant needs to install the add-on. Source code, build
scripts, and CI configuration live on the [`main`](https://github.com/ClassonConsultingAB/ha-azure-ddns/tree/main) branch of this repository.
