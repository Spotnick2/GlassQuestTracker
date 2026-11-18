<#
    run.ps1 - Syntax-check the addon and the probe, and run every tests\test_*.lua
    under Lua 5.1, through WowTestKit at the commit tests\kit.pin names (its
    scripts\run.ps1).

    Usage:
        pwsh tests/run.ps1
        pwsh tests/run.ps1 -Lua "C:\path\to\lua5.1.exe"
        pwsh tests/run.ps1 -KitDev      # the ..\WowTestKit working copy, not the pin
#>

param(
    [string]$Lua = "C:\Program Files (x86)\Lua\5.1\lua.exe",
    [switch]$KitDev
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $Lua)) { Write-Error "Lua 5.1 not found at $Lua (pass -Lua <path>)"; exit 1 }
$RepoRoot = Split-Path -Parent $PSScriptRoot

# The TOCs are the list, so a new file cannot go unchecked: the kit's runner
# syntax-checks the addon's TOC files, and the probe's are passed as -Extra.
# The embedded library is checked in its own repo.
$probeToc = Join-Path $RepoRoot "Tools\TrackerProbe\TrackerProbe.toc"
$probeFiles = @()
if (Test-Path $probeToc) {
    $probeFiles = @(Get-Content $probeToc | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -notmatch "^#" -and $_ -match "[.]lua$" } | ForEach-Object { "Tools\TrackerProbe\$_" })
}

# The tests load the LibGlass checkout as it is; CI loads the .pkgmeta pin.
$libGlass = if ($env:LIBGLASS) { $env:LIBGLASS } else { Join-Path (Split-Path -Parent $RepoRoot) "LibGlass" }
. (Join-Path $RepoRoot "Tools\LibGlassPin.ps1")
if (Test-Path -LiteralPath $libGlass) { Write-LibGlassPinStatus $RepoRoot $libGlass "CI tests the pin" }

. (Join-Path $PSScriptRoot "kit.ps1")
$kit = Get-WowTestKit -RepoRoot $RepoRoot -KitDev:$KitDev
& (Join-Path $kit "scripts\run.ps1") -RepoRoot $RepoRoot -Toc "GlassQuestTracker.toc" -Extra $probeFiles -Lua $Lua
exit $LASTEXITCODE
