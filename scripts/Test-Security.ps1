$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$checks = 0
foreach ($name in @('Install.ps1', 'Uninstall.ps1', 'New-Release.ps1')) {
    $tokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $name), [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw "Syntax errors in $name" }
    $guard = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Assert-SafeOwnedPath' }, $true)
    if (-not $guard) { throw "Missing path guard in $name" }
    # Evaluate only the guard function, never the installer/uninstaller body.
    & ([scriptblock]::Create($guard.Extent.Text + @'

    $parent = Join-Path $repositoryRoot 'artifacts'
    $child = Join-Path $parent 'security-test-nonexistent'
    Assert-SafeOwnedPath $child $parent 'security-test-nonexistent'
    $rejected = $false
    try { Assert-SafeOwnedPath ($child + '-sibling') $parent 'security-test-nonexistent' }
    catch { $rejected = $true }
    if (-not $rejected) { throw 'Sibling path incorrectly accepted' }
'@))
    $checks += 3
}
Write-Host "PASS: $checks PowerShell syntax/path checks; installers not executed."
