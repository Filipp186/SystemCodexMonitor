$ErrorActionPreference = 'Stop'

$programsRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs'))
$installRoot = [IO.Path]::GetFullPath((Join-Path $programsRoot 'SystemCodexMonitor'))
$startupTaskName = 'SystemCodexMonitor Dock Startup'

function Assert-SafeOwnedPath([string] $Path, [string] $Parent, [string] $Name) {
    $expected = [IO.Path]::GetFullPath((Join-Path $Parent $Name))
    if (-not [IO.Path]::GetFullPath($Path).Equals($expected, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove an unexpected path: $Path"
    }

    $ancestor = $expected
    while ($ancestor) {
        if (Test-Path -LiteralPath $ancestor) {
            $item = Get-Item -LiteralPath $ancestor -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Refusing to remove a reparse point: $ancestor"
            }
        }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }

    if (Test-Path -LiteralPath $expected -PathType Container) {
        $directories = [Collections.Generic.Stack[string]]::new()
        $directories.Push($expected)
        while ($directories.Count -gt 0) {
            foreach ($item in Get-ChildItem -LiteralPath $directories.Pop() -Force) {
                if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                    throw "Refusing to remove a reparse point: $($item.FullName)"
                }
                if ($item.PSIsContainer) { $directories.Push($item.FullName) }
            }
        }
    }
}

Assert-SafeOwnedPath $installRoot $programsRoot 'SystemCodexMonitor'
$logRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'SystemCodexMonitor'))
$logPath = Join-Path $logRoot 'startup.log'
Assert-SafeOwnedPath $logPath $logRoot 'startup.log'

Get-ScheduledTask -TaskName $startupTaskName -ErrorAction SilentlyContinue |
    Stop-ScheduledTask -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $startupTaskName -Confirm:$false -ErrorAction SilentlyContinue

Get-Process -Name 'SystemCodexMonitor' -ErrorAction SilentlyContinue |
    Where-Object {
        try {
            [IO.Path]::GetFullPath($_.Path).Equals((Join-Path $installRoot 'SystemCodexMonitor.exe'), [StringComparison]::OrdinalIgnoreCase)
        }
        catch { $false }
    } |
    Stop-Process -Force
Get-AppxPackage -Name 'Local.SystemCodexMonitor' -ErrorAction SilentlyContinue |
    Remove-AppxPackage -ErrorAction SilentlyContinue

Assert-SafeOwnedPath $installRoot $programsRoot 'SystemCodexMonitor'
if (Test-Path -LiteralPath $installRoot) {
    Remove-Item -LiteralPath $installRoot -Recurse -Force
}

Assert-SafeOwnedPath $logPath $logRoot 'startup.log'
if (Test-Path -LiteralPath $logPath -PathType Leaf) {
    Remove-Item -LiteralPath $logPath -Force
}

Write-Host 'System & Codex Monitor removed.' -ForegroundColor Green
