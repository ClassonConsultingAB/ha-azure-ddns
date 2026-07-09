using System.Net;
using AzureDdns.Core;
using AzureDdns.Core.Abstractions;
using AzureDdns.Core.Features;
using AzureDdns.Specs.Core.Support;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Xunit;

namespace AzureDdns.Specs.Core;

public class DnsRecordSynchronizerSpecs
{
    private static (
        IDnsRecordSynchronizer Sut,
        FakeIpAddressProvider IpAddressProvider,
        FakeDnsZoneClient DnsZoneClient,
        FakeLogger<IDnsRecordSynchronizer> Logger)
        CreateSut(IPAddress currentIp, IPAddress? existingRecordAddress)
    {
        var ipAddressProvider = new FakeIpAddressProvider(currentIp);
        var dnsZoneClient = new FakeDnsZoneClient(existingRecordAddress);
        var logger = new FakeLogger<IDnsRecordSynchronizer>();
        var services = new ServiceCollection();
        services.AddAzureDdnsCore(new ConfigurationBuilder().Build());
        services.AddSingleton<IIpAddressProvider>(ipAddressProvider);
        services.AddSingleton<IDnsZoneClient>(dnsZoneClient);
        services.AddSingleton<ILogger<IDnsRecordSynchronizer>>(logger);
        var sut = services.BuildServiceProvider().GetRequiredService<IDnsRecordSynchronizer>();
        return (sut, ipAddressProvider, dnsZoneClient, logger);
    }

    [Fact]
    public async Task SyncAsync_updates_the_record_when_the_address_differs()
    {
        var currentIp = IPAddress.Parse("203.0.113.1");
        var (sut, _, dnsZoneClient, logger) = CreateSut(currentIp, IPAddress.Parse("203.0.113.2"));

        await sut.SyncAsync(CancellationToken.None);

        Assert.Equal(1, dnsZoneClient.SetCount);
        Assert.Equal(currentIp, dnsZoneClient.CurrentAddress);
        Assert.Contains(logger.Messages, m => m.Contains("Updated"));
    }

    [Fact]
    public async Task SyncAsync_does_not_update_and_logs_once_when_the_address_is_already_current()
    {
        var currentIp = IPAddress.Parse("203.0.113.1");
        var (sut, _, dnsZoneClient, logger) = CreateSut(currentIp, currentIp);

        await sut.SyncAsync(CancellationToken.None);

        Assert.Equal(0, dnsZoneClient.SetCount);
        Assert.Single(logger.Messages, m => m.Contains("No change"));
    }

    [Fact]
    public async Task SyncAsync_stays_silent_on_subsequent_checks_while_the_address_remains_unchanged()
    {
        var currentIp = IPAddress.Parse("203.0.113.1");
        var (sut, _, dnsZoneClient, logger) = CreateSut(currentIp, currentIp);

        await sut.SyncAsync(CancellationToken.None);
        await sut.SyncAsync(CancellationToken.None);
        await sut.SyncAsync(CancellationToken.None);

        Assert.Single(logger.Messages, m => m.Contains("No change"));
    }

    [Fact]
    public async Task SyncAsync_only_fetches_the_existing_record_once_across_multiple_calls()
    {
        var firstIp = IPAddress.Parse("203.0.113.1");
        var secondIp = IPAddress.Parse("203.0.113.2");
        var (sut, ipAddressProvider, dnsZoneClient, _) = CreateSut(firstIp, IPAddress.Parse("203.0.113.99"));

        await sut.SyncAsync(CancellationToken.None);
        ipAddressProvider.Address = secondIp;
        await sut.SyncAsync(CancellationToken.None);
        await sut.SyncAsync(CancellationToken.None);

        Assert.Equal(1, dnsZoneClient.GetCount);
    }

    [Fact]
    public async Task SyncAsync_logs_no_change_again_after_a_later_update_stabilizes()
    {
        var firstIp = IPAddress.Parse("203.0.113.1");
        var secondIp = IPAddress.Parse("203.0.113.2");
        var (sut, ipAddressProvider, dnsZoneClient, logger) =
            CreateSut(firstIp, IPAddress.Parse("203.0.113.99"));

        await sut.SyncAsync(CancellationToken.None);
        await sut.SyncAsync(CancellationToken.None);

        ipAddressProvider.Address = secondIp;
        await sut.SyncAsync(CancellationToken.None);
        await sut.SyncAsync(CancellationToken.None);

        Assert.Equal(2, dnsZoneClient.SetCount);
        Assert.Equal(2, logger.Messages.Count(m => m.Contains("No change")));
    }
}
