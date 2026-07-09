using System.Net;
using AzureDdns.Core.Abstractions;
using Microsoft.Extensions.Logging;

namespace AzureDdns.Core.Features;

public interface IDnsRecordSynchronizer
{
    Task SyncAsync(CancellationToken cancellationToken);
}

internal class DnsRecordSynchronizer(
    IIpAddressProvider ipAddressProvider, IDnsZoneClient dnsZoneClient, ILogger<IDnsRecordSynchronizer> logger)
    : IDnsRecordSynchronizer
{
    private bool _initialized;
    private IPAddress? _lastKnownAddress;
    private bool _loggedNoChangeSinceLastUpdate;

    public async Task SyncAsync(CancellationToken cancellationToken)
    {
        if (!_initialized)
        {
            _lastKnownAddress = await dnsZoneClient.TryGetARecordAddressAsync(cancellationToken);
            _initialized = true;
        }

        var currentAddress = await ipAddressProvider.GetPublicIpAddressAsync(cancellationToken);

        if (Equals(_lastKnownAddress, currentAddress))
        {
            LogNoChangeOnce(currentAddress);
            return;
        }

        await dnsZoneClient.SetARecordAddressAsync(currentAddress, cancellationToken);
        logger.LogInformation(
            "Updated A record from {OldAddress} to {NewAddress}", _lastKnownAddress, currentAddress);
        _lastKnownAddress = currentAddress;
        _loggedNoChangeSinceLastUpdate = false;
    }

    private void LogNoChangeOnce(IPAddress currentAddress)
    {
        if (_loggedNoChangeSinceLastUpdate)
            return;
        logger.LogInformation("No change needed, A record already set to {Address}", currentAddress);
        _loggedNoChangeSinceLastUpdate = true;
    }
}
