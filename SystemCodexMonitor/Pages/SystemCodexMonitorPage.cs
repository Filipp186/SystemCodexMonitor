using Microsoft.CommandPalette.Extensions;
using Microsoft.CommandPalette.Extensions.Toolkit;

namespace SystemCodexMonitor;

internal sealed partial class SystemCodexMonitorPage : ListPage, IDisposable
{
    private readonly HardwareMonitorService _hardware;
    private readonly CodexRateLimitService _codex;

    public SystemCodexMonitorPage(HardwareMonitorService hardware, CodexRateLimitService codex)
    {
        _hardware = hardware;
        _codex = codex;
        Icon = new IconInfo("\uE9D9");
        Title = "System & Codex Monitor";
        Name = "Open monitor";
        _hardware.Updated += OnUpdated;
        _codex.Updated += OnUpdated;
    }

    public override IListItem[] GetItems()
    {
        var hardware = _hardware.Snapshot;
        var codex = _codex.Snapshot;

        return
        [
            SnapshotItem("CPU", HardwareMetricItem.FormatCpu(hardware), new IconInfo("\uE950")),
            SnapshotItem("Memory", HardwareMetricItem.FormatMemory(hardware), IconHelpers.FromRelativePath("Assets\\RamLogo.svg")),
            SnapshotItem("GPU", HardwareMetricItem.FormatGpu(hardware), IconHelpers.FromRelativePath("Assets\\GpuLogo.svg")),
            SnapshotItem("Codex", CodexMetricItem.FormatTitle(codex), IconHelpers.FromRelativePath("Assets\\CodexLogo.png"), CodexMetricItem.FormatSubtitle(codex)),
        ];
    }

    public void Dispose()
    {
        _hardware.Updated -= OnUpdated;
        _codex.Updated -= OnUpdated;
    }

    private static ListItem SnapshotItem(string name, string value, IconInfo icon, string? subtitle = null)
    {
        return new ListItem(new NoOpCommand())
        {
            Title = value,
            Subtitle = subtitle ?? name,
            Icon = icon,
        };
    }

    private void OnUpdated(object? sender, EventArgs e) => RaiseItemsChanged();
}
