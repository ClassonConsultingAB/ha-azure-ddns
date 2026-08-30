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
                // Using the production DNZ zone instead of a separate one for tests only saves me 60 SEK per year
                "/subscriptions/1fda8046-ed5e-4430-a580-c147285495ae/resourceGroups/dns-rg/providers/Microsoft.Network/dnszones/classon.eu",
            ["record_name"] = "ddns-integrations-test",
            ["ttl_seconds"] = "0",
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
