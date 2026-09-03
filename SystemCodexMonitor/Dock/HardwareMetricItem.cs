using Microsoft.CommandPalette.Extensions;
using Microsoft.CommandPalette.Extensions.Toolkit;

namespace SystemCodexMonitor;

internal enum HardwareMetric
{
    Cpu,
    Memory,
    Gpu,
}

internal sealed partial class HardwareMetricItem : ListItem, IDisposable
{
    private readonly HardwareMonitorService _service;
    private readonly HardwareMetric _metric;

    public HardwareMetricItem(HardwareMonitorService service, HardwareMetric metric)
        : base(new NoOpCommand())
    {
        _service = service;
        _metric = metric;
        Icon = metric switch
        {
            HardwareMetric.Memory => IconHelpers.FromRelativePath("Assets\\RamLogo.svg"),
            HardwareMetric.Gpu => IconHelpers.FromRelativePath("Assets\\GpuLogo.svg"),
            _ => new IconInfo("\uE950"),
        };
        _service.Updated += OnUpdated;
        Apply(_service.Snapshot);
    }

    public void Dispose() => _service.Updated -= OnUpdated;

    internal static string FormatCpu(HardwareSnapshot value)
    {
        return $"CPU {Temperature(value.CpuTemperature)} · {Percent(value.CpuLoad)}";
    }

    internal static string FormatMemory(HardwareSnapshot value)
    {
        var temperature = value.MemoryTemperature is null ? string.Empty : $" · {Temperature(value.MemoryTemperature)}";
        return $"RAM {Percent(value.MemoryLoad)}{temperature}";
    }

    internal static string FormatGpu(HardwareSnapshot value)
    {
        return $"GPU {Temperature(value.GpuTemperature)} · {Percent(value.GpuLoad)}";
    }

    private static string Temperature(float? value) => value is null ? "—°C" : $"{value.Value:0}°C";

    private static string Percent(float? value) => value is null ? "—%" : $"{value.Value:0}%";

    private void OnUpdated(object? sender, EventArgs e) => Apply(_service.Snapshot);

    private void Apply(HardwareSnapshot value)
    {
        Title = _metric switch
        {
            HardwareMetric.Cpu => $"{Temperature(value.CpuTemperature)} {Percent(value.CpuLoad)}",
            HardwareMetric.Memory => $"{Temperature(value.MemoryTemperature)} {Percent(value.MemoryLoad)}",
            _ => $"{Temperature(value.GpuTemperature)} {Percent(value.GpuLoad)}",
        };
        Subtitle = _metric switch
        {
            HardwareMetric.Cpu => FormatCpu(value),
            HardwareMetric.Memory => FormatMemory(value),
            _ => FormatGpu(value),
        };
    }
}
