using System.Net;
using AzureDdns.Core.Abstractions;

namespace AzureDdns.Specs.Core.Support;

internal class FakeDnsZoneClient(IPAddress? initialAddress) : IDnsZoneClient
{
    public IPAddress? CurrentAddress { get; private set; } = initialAddress;
    public int SetCount { get; private set; }
    public int GetCount { get; private set; }

    public Task<IPAddress?> TryGetARecordAddressAsync(CancellationToken cancellationToken)
    {
        GetCount++;
        return Task.FromResult(CurrentAddress);
    }

    public Task SetARecordAddressAsync(IPAddress address, CancellationToken cancellationToken)
    {
        CurrentAddress = address;
        SetCount++;
        return Task.CompletedTask;
    }
}
