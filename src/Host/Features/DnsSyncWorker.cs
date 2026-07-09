using AzureDdns.Core;
using AzureDdns.Core.Features;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace AzureDdns.Host.Features;

internal partial class DnsSyncWorker(
    IDnsRecordSynchronizer synchronizer, DnsUpdaterOptions options, ILogger<DnsSyncWorker> logger)
    : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(options.IntervalSeconds));
        do
        {
            await SyncSafelyAsync(stoppingToken);
        } while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    private async Task SyncSafelyAsync(CancellationToken cancellationToken)
    {
        try
        {
            await synchronizer.SyncAsync(cancellationToken);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            LogFailedToSyncTheDnsRecord(ex);
        }
    }

    [LoggerMessage(LogLevel.Error, "Failed to sync the DNS record")]
    partial void LogFailedToSyncTheDnsRecord(Exception exception);
}
