param zoneName string

resource zone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: zoneName
  location: 'global'
}

resource integrationsTestRecord 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  parent: zone
  name: 'ddns-integrations-test'
  properties: {
    TTL: 0
    ARecords: [
      {
        ipv4Address: '203.0.113.12'
      }
    ]
  }
}

resource noRecordsRecordSet 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  parent: zone
  name: 'ddns-no-records'
  properties: {
    TTL: 3600
    ARecords: []
  }
}
