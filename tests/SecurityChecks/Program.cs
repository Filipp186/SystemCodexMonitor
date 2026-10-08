using System.IO.MemoryMappedFiles;
using System.Reflection;
using System.Text;
using SystemCodexMonitor;

var resolver = typeof(CodexRateLimitService).GetMethod("FindCodexExecutable", BindingFlags.NonPublic | BindingFlags.Static)!;
var root = Directory.CreateTempSubdirectory("SystemCodexMonitor-security-").FullName;
if (!Directory.GetParent(root)!.FullName.Equals(Path.GetFullPath(Path.GetTempPath()).TrimEnd(Path.DirectorySeparatorChar), StringComparison.OrdinalIgnoreCase))
    throw new InvalidOperationException("Unexpected test cleanup path");
var checks = 0;
void Check(bool condition, string label)
{
    if (!condition) throw new InvalidOperationException(label);
    checks++;
}
string Resolve(string profile, string? path) => (string)resolver.Invoke(null, [profile, path])!;
try
{
    var profile = Path.Combine(root, "profile");
    var fallback = Directory.CreateDirectory(Path.Combine(root, "cli")).FullName;
    var exe = Path.Combine(fallback, "codex.exe");
    File.WriteAllBytes(exe, []); // Resolver-only fixture: never executed.
    Check(Resolve(profile, $".;relative;C:relative;\"{fallback}\"") == exe, "Absolute PATH fallback");
    var preferred = Path.Combine(profile, ".codex", "plugins", ".plugin-appserver", "codex.exe");
    Directory.CreateDirectory(Path.GetDirectoryName(preferred)!);
    File.WriteAllBytes(preferred, []);
    Check(Resolve(profile, fallback) == preferred, "Preferred executable precedence");
    foreach (var path in new string?[] { null, "", ".;relative;C:relative", Path.Combine(root, "missing") })
    {
        try { Resolve(Path.Combine(root, "absent-profile"), path); throw new InvalidOperationException("Unsafe fallback accepted"); }
        catch (TargetInvocationException ex) when (ex.InnerException is FileNotFoundException) { checks++; }
    }

    var parser = typeof(Aida64SensorReader).GetMethod("Parse", BindingFlags.NonPublic | BindingFlags.Static)!;
    foreach (var value in new[] { "NaN", "Infinity", "-Infinity", "201", "-101", "not a number" })
        Check(parser.Invoke(null, [value]) is null, "Reject invalid temperature: " + value);
    Check((float)parser.Invoke(null, ["57.5"])! == 57.5f, "Accept valid temperature");

    var names = (string[])typeof(Aida64SensorReader).GetField("MapNames", BindingFlags.NonPublic | BindingFlags.Static)!.GetValue(null)!;
    names[0] = "SystemCodexMonitor-security-" + Guid.NewGuid();
    names[1] = names[0] + "-missing";
    using (var map = MemoryMappedFile.CreateNew(names[0], 4096))
    {
        using (var stream = map.CreateViewStream())
        {
            var xml = Encoding.UTF8.GetBytes("<temp><id>TCPUPKG</id><value>57</value></temp>");
            stream.Write(xml);
        }
        Check(Aida64SensorReader.Read().Cpu == 57, "Bounded shared-memory XML");
    }
    using (var map = MemoryMappedFile.CreateNew(names[0], 2 * 1024 * 1024))
        Check(Aida64SensorReader.Read() == Aida64Temperatures.Empty, "Reject oversized mapping");

    var drain = typeof(CodexRateLimitService).GetMethod("DrainStandardErrorAsync", BindingFlags.NonPublic | BindingFlags.Static)!;
    using var data = new MemoryStream(Encoding.UTF8.GetBytes(new string('x', 128 * 1024)));
    using var reader = new StreamReader(data);
    await (Task)drain.Invoke(null, [reader, CancellationToken.None])!;
    Check(data.Position == data.Length, "Drain stderr without retaining output");
    using var canceled = new CancellationTokenSource();
    canceled.Cancel();
    await (Task)drain.Invoke(null, [reader, canceled.Token])!;
    Check(true, "Canceled stderr drain returns cleanly");
    Console.WriteLine($"PASS: {checks} security checks; no app-server or installer launched.");
}
finally
{
    // Only this test-created directory; never repository or user application data.
    Directory.Delete(root, recursive: true);
}
