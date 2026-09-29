targetScope = 'subscription'

param location string = 'swedencentral'
param resourceGroupName string = 'rg-dns'
param zoneName string = 'classon.local'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

module zone 'dns-zone.bicep' = {
  scope: rg
  name: 'dns-zone'
  params: {
    zoneName: zoneName
  }
}
