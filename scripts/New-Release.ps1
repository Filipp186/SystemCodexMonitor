param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string] $Version
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$artifactsRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot 'artifacts'))
$publishRoot = [IO.Path]::GetFullPath((Join-Path $artifactsRoot 'publish'))
$releaseRoot = [IO.Path]::GetFullPath((Join-Path $artifactsRoot "SystemCodexMonitor-v$Version-win-x64"))
$zipPath = [IO.Path]::GetFullPath("$releaseRoot.zip")
$project = Join-Path $repositoryRoot 'SystemCodexMonitor\SystemCodexMonitor.csproj'

foreach ($path in @($publishRoot, $releaseRoot, $zipPath)) {
    if (-not $path.StartsWith($artifactsRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify an unexpected path: $path"
    }

    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
    }
}

dotnet publish $project -c Release -r win-x64 --self-contained true -p:Platform=x64 -o $publishRoot
if ($LASTEXITCODE -ne 0) {
    throw 'dotnet publish failed.'
}

$winRtRuntime = Join-Path $publishRoot 'WinRT.Runtime.dll'
try {
    [Reflection.AssemblyName]::GetAssemblyName($winRtRuntime) | Out-Null
}
catch {
    throw 'The published WinRT.Runtime.dll is not loadable. ReadyToRun must remain disabled.'
}

$generatedManifest = Get-ChildItem (Join-Path $repositoryRoot 'SystemCodexMonitor\bin\x64\Release') `
    -Recurse -Filter 'AppxManifest.xml' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if (-not $generatedManifest) {
    throw 'The generated AppxManifest.xml was not found.'
}

Copy-Item -LiteralPath $generatedManifest.FullName -Destination (Join-Path $publishRoot 'AppxManifest.xml') -Force

New-Item -ItemType Directory -Path (Join-Path $releaseRoot 'app') -Force | Out-Null
Copy-Item -Path (Join-Path $publishRoot '*') -Destination (Join-Path $releaseRoot 'app') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Install.ps1'), (Join-Path $PSScriptRoot 'Install.cmd'), (Join-Path $PSScriptRoot 'Uninstall.ps1'), (Join-Path $PSScriptRoot 'Uninstall.cmd'), (Join-Path $PSScriptRoot 'Ensure-DockStartup.ps1') -Destination $releaseRoot
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'README.ru.md'), (Join-Path $repositoryRoot 'LICENSE'), (Join-Path $repositoryRoot 'THIRD-PARTY-NOTICES.md') -Destination $releaseRoot
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'LICENSES') -Destination $releaseRoot -Recurse

Compress-Archive -Path (Join-Path $releaseRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal
Write-Host $zipPath
