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
$checksumPath = "$zipPath.sha256"
$project = Join-Path $repositoryRoot 'SystemCodexMonitor\SystemCodexMonitor.csproj'

function Assert-SafeOwnedPath([string] $Path, [string] $Parent, [string] $Name) {
    $expected = [IO.Path]::GetFullPath((Join-Path $Parent $Name))
    if (-not [IO.Path]::GetFullPath($Path).Equals($expected, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify an unexpected path: $Path"
    }

    $ancestor = $expected
    while ($ancestor) {
        if (Test-Path -LiteralPath $ancestor) {
            $item = Get-Item -LiteralPath $ancestor -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Refusing to modify a reparse point: $ancestor"
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
                    throw "Refusing to modify a reparse point: $($item.FullName)"
                }
                if ($item.PSIsContainer) { $directories.Push($item.FullName) }
            }
        }
    }
}

foreach ($path in @($publishRoot, $releaseRoot, $zipPath, $checksumPath)) {
    Assert-SafeOwnedPath $path $artifactsRoot ([IO.Path]::GetFileName($path))

    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
    }
}

dotnet publish $project -c Release -r win-x64 --self-contained true -p:Platform=x64 -p:DebugType=None -p:DebugSymbols=false -o $publishRoot
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

$targetDirectory = dotnet msbuild $project -nologo -getProperty:TargetDir -p:Configuration=Release -p:Platform=x64 -p:RuntimeIdentifier=win-x64
if ($LASTEXITCODE -ne 0 -or -not [IO.Path]::IsPathRooted([string]$targetDirectory)) {
    throw 'The current build output directory could not be determined.'
}
$generatedManifest = Join-Path ([string]$targetDirectory).Trim() 'AppxManifest.xml'
if (-not (Test-Path -LiteralPath $generatedManifest -PathType Leaf)) {
    throw 'The generated AppxManifest.xml was not found.'
}

Copy-Item -LiteralPath $generatedManifest -Destination (Join-Path $publishRoot 'AppxManifest.xml') -Force

New-Item -ItemType Directory -Path (Join-Path $releaseRoot 'app') -Force | Out-Null
Copy-Item -Path (Join-Path $publishRoot '*') -Destination (Join-Path $releaseRoot 'app') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Install.ps1'), (Join-Path $PSScriptRoot 'Install.cmd'), (Join-Path $PSScriptRoot 'Uninstall.ps1'), (Join-Path $PSScriptRoot 'Uninstall.cmd'), (Join-Path $PSScriptRoot 'Ensure-DockStartup.ps1') -Destination $releaseRoot
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'README.ru.md'), (Join-Path $repositoryRoot 'LICENSE'), (Join-Path $repositoryRoot 'THIRD-PARTY-NOTICES.md') -Destination $releaseRoot
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'LICENSES') -Destination $releaseRoot -Recurse

Assert-SafeOwnedPath $releaseRoot $artifactsRoot "SystemCodexMonitor-v$Version-win-x64"
Get-ChildItem -LiteralPath $releaseRoot -Filter '*.pdb' -File -Recurse |
    Remove-Item -Force

Compress-Archive -Path (Join-Path $releaseRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal
$checksum = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText($checksumPath, "$checksum  $([IO.Path]::GetFileName($zipPath))`n", [Text.Encoding]::ASCII)
Write-Host $zipPath
