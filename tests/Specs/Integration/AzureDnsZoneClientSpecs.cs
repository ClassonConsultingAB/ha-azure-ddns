using System.Net;
using AzureDdns.Core.Abstractions;
using Xunit;

namespace AzureDdns.Specs.Integration;

/// <summary>
/// Runs against a real Azure DNS zone — requires the developer to be `az login`'d
/// (DefaultAzureCredential falls back to AzureCliCredential when no env-var/managed-identity
/// credential is available).
/// </summary>
public class AzureDnsZoneClientSpecs : AzureDdnsIntegrationTestBase
{
    [Fact]
    public async Task TryGetARecordAddressAsync_returns_null_when_the_record_does_not_exist()
    {
        // Uses a record name that is never created by any test in this class, so this doesn't need
        // teardown/cleanup coordination with the round-trip tests below that share "integrations-test".
        var sut = CreateSut<IDnsZoneClient>(("record_name", "integrations-test-missing"));

        var result = await sut.TryGetARecordAddressAsync(CancellationToken.None);

        Assert.Null(result);
    }

    [Fact]
    public async Task TryGetARecordAddressAsync_returns_null_when_the_record_set_has_no_a_records()
    {
        // "no-records" is a pre-created A record set in the real zone with zero DnsARecords entries,
        // exercising the FirstOrDefault() empty-collection path distinct from the 404/missing case above.
        var sut = CreateSut<IDnsZoneClient>(("record_name", "no-records"));

        var result = await sut.TryGetARecordAddressAsync(CancellationToken.None);

        Assert.Null(result);
    }

    [Fact]
    public async Task SetARecordAddressAsync_then_TryGetARecordAddressAsync_round_trips_the_value()
    {
        var sut = CreateSut<IDnsZoneClient>();
        var address = IPAddress.Parse("203.0.113.10");

        await sut.SetARecordAddressAsync(address, CancellationToken.None);
        var result = await sut.TryGetARecordAddressAsync(CancellationToken.None);

        Assert.Equal(address, result);
    }

    [Fact]
    public async Task SetARecordAddressAsync_overwrites_an_existing_different_value()
    {
        var sut = CreateSut<IDnsZoneClient>();
        await sut.SetARecordAddressAsync(IPAddress.Parse("203.0.113.11"), CancellationToken.None);

        await sut.SetARecordAddressAsync(IPAddress.Parse("203.0.113.12"), CancellationToken.None);
        var result = await sut.TryGetARecordAddressAsync(CancellationToken.None);

        Assert.Equal(IPAddress.Parse("203.0.113.12"), result);
    }
}
