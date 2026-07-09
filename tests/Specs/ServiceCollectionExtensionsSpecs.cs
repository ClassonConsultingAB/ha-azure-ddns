using System.ComponentModel.DataAnnotations;
using AzureDdns.Integration;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace AzureDdns.Specs;

public class ServiceCollectionExtensionsSpecs
{
    [Theory]
    [InlineData("dns_zone_resource_id")]
    [InlineData("record_name")]
    [InlineData("ip_provider_endpoint")]
    public void AddAzureDdnsIntegration_throws_when_a_required_config_value_is_empty(string emptyKey)
    {
        var configValues = new Dictionary<string, string?>
        {
            ["dns_zone_resource_id"] = "some-id",
            ["record_name"] = "some-record",
            ["ip_provider_endpoint"] = "https://icanhazip.com"
        };
        configValues[emptyKey] = "";
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(configValues).Build();
        var services = new ServiceCollection();

        Assert.Throws<ValidationException>(() => services.AddAzureDdnsIntegration(configuration));
    }
}
