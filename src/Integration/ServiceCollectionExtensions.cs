using Azure.Core;
using Azure.Identity;
using Azure.ResourceManager;
using AzureDdns.Core;
using AzureDdns.Core.Abstractions;
using Classon.Identity;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace AzureDdns.Integration;

public static class ServiceCollectionExtensions
{
    extension(IServiceCollection services)
    {
        public IServiceCollection AddAzureDdnsIntegration(IConfiguration configuration)
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
    }
}
