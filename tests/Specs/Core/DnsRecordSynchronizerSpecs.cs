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
    public async Task UpdatesTheRecordWhenTheAddressDiffers()
    {
        var currentIp = IPAddress.Parse("203.0.113.1");
        var (sut, _, dnsZoneClient, logger) = CreateSut(currentIp, IPAddress.Parse("203.0.113.2"));

        await sut.SyncAsync(CancellationToken.None);

        Assert.Equal(1, dnsZoneClient.SetCount);
        Assert.Equal(currentIp, dnsZoneClient.CurrentAddress);
        Assert.Contains(logger.Messages, m => m.Contains("Updated"));
    }

    [Fact]
    public async Task DoesNotUpdateAndLogsOnceWhenTheAddressIsAlreadyCurrent()
    {
        var currentIp = IPAddress.Parse("203.0.113.1");
        var (sut, _, dnsZoneClient, logger) = CreateSut(currentIp, currentIp);

        await sut.SyncAsync(CancellationToken.None);

        Assert.Equal(0, dnsZoneClient.SetCount);
        Assert.Single(logger.Messages, m => m.Contains("No change"));
    }

    [Fact]
    public async Task StaysSilentOnSubsequentChecksWhileTheAddressRemainsUnchanged()
    {
        var currentIp = IPAddress.Parse("203.0.113.1");
        var (sut, _, _, logger) = CreateSut(currentIp, currentIp);

        await sut.SyncAsync(CancellationToken.None);
        await sut.SyncAsync(CancellationToken.None);
        await sut.SyncAsync(CancellationToken.None);

        Assert.Single(logger.Messages, m => m.Contains("No change"));
    }

    [Fact]
    public async Task OnlyFetchesTheExistingRecordOnceAcrossMultipleCalls()
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
    public async Task LogsNoChangeAgainAfterALaterUpdateStabilizes()
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
