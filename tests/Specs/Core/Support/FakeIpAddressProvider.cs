using System.Net;
using AzureDdns.Core.Abstractions;

namespace AzureDdns.Specs.Core.Support;

internal class FakeIpAddressProvider(IPAddress address) : IIpAddressProvider
{
    public IPAddress Address { get; set; } = address;

    public Task<IPAddress> GetPublicIpAddressAsync(CancellationToken cancellationToken) =>
        Task.FromResult(Address);
}
