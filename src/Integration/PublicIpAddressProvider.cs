using System.ComponentModel.DataAnnotations;
using System.Net;
using AzureDdns.Core.Abstractions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Http;

namespace AzureDdns.Integration;

public class IpProviderOptions
{
    [Required]
    [ConfigurationKeyName("ip_provider_endpoint")]
    public string Endpoint { get; set; } = "https://icanhazip.com";
}

internal class PublicIpAddressProvider(IHttpClientFactory httpClientFactory, IpProviderOptions options)
    : IIpAddressProvider
{
    public async Task<IPAddress> GetPublicIpAddressAsync(CancellationToken cancellationToken)
    {
        using var client = httpClientFactory.CreateClient();
        var response = await client.GetStringAsync(options.Endpoint, cancellationToken);
        return IPAddress.Parse(response.Trim());
    }
}
