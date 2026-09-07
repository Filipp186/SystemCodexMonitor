using Microsoft.CommandPalette.Extensions;
using Microsoft.CommandPalette.Extensions.Toolkit;

namespace SystemCodexMonitor;

internal sealed partial class CodexMetricItem : ListItem, IDisposable
{
    private readonly CodexRateLimitService _service;
    private readonly System.Timers.Timer _displayTimer;

    public CodexMetricItem(CodexRateLimitService service)
        : base(new NoOpCommand())
    {
        _service = service;
        Icon = IconHelpers.FromRelativePath("Assets\\CodexLogo.png");
        _service.Updated += OnUpdated;
        _displayTimer = new System.Timers.Timer(60_000) { AutoReset = true };
        _displayTimer.Elapsed += OnDisplayTimerElapsed;
        Apply(_service.Snapshot);
        _displayTimer.Start();
    }

    public void Dispose()
    {
        _displayTimer.Stop();
        _displayTimer.Elapsed -= OnDisplayTimerElapsed;
        _displayTimer.Dispose();
        _service.Updated -= OnUpdated;
    }

    internal static string FormatTitle(CodexLimitSnapshot value)
    {
        if (value.Primary is null)
        {
            return value.Error is null ? "Codex …" : "Codex —";
        }

        return $"{value.Primary.RemainingPercent:0}% {FormatResetCountdown(value.Primary)}";
    }

    internal static string FormatSubtitle(CodexLimitSnapshot value)
    {
        if (value.Error is not null)
        {
            return value.Error;
        }

        if (value.Primary is null)
        {
            return "Loading limits";
        }

        var primary = Describe(value.Primary);
        var secondary = value.Secondary is null ? string.Empty : $"; {Describe(value.Secondary)}";
        return $"Remaining: {primary}{secondary}";
    }

    private static string Describe(CodexLimitWindow value)
    {
        var reset = DateTimeOffset.FromUnixTimeSeconds(value.ResetsAt).ToLocalTime();
        return $"{FormatWindow(value.WindowDurationMinutes)} resets {reset:dd.MM HH:mm}";
    }

    private static string FormatWindow(int minutes)
    {
        if (minutes % 10_080 == 0)
        {
            return $"{minutes / 10_080}w";
        }

        if (minutes % 1_440 == 0)
        {
            return $"{minutes / 1_440}d";
        }

        if (minutes % 60 == 0)
        {
            return $"{minutes / 60}h";
        }

        return $"{minutes}m";
    }

    private static string FormatResetCountdown(CodexLimitWindow value)
    {
        var remaining = DateTimeOffset.FromUnixTimeSeconds(value.ResetsAt) - DateTimeOffset.UtcNow;
        if (remaining <= TimeSpan.Zero)
        {
            return "0m";
        }

        if (remaining.TotalDays >= 1)
        {
            return $"{Math.Ceiling(remaining.TotalDays):0}d";
        }

        if (remaining.TotalHours >= 1)
        {
            return $"{Math.Ceiling(remaining.TotalHours):0}h";
        }

        return $"{Math.Ceiling(remaining.TotalMinutes):0}m";
    }

    private void OnUpdated(object? sender, EventArgs e) => Apply(_service.Snapshot);

    private void OnDisplayTimerElapsed(object? sender, EventArgs e) => Apply(_service.Snapshot);

    private void Apply(CodexLimitSnapshot value)
    {
        Title = FormatTitle(value);
        Subtitle = FormatSubtitle(value);
    }
}
