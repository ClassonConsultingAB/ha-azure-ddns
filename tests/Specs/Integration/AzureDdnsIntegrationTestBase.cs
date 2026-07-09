using AzureDdns.Integration;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace AzureDdns.Specs.Integration;

/// <summary>
/// Shared setup for Integration tests that resolve a SUT via DI through `AddAzureDdnsIntegration`.
/// Centralizes the real Azure DNS zone/record defaults (so they're not duplicated per test file) and
/// tracks every `ServiceProvider` created via <see cref="CreateSut{TSut}"/> so they can all be
/// disposed together — `ServiceProvider` is `IDisposable`, and letting them leak per test adds up
/// across a suite (HttpClient handlers, ArmClient, etc.).
/// </summary>
public abstract class AzureDdnsIntegrationTestBase : IDisposable
{
    private readonly List<ServiceProvider> _serviceProviders = [];

    protected TSut CreateSut<TSut>(params (string Key, string? Value)[] configOverrides) where TSut : notnull
    {
        var configValues = new Dictionary<string, string?>
        {
            ["dns_zone_resource_id"] =
                "/subscriptions/efd58bfe-18fe-47f3-ab30-2d5096d9149e/resourceGroups/ha-azure-dns-local" +
                "/providers/Microsoft.Network/dnsZones/classon-local.eu",
            ["record_name"] = "integrations-test",
            ["ttl_seconds"] = "60",
            ["ip_provider_endpoint"] = "https://icanhazip.com"
        };
        foreach (var (key, value) in configOverrides)
            configValues[key] = value;

        var configuration = new ConfigurationBuilder().AddInMemoryCollection(configValues).Build();
        var services = new ServiceCollection();
        services.AddAzureDdnsIntegration(configuration);
        var serviceProvider = services.BuildServiceProvider();
        _serviceProviders.Add(serviceProvider);
        return serviceProvider.GetRequiredService<TSut>();
    }

    public void Dispose()
    {
        foreach (var serviceProvider in _serviceProviders)
            serviceProvider.Dispose();
        GC.SuppressFinalize(this);
    }
}
