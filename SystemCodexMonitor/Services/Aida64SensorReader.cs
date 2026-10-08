using System.Globalization;
using System.IO.MemoryMappedFiles;
using System.Xml.Linq;

namespace SystemCodexMonitor;

internal static class Aida64SensorReader
{
    private const long MaxSensorBytes = 1024 * 1024;
    private static readonly string[] MapNames = ["Global\\AIDA64_SensorValues", "AIDA64_SensorValues"];

    public static Aida64Temperatures Read()
    {
        foreach (var mapName in MapNames)
        {
            try
            {
                using var map = MemoryMappedFile.OpenExisting(mapName, MemoryMappedFileRights.Read);
                using var stream = map.CreateViewStream(0, 0, MemoryMappedFileAccess.Read);
                if (stream.Length > MaxSensorBytes)
                {
                    continue;
                }

                using var reader = new StreamReader(stream);
                var xml = reader.ReadToEnd().TrimEnd('\0');
                var values = XDocument.Parse($"<root>{xml}</root>")
                    .Root!
                    .Elements("temp")
                    .Select(element => new
                    {
                        Id = element.Element("id")?.Value,
                        Value = Parse(element.Element("value")?.Value),
                    })
                    .Where(sensor => sensor.Id is not null && sensor.Value is not null)
                    .ToArray();

                return new Aida64Temperatures(
                    Cpu: values.FirstOrDefault(sensor => sensor.Id == "TCPUPKG")?.Value,
                    Memory: Average(values.Where(sensor => sensor.Id!.StartsWith("TDIMMTS", StringComparison.OrdinalIgnoreCase)).Select(sensor => sensor.Value)),
                    Gpu: values.FirstOrDefault(sensor => sensor.Id!.StartsWith("TGPU", StringComparison.OrdinalIgnoreCase)
                        && !sensor.Id.Contains("MEM", StringComparison.OrdinalIgnoreCase))?.Value);
            }
            catch
            {
                // AIDA64 may be closed or Shared Memory may be disabled.
            }
        }

        return Aida64Temperatures.Empty;
    }

    private static float? Parse(string? value)
    {
        if (float.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out var invariant))
        {
            return float.IsFinite(invariant) && invariant is >= -100 and <= 200 ? invariant : null;
        }

        return float.TryParse(value, NumberStyles.Float, CultureInfo.CurrentCulture, out var current)
            && float.IsFinite(current) && current is >= -100 and <= 200
            ? current
            : null;
    }

    private static float? Average(IEnumerable<float?> values)
    {
        var available = values.OfType<float>().ToArray();
        return available.Length == 0 ? null : available.Average();
    }
}

internal sealed record Aida64Temperatures(float? Cpu, float? Memory, float? Gpu)
{
    public static Aida64Temperatures Empty { get; } = new(null, null, null);
}
