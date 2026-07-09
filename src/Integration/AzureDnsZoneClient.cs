using System.ComponentModel.DataAnnotations;
using System.Net;
using Azure;
using Azure.Core;
using Azure.ResourceManager;
using Azure.ResourceManager.Dns;
using Azure.ResourceManager.Dns.Models;
using AzureDdns.Core.Abstractions;
using Microsoft.Extensions.Configuration;

namespace AzureDdns.Integration;

public class AzureDnsZoneOptions
{
    [Required]
    [ConfigurationKeyName("dns_zone_resource_id")]
    public string DnsZoneResourceId { get; set; } = "";

    [Required]
    [ConfigurationKeyName("record_name")]
    public string RecordName { get; set; } = "";

    [ConfigurationKeyName("ttl_seconds")]
    public int TtlSeconds { get; set; } = 3600;
}

internal class AzureDnsZoneClient(ArmClient armClient, AzureDnsZoneOptions options) : IDnsZoneClient
{
    public async Task<IPAddress?> TryGetARecordAddressAsync(CancellationToken cancellationToken)
    {
        try
        {
            var record = await GetCollection().GetAsync(options.RecordName, cancellationToken);
            return record.Value.Data.DnsARecords.FirstOrDefault()?.IPv4Address;
        }
        catch (RequestFailedException ex) when (ex.Status == 404)
        {
            return null;
        }
    }

    public async Task SetARecordAddressAsync(IPAddress address, CancellationToken cancellationToken)
    {
        var data = new DnsARecordData
        {
            TtlInSeconds = options.TtlSeconds,
            DnsARecords = { new DnsARecordInfo { IPv4Address = address } }
        };
        await GetCollection().CreateOrUpdateAsync(
            WaitUntil.Completed, options.RecordName, data, cancellationToken: cancellationToken);
    }

    private DnsARecordCollection GetCollection() =>
        armClient.GetDnsZoneResource(new ResourceIdentifier(options.DnsZoneResourceId)).GetDnsARecords();
}
