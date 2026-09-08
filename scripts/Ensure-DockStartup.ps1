$ErrorActionPreference = 'Stop'

$logRoot = Join-Path $env:LOCALAPPDATA 'SystemCodexMonitor'
$logPath = Join-Path $logRoot 'startup.log'

function Write-StartupLog([string] $Message) {
    try {
        New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
        Add-Content -LiteralPath $logPath -Value "$(Get-Date -Format o) $Message"
    }
    catch {
        # Logging must not prevent recovery.
    }
}

$windowProbe = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class DockWindowProbe
{
    private delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr hwnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int maxCount);

    public static bool HasVisiblePowerDock(uint[] processIds)
    {
        var ids = new HashSet<uint>(processIds);
        var found = false;

        EnumWindows((hwnd, _) =>
        {
            uint processId;
            GetWindowThreadProcessId(hwnd, out processId);
            if (!ids.Contains(processId) || !IsWindowVisible(hwnd))
            {
                return true;
            }

            var title = new StringBuilder(64);
            GetWindowText(hwnd, title, title.Capacity);
            if (string.Equals(title.ToString(), "PowerDock", StringComparison.Ordinal))
            {
                found = true;
                return false;
            }

            return true;
        }, IntPtr.Zero);

        return found;
    }
}
'@

function Get-CommandPaletteProcesses {
    @(Get-Process -Name 'Microsoft.CmdPal.UI' -ErrorAction SilentlyContinue |
        Where-Object {
            try {
                $_.Path -match '[\\/]WindowsApps[\\/]Microsoft\.CommandPalette_.*[\\/]Microsoft\.CmdPal\.UI\.exe$'
            }
            catch {
                $false
            }
        })
}

try {
    Add-Type -TypeDefinition $windowProbe

    $commandPalette = Get-CommandPaletteProcesses
    $commandPaletteIds = [uint32[]]@($commandPalette | ForEach-Object { $_.Id })
    if ($commandPaletteIds.Count -gt 0 -and [DockWindowProbe]::HasVisiblePowerDock($commandPaletteIds)) {
        Write-StartupLog 'Dock is already visible.'
        exit 0
    }

    foreach ($process in $commandPalette) {
        Stop-Process -Id $process.Id -Force
    }

    $extensionPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'SystemCodexMonitor.exe'))
    Get-Process -Name 'SystemCodexMonitor' -ErrorAction SilentlyContinue |
        Where-Object {
            try {
                [IO.Path]::GetFullPath($_.Path).Equals($extensionPath, [StringComparison]::OrdinalIgnoreCase)
            }
            catch {
                $false
            }
        } |
        ForEach-Object { Stop-Process -Id $_.Id -Force }

    Start-Process 'x-cmdpal://background'

    $deadline = (Get-Date).AddSeconds(45)
    do {
        Start-Sleep -Seconds 1
        $commandPalette = Get-CommandPaletteProcesses
        $commandPaletteIds = [uint32[]]@($commandPalette | ForEach-Object { $_.Id })
        if ($commandPaletteIds.Count -gt 0 -and [DockWindowProbe]::HasVisiblePowerDock($commandPaletteIds)) {
            Write-StartupLog 'Dock recovered after delayed startup.'
            exit 0
        }
    }
    while ((Get-Date) -lt $deadline)

    Write-StartupLog 'Dock recovery timed out.'
    exit 1
}
catch {
    Write-StartupLog "Dock recovery failed: $($_.Exception.Message)"
    exit 1
}
