using System.ComponentModel.DataAnnotations;
using AzureDdns.Core.Features;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace AzureDdns.Core;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddAzureDdnsCore(
        this IServiceCollection services, IConfiguration configuration)
    {
        services.AddBoundOptions<DnsUpdaterOptions>(configuration);
        services.AddSingleton<IDnsRecordSynchronizer, DnsRecordSynchronizer>();
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
