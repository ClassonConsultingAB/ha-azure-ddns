using System.ComponentModel.DataAnnotations;
using Microsoft.Extensions.Configuration;

namespace AzureDdns.Core;

public class DnsUpdaterOptions
{
    [ConfigurationKeyName("interval_seconds")]
    public int IntervalSeconds { get; set; } = 300;
}
