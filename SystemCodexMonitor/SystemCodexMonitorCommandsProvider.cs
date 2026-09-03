using Microsoft.CommandPalette.Extensions;
using Microsoft.CommandPalette.Extensions.Toolkit;

namespace SystemCodexMonitor;

public sealed partial class SystemCodexMonitorCommandsProvider : CommandProvider, IDisposable
{
    private readonly HardwareMonitorService _hardware = new();
    private readonly CodexRateLimitService _codex = new();
    private readonly HardwareMetricItem[] _hardwareItems;
    private readonly CodexMetricItem _codexItem;
    private readonly ICommandItem[] _commands;
    private readonly ICommandItem[] _dockBands;

    public SystemCodexMonitorCommandsProvider()
    {
        DisplayName = "System & Codex Monitor";
        Id = "local.system-codex-monitor";
        Icon = new IconInfo("\uE9D9");

        _hardwareItems =
        [
            new HardwareMetricItem(_hardware, HardwareMetric.Cpu),
            new HardwareMetricItem(_hardware, HardwareMetric.Memory),
            new HardwareMetricItem(_hardware, HardwareMetric.Gpu),
        ];
        _codexItem = new CodexMetricItem(_codex);

        _dockBands =
        [
            new WrappedDockItem(
                _hardwareItems,
                "local.system-codex-monitor.hardware",
                "System sensors"),
            new WrappedDockItem(
                [_codexItem],
                "local.system-codex-monitor.codex",
                "Codex limit"),
        ];

        var page = new SystemCodexMonitorPage(_hardware, _codex);
        _commands = [new CommandItem(page) { Title = DisplayName }];
    }

    public override ICommandItem[] TopLevelCommands() => _commands;

    public override ICommandItem[]? GetDockBands() => _dockBands;

    public override void Dispose()
    {
        foreach (var item in _hardwareItems)
        {
            item.Dispose();
        }

        _codexItem.Dispose();
        _hardware.Dispose();
        _codex.Dispose();
        base.Dispose();
    }
}
