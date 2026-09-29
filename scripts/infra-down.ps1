param(
    [string]$SubscriptionId = 'efd58bfe-18fe-47f3-ab30-2d5096d9149e',
    [string]$ResourceGroupName = 'rg-dns'
)

$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/modules/BuildTasks/BuildTasks.psm1" -Force

$exists = Exec "az group exists --name $ResourceGroupName --subscription $SubscriptionId" -ReturnOutput
if ($exists -ne 'true') {
    return
}

Exec "az group delete --name $ResourceGroupName --subscription $SubscriptionId --yes"
