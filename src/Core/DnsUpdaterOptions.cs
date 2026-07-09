using Microsoft.Extensions.Configuration;

namespace AzureDdns.Core;

// ReSharper disable AutoPropertyCanBeMadeGetOnly.Global - Options

public class DnsUpdaterOptions
{
    [ConfigurationKeyName("interval_seconds")]
    public int IntervalSeconds { get; set; } = 300;
}
