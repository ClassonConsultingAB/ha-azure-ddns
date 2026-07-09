using System.ComponentModel.DataAnnotations;
using Azure.Core;
using Azure.Identity;
using Azure.ResourceManager;
using AzureDdns.Core.Abstractions;
using Classon.Identity;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace AzureDdns.Integration;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddAzureDdnsIntegration(
        this IServiceCollection services, IConfiguration configuration)
    {
        services.AddBoundOptions<IpProviderOptions>(configuration);
        services.AddBoundOptions<AzureDnsZoneOptions>(configuration);
        services.AddHttpClient();
        services.AddCachingTokenCredential(new DefaultAzureCredential());
        services.AddSingleton(sp => new ArmClient(sp.GetRequiredService<TokenCredential>()));
        services.AddSingleton<IIpAddressProvider, PublicIpAddressProvider>();
        services.AddSingleton<IDnsZoneClient, AzureDnsZoneClient>();
        return services;
    }

    private static void AddBoundOptions<TOptions>(
        this IServiceCollection services, IConfiguration configuration) where TOptions : class, new()
    {
        var options = new TOptions();
        configuration.Bind(options);
        Validator.ValidateObject(options, new ValidationContext(options), validateAllProperties: true);
        services.AddSingleton(options);
    }
}
