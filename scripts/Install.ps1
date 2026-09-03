$ErrorActionPreference = 'Stop'

$source = Join-Path $PSScriptRoot 'app'
$programsRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs'))
$installRoot = [IO.Path]::GetFullPath((Join-Path $programsRoot 'SystemCodexMonitor'))

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
    Stop-Process -Force

Get-AppxPackage -Name 'Local.SystemCodexMonitor' -ErrorAction SilentlyContinue |
    Remove-AppxPackage -ErrorAction SilentlyContinue

if (-not $installRoot.StartsWith($programsRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to use an unexpected installation path.'
}

if (Test-Path -LiteralPath $installRoot) {
    Remove-Item -LiteralPath $installRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $installRoot -Recurse -Force
Add-AppxPackage -Register (Join-Path $installRoot 'AppxManifest.xml') -ForceApplicationShutdown

Start-Process explorer.exe 'shell:AppsFolder\Microsoft.CommandPalette_8wekyb3d8bbwe!App'
Write-Host 'System & Codex Monitor installed successfully.' -ForegroundColor Green
