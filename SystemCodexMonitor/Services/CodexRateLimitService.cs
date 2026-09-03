using System.Diagnostics;
using System.Text.Json;

namespace SystemCodexMonitor;

internal sealed partial class CodexRateLimitService : IDisposable
{
    private readonly System.Timers.Timer _timer;
    private readonly CancellationTokenSource _cancellation = new();
    private readonly object _sync = new();
    private CodexLimitSnapshot _snapshot = CodexLimitSnapshot.Loading;
    private int _refreshing;

    public CodexRateLimitService()
    {
        _timer = new System.Timers.Timer(120_000) { AutoReset = true };
        _timer.Elapsed += (_, _) => _ = RefreshAsync();
        _timer.Start();
        _ = RefreshAsync();
    }

    public event EventHandler? Updated;

    public CodexLimitSnapshot Snapshot
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
        _cancellation.Cancel();
        _cancellation.Dispose();
    }

    private async Task RefreshAsync()
    {
        if (Interlocked.Exchange(ref _refreshing, 1) != 0)
        {
            return;
        }

        try
        {
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(_cancellation.Token);
            timeout.CancelAfter(TimeSpan.FromSeconds(15));
            var next = await ReadLimitsAsync(timeout.Token).ConfigureAwait(false);
            lock (_sync)
            {
                _snapshot = next;
            }

            Updated?.Invoke(this, EventArgs.Empty);
        }
        catch (OperationCanceledException) when (!_cancellation.IsCancellationRequested)
        {
            SetError("Codex timeout");
        }
        catch (Exception ex)
        {
            SetError(ex.Message);
        }
        finally
        {
            Interlocked.Exchange(ref _refreshing, 0);
        }
    }

    private static async Task<CodexLimitSnapshot> ReadLimitsAsync(CancellationToken cancellationToken)
    {
        using var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = FindCodexExecutable(),
                Arguments = "app-server",
                UseShellExecute = false,
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
            },
        };

        try
        {
            if (!process.Start())
            {
                throw new InvalidOperationException("Codex app-server did not start");
            }

            await process.StandardInput.WriteLineAsync("{\"method\":\"initialize\",\"id\":0,\"params\":{\"clientInfo\":{\"name\":\"system_codex_monitor\",\"title\":\"System Codex Monitor\",\"version\":\"0.1.0\"}}}").ConfigureAwait(false);
            await process.StandardInput.WriteLineAsync("{\"method\":\"initialized\",\"params\":{}}").ConfigureAwait(false);
            await process.StandardInput.WriteLineAsync("{\"method\":\"account/rateLimits/read\",\"id\":6}").ConfigureAwait(false);
            await process.StandardInput.FlushAsync(cancellationToken).ConfigureAwait(false);

            while (!cancellationToken.IsCancellationRequested)
            {
                var line = await process.StandardOutput.ReadLineAsync(cancellationToken).ConfigureAwait(false);
                if (line is null)
                {
                    throw new InvalidOperationException("Codex app-server closed unexpectedly");
                }

                using var document = JsonDocument.Parse(line);
                var root = document.RootElement;
                if (!root.TryGetProperty("id", out var id) || id.GetInt32() != 6)
                {
                    continue;
                }

                if (root.TryGetProperty("error", out var error))
                {
                    throw new InvalidOperationException(error.GetProperty("message").GetString() ?? "Codex error");
                }

                var limits = root.GetProperty("result").GetProperty("rateLimits");
                return new CodexLimitSnapshot(
                    ReadWindow(limits, "primary"),
                    ReadWindow(limits, "secondary"),
                    null);
            }

            throw new OperationCanceledException(cancellationToken);
        }
        finally
        {
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
            }
        }
    }

    private static CodexLimitWindow? ReadWindow(JsonElement limits, string propertyName)
    {
        if (!limits.TryGetProperty(propertyName, out var value) || value.ValueKind == JsonValueKind.Null)
        {
            return null;
        }

        var used = value.GetProperty("usedPercent").GetDouble();
        var duration = value.GetProperty("windowDurationMins").GetInt32();
        var reset = value.GetProperty("resetsAt").GetInt64();
        return new CodexLimitWindow(Math.Clamp(100 - used, 0, 100), duration, reset);
    }

    private static string FindCodexExecutable()
    {
        var preferred = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".codex",
            "plugins",
            ".plugin-appserver",
            "codex.exe");
        return File.Exists(preferred) ? preferred : "codex.exe";
    }

    private void SetError(string error)
    {
        lock (_sync)
        {
            _snapshot = _snapshot with { Error = error };
        }

        Updated?.Invoke(this, EventArgs.Empty);
    }
}

internal sealed record CodexLimitWindow(double RemainingPercent, int WindowDurationMinutes, long ResetsAt);

internal sealed record CodexLimitSnapshot(CodexLimitWindow? Primary, CodexLimitWindow? Secondary, string? Error)
{
    public static CodexLimitSnapshot Loading { get; } = new(null, null, null);
}
