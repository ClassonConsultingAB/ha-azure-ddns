using System.Net;

namespace AzureDdns.Core.Abstractions;

public interface IIpAddressProvider
{
    Task<IPAddress> GetPublicIpAddressAsync(CancellationToken cancellationToken);
}
