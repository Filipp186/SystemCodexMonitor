param(
    [Parameter(Mandatory)] [string] $ArchivePath,
    [Parameter(Mandatory)] [string] $OutputDirectory
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$sourcePath = (Get-Item -LiteralPath $ArchivePath -ErrorAction Stop).FullName
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$outputPath = Join-Path $outputRoot ([IO.Path]::GetFileName($sourcePath))
if ($sourcePath.Equals($outputPath, [StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $outputPath) -or (Test-Path -LiteralPath "$outputPath.sha256")) {
    throw 'Use a separate output directory with no existing output ZIP. Originals are never overwritten.'
}

$source = [IO.Compression.ZipFile]::OpenRead($sourcePath)
try {
    $output = [IO.Compression.ZipFile]::Open($outputPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        $removed = 0
        foreach ($entry in $source.Entries) {
            if ($entry.FullName.EndsWith('.pdb', [StringComparison]::OrdinalIgnoreCase)) { $removed++; continue }
            $copy = $output.CreateEntry($entry.FullName, [IO.Compression.CompressionLevel]::Optimal)
            $copy.LastWriteTime = $entry.LastWriteTime
            $copy.ExternalAttributes = $entry.ExternalAttributes
            $inputStream = $entry.Open()
            try {
                $outputStream = $copy.Open()
                try { $inputStream.CopyTo($outputStream) }
                finally { $outputStream.Dispose() }
            }
            finally { $inputStream.Dispose() }
        }
    }
    finally { $output.Dispose() }
}
finally { $source.Dispose() }

# Verify every retained file is identical; only debug symbols may disappear.
$before = [IO.Compression.ZipFile]::OpenRead($sourcePath)
$after = [IO.Compression.ZipFile]::OpenRead($outputPath)
try {
    if ($before.Entries.Count - $removed -ne $after.Entries.Count) { throw 'Unexpected entry count' }
    foreach ($entry in $before.Entries) {
        if ($entry.FullName.EndsWith('.pdb', [StringComparison]::OrdinalIgnoreCase)) { continue }
        $retained = $after.GetEntry($entry.FullName)
        if (-not $retained -or $entry.Length -ne $retained.Length) { throw "Entry mismatch: $($entry.FullName)" }
        $hash = [Security.Cryptography.SHA256]::Create()
        $a = $entry.Open(); $b = $retained.Open()
        try {
            if ([Convert]::ToBase64String($hash.ComputeHash($a)) -ne [Convert]::ToBase64String($hash.ComputeHash($b))) {
                throw "Content mismatch: $($entry.FullName)"
            }
        }
        finally { $a.Dispose(); $b.Dispose(); $hash.Dispose() }
    }
}
finally { $before.Dispose(); $after.Dispose() }
$checksum = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText("$outputPath.sha256", "$checksum  $([IO.Path]::GetFileName($outputPath))`n", [Text.Encoding]::ASCII)
[pscustomobject]@{ Archive = $outputPath; RemovedSymbols = $removed; Sha256 = $checksum }
