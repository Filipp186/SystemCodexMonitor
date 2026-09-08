$ErrorActionPreference = 'Stop'

$programsRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs'))
$installRoot = [IO.Path]::GetFullPath((Join-Path $programsRoot 'SystemCodexMonitor'))
$startupTaskName = 'SystemCodexMonitor Dock Startup'

Get-ScheduledTask -TaskName $startupTaskName -ErrorAction SilentlyContinue |
    Stop-ScheduledTask -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $startupTaskName -Confirm:$false -ErrorAction SilentlyContinue

Get-Process -Name 'SystemCodexMonitor' -ErrorAction SilentlyContinue | Stop-Process -Force
Get-AppxPackage -Name 'Local.SystemCodexMonitor' -ErrorAction SilentlyContinue |
    Remove-AppxPackage -ErrorAction SilentlyContinue

if (-not $installRoot.StartsWith($programsRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to remove an unexpected path.'
}

if (Test-Path -LiteralPath $installRoot) {
    Remove-Item -LiteralPath $installRoot -Recurse -Force
}

Write-Host 'System & Codex Monitor removed.' -ForegroundColor Green
