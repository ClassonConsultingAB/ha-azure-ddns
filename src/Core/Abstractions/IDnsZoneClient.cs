using System.Net;

namespace AzureDdns.Core.Abstractions;

public interface IDnsZoneClient
{
    Task<IPAddress?> TryGetARecordAddressAsync(CancellationToken cancellationToken);

    Task SetARecordAddressAsync(IPAddress address, CancellationToken cancellationToken);
}
