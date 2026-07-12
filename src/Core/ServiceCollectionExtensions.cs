using System.ComponentModel.DataAnnotations;
using AzureDdns.Core.Features;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace AzureDdns.Core;

public static class ServiceCollectionExtensions
{
    extension(IServiceCollection services)
    {
        // ReSharper disable once UnusedMethodReturnValue.Global - Convension
        public IServiceCollection AddAzureDdnsCore(IConfiguration configuration)
        {
            services.AddBoundOptions<DnsUpdaterOptions>(configuration);
            services.AddSingleton<IDnsRecordSynchronizer, DnsRecordSynchronizer>();
            return services;
        }

        public void AddBoundOptions<TOptions>(IConfiguration configuration) where TOptions : class, new()
        {
            var options = new TOptions();
            configuration.Bind(options);
            Validator.ValidateObject(options, new ValidationContext(options), validateAllProperties: true);
            services.AddSingleton(options);
        }
    }
}
