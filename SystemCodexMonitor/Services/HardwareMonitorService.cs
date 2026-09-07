using LibreHardwareMonitor.Hardware;

namespace SystemCodexMonitor;

internal sealed partial class HardwareMonitorService : IDisposable
{
    private readonly Computer _computer;
    private readonly System.Timers.Timer _timer;
    private readonly object _sync = new();
    private HardwareSnapshot _snapshot = HardwareSnapshot.Empty;

    public HardwareMonitorService()
    {
        _computer = new Computer
        {
            IsCpuEnabled = true,
            IsGpuEnabled = true,
            IsMemoryEnabled = true,
            IsMotherboardEnabled = true,
        };

        try
        {
            _computer.Open();
        }
        catch
        {
            // Sensors that need a privileged driver can be unavailable.
        }

        _timer = new System.Timers.Timer(2_000) { AutoReset = true };
        _timer.Elapsed += (_, _) => Refresh();
        Refresh();
        _timer.Start();
    }

    public event EventHandler? Updated;

    public HardwareSnapshot Snapshot
    {
        get
        {
            lock (_sync)
            {
                return _snapshot;
            }
        }
    }

    public void Dispose()
    {
        _timer.Stop();
        _timer.Dispose();
        try
        {
            _computer.Close();
        }
        catch
        {
        }
    }

    private void Refresh()
    {
        try
        {
            foreach (var hardware in _computer.Hardware)
            {
                UpdateHardware(hardware);
            }

            var sensors = EnumerateSensors(_computer.Hardware).ToArray();
            var cpuSensors = sensors.Where(s => s.Hardware.HardwareType == HardwareType.Cpu).ToArray();
            var gpuSensors = sensors.Where(s => IsGpu(s.Hardware.HardwareType)).ToArray();
            var memorySensors = sensors.Where(s => s.Hardware.HardwareType == HardwareType.Memory).ToArray();
            var physicalMemorySensors = memorySensors
                .Where(s => s.Hardware.Name.Equals("Total Memory", StringComparison.OrdinalIgnoreCase))
                .ToArray();
            var aida = Aida64SensorReader.Read();

            var next = new HardwareSnapshot(
                CpuTemperature: aida.Cpu ?? Preferred(cpuSensors, SensorType.Temperature, "Package", "Tctl", "Core Max"),
                CpuLoad: Preferred(cpuSensors, SensorType.Load, "CPU Total", "Total"),
                MemoryLoad: Preferred(physicalMemorySensors, SensorType.Load, "Memory"),
                MemoryTemperature: aida.Memory ?? PreferredMemoryTemperature(sensors),
                GpuTemperature: aida.Gpu ?? Preferred(gpuSensors, SensorType.Temperature, "GPU Core", "Core", "Hot Spot"),
                GpuLoad: Preferred(gpuSensors, SensorType.Load, "GPU Core", "Core", "D3D 3D"),
                GpuMemoryLoad: Exact(gpuSensors, SensorType.Load, "GPU Memory"));

            lock (_sync)
            {
                _snapshot = next;
            }

            Updated?.Invoke(this, EventArgs.Empty);
        }
        catch
        {
            // Keep the last valid snapshot when a hardware driver is temporarily unavailable.
        }
    }

    private static void UpdateHardware(IHardware hardware)
    {
        hardware.Update();
        foreach (var child in hardware.SubHardware)
        {
            UpdateHardware(child);
        }
    }

    private static IEnumerable<ISensor> EnumerateSensors(IEnumerable<IHardware> hardwareList)
    {
        foreach (var hardware in hardwareList)
        {
            foreach (var sensor in hardware.Sensors)
            {
                if (sensor.Value is not null)
                {
                    yield return sensor;
                }
            }

            foreach (var childSensor in EnumerateSensors(hardware.SubHardware))
            {
                yield return childSensor;
            }
        }
    }

    private static float? Preferred(IEnumerable<ISensor> sensors, SensorType type, params string[] names)
    {
        var matches = sensors.Where(s => s.SensorType == type && s.Value is not null).ToArray();
        foreach (var name in names)
        {
            var match = matches.FirstOrDefault(s => s.Name.Contains(name, StringComparison.OrdinalIgnoreCase));
            if (match?.Value is not null)
            {
                return match.Value.Value;
            }
        }

        return matches.FirstOrDefault()?.Value;
    }

    private static float? Exact(IEnumerable<ISensor> sensors, SensorType type, string name)
    {
        return sensors
            .FirstOrDefault(sensor => sensor.SensorType == type
                && sensor.Value is not null
                && sensor.Name.Equals(name, StringComparison.OrdinalIgnoreCase))
            ?.Value;
    }

    private static float? PreferredMemoryTemperature(IEnumerable<ISensor> sensors)
    {
        return sensors
            .Where(s => s.SensorType == SensorType.Temperature && s.Value is not null)
            .Where(s => s.Name.Contains("DIMM", StringComparison.OrdinalIgnoreCase)
                || s.Name.Contains("DRAM", StringComparison.OrdinalIgnoreCase))
            .Where(s => !IsGpu(s.Hardware.HardwareType))
            .Select(s => s.Value)
            .FirstOrDefault();
    }

    private static bool IsGpu(HardwareType type)
    {
        return type is HardwareType.GpuAmd or HardwareType.GpuIntel or HardwareType.GpuNvidia;
    }
}

internal sealed record HardwareSnapshot(
    float? CpuTemperature,
    float? CpuLoad,
    float? MemoryLoad,
    float? MemoryTemperature,
    float? GpuTemperature,
    float? GpuLoad,
    float? GpuMemoryLoad)
{
    public static HardwareSnapshot Empty { get; } = new(null, null, null, null, null, null, null);
}
