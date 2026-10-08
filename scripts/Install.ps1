$ErrorActionPreference = 'Stop'

$source = Join-Path $PSScriptRoot 'app'
$programsRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs'))
$installRoot = [IO.Path]::GetFullPath((Join-Path $programsRoot 'SystemCodexMonitor'))
$startupTaskName = 'SystemCodexMonitor Dock Startup'

function Assert-SafeOwnedPath([string] $Path, [string] $Parent, [string] $Name) {
    $expected = [IO.Path]::GetFullPath((Join-Path $Parent $Name))
    if (-not [IO.Path]::GetFullPath($Path).Equals($expected, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to use an unexpected path: $Path"
    }

    $ancestor = $expected
    while ($ancestor) {
        if (Test-Path -LiteralPath $ancestor) {
            $item = Get-Item -LiteralPath $ancestor -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Refusing to use a reparse point: $ancestor"
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
                    throw "Refusing to use a reparse point: $($item.FullName)"
                }
                if ($item.PSIsContainer) { $directories.Push($item.FullName) }
            }
        }
    }
}

Assert-SafeOwnedPath $installRoot $programsRoot 'SystemCodexMonitor'

if (-not (Test-Path -LiteralPath (Join-Path $source 'AppxManifest.xml'))) {
    throw 'The app payload is missing. Extract the complete release ZIP before installing.'
}

$developerMode = Get-ItemPropertyValue `
    -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
    -Name 'AllowDevelopmentWithoutDevLicense' `
    -ErrorAction SilentlyContinue

if ($developerMode -ne 1) {
    Start-Process 'ms-settings:developers'
    throw 'Enable Windows Developer Mode, then run Install.cmd again.'
}

Get-Process -Name 'Microsoft.CmdPal.UI', 'SystemCodexMonitor' -ErrorAction SilentlyContinue |
    Where-Object {
        try {
            $processPath = [IO.Path]::GetFullPath($_.Path)
            $processPath.Equals((Join-Path $installRoot 'SystemCodexMonitor.exe'), [StringComparison]::OrdinalIgnoreCase) -or
                $processPath -match '[\\/]WindowsApps[\\/]Microsoft\.CommandPalette_.*[\\/]Microsoft\.CmdPal\.UI\.exe$'
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

New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $installRoot -Recurse -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Ensure-DockStartup.ps1') -Destination $installRoot -Force
Add-AppxPackage -Register (Join-Path $installRoot 'AppxManifest.xml') -ForceApplicationShutdown

$startupScript = Join-Path $installRoot 'Ensure-DockStartup.ps1'
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$action = New-ScheduledTaskAction -Execute $powershell -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$startupScript`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$trigger.Delay = 'PT2M'
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 3)
Register-ScheduledTask -TaskName $startupTaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Ensures that the Command Palette Dock is visible after display initialization.' -Force | Out-Null

Start-Process 'x-cmdpal://background'
Write-Host 'System & Codex Monitor installed successfully.' -ForegroundColor Green
