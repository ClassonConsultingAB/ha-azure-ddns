param(
    [string]$SubscriptionId = 'efd58bfe-18fe-47f3-ab30-2d5096d9149e',
    [string]$Location = 'swedencentral'
)

$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/modules/BuildTasks/BuildTasks.psm1" -Force

$templateFilePath = Join-Path $PSScriptRoot '../infra/main.bicep' | Resolve-Path -Relative

Exec "az deployment sub create --subscription $SubscriptionId --location $Location --name ha-azure-ddns-dns --template-file $templateFilePath --output none"
