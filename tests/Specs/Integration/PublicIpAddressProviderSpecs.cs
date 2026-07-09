using AzureDdns.Core.Abstractions;
using Xunit;

namespace AzureDdns.Specs.Integration;

/// <summary>
/// Runs real HTTP calls against public IP-address lookup services to prove both the default
/// endpoint and the configurable-endpoint mechanism work.
/// </summary>
public class PublicIpAddressProviderSpecs : AzureDdnsIntegrationTestBase
{
    [Theory]
    [InlineData("https://icanhazip.com")]
    [InlineData("https://ifconfig.me/ip")]
    public async Task GetPublicIpAddressAsync_returns_a_parseable_address_from_the_configured_endpoint(
        string endpoint)
    {
        var sut = CreateSut<IIpAddressProvider>(("ip_provider_endpoint", endpoint));

        var address = await sut.GetPublicIpAddressAsync(CancellationToken.None);

        Assert.NotNull(address);
    }
}

