using AzureDdns.Core;
using AzureDdns.Host.Features;
using AzureDdns.Integration;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

var builder = Host.CreateApplicationBuilder(args);
builder.Configuration.AddJsonFile("/data/options.json", optional: true);

builder.Logging.AddSimpleConsole(options =>
{
    options.SingleLine = true;
    options.TimestampFormat = "[yyyy-MM-dd HH:mm:ss] ";
});

// DefaultAzureCredential's EnvironmentCredential (used by AddAzureDdnsIntegration below) reads these
// standard Azure SDK env vars. Home Assistant options can't be exposed as env vars directly, so this
// bridges the HA-configured service principal into the process environment before the credential is
// constructed, keeping the secret out of the image/config.yaml.
SetEnvironmentVariableFromConfig("AZURE_TENANT_ID", "tenant_id");
SetEnvironmentVariableFromConfig("AZURE_CLIENT_ID", "client_id");
SetEnvironmentVariableFromConfig("AZURE_CLIENT_SECRET", "client_secret");

builder.Services.AddAzureDdnsCore(builder.Configuration);
builder.Services.AddAzureDdnsIntegration(builder.Configuration);
builder.Services.AddHostedService<DnsSyncWorker>();

builder.Build().Run();

void SetEnvironmentVariableFromConfig(string environmentVariableName, string configKey)
{
    var value = builder.Configuration[configKey];
    if (!string.IsNullOrEmpty(value))
        Environment.SetEnvironmentVariable(environmentVariableName, value);
}

