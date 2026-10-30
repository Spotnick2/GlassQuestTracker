<#
    deploy.ps1 - Copy GlassQuestTracker (and optionally TrackerProbe) into the Forever AddOns folder.

    The repo keeps "## Version: @project-version@" for the packager; the deployed
    copy gets "dev". The repo copy is never modified.

    The glass material is the embedded LibGlass-1.0. The packager fetches it
    into Libs\LibGlass-1.0 (.pkgmeta externals); for a dev copy this script
    hands that job to the LibGlass checkout's own deploy.ps1, which checks the
    checkout, copies only the shipped files and prints its commit. The checkout
    is $env:LIBGLASS, else ..\LibGlass. (GlassChat's deploy, trimmed.)

    Usage:
        pwsh Tools/deploy.ps1               # GlassQuestTracker
        pwsh Tools/deploy.ps1 -Probe        # ...and TrackerProbe, with its host ForeverProbe
        pwsh Tools/deploy.ps1 -ProbeOnly    # just TrackerProbe and ForeverProbe

    TrackerProbe is a ForeverProbe module (References\Docs\PROBES.md). Its host is
    deployed first from $env:FOREVERPROBE, else ..\ForeverProbe, with the host's
    own deploy; a refusal there leaves TrackerProbe untouched.
        pwsh Tools/deploy.ps1 -AddOnsPath "D:\...\_forever_\Interface\AddOns"
#>

param(
    [string]$AddOnsPath = "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns",
    [switch]$Probe,
    [switch]$ProbeOnly
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path $AddOnsPath)) { Write-Error "AddOns path not found: $AddOnsPath"; exit 1 }
# Absolute, as LibGlass's deploy does: the stale-file sweep compares against
# Get-ChildItem's absolute FullName, and a relative $dest made it delete
# everything it had just copied, the library included (Codex, PR #8).
$AddOnsPath = (Resolve-Path -LiteralPath $AddOnsPath).ProviderPath

. (Join-Path $PSScriptRoot "LibGlassPin.ps1")
$LibGlass = if ($env:LIBGLASS) { $env:LIBGLASS } else { Join-Path (Split-Path -Parent $RepoRoot) "LibGlass" }
$ForeverProbe = if ($env:FOREVERPROBE) { $env:FOREVERPROBE } else { Join-Path (Split-Path -Parent $RepoRoot) "ForeverProbe" }

function Deploy-Addon {
    $dest = Join-Path $AddOnsPath "GlassQuestTracker"
    if (-not (Test-Path -LiteralPath (Join-Path $LibGlass "Tools\deploy.ps1"))) {
        Write-Error "LibGlass checkout not found at $LibGlass (clone github.com/Spotnick2/LibGlass there, or set `$env:LIBGLASS)"
        exit 1
    }
    Write-LibGlassPinStatus $RepoRoot $LibGlass "this deploy tests a library the release won't ship"
    # The library first: its deploy checks the checkout and may refuse, and a
    # refusal must leave the deployed addon as it was.
    & pwsh -NoProfile -File (Join-Path $LibGlass "Tools\deploy.ps1") -Addon GlassQuestTracker -AddOnsPath $AddOnsPath
    if ($LASTEXITCODE -ne 0) { Write-Error "LibGlass deploy refused; GlassQuestTracker was not touched"; exit 1 }
    Write-Host "Deploying GlassQuestTracker -> $dest" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    # The TOC is the list of what ships (subfolders included, e.g. Core\).
    $lua = @(Get-Content -LiteralPath (Join-Path $RepoRoot "GlassQuestTracker.toc") | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -notmatch "^#" -and $_ -match "[.]lua$" })
    # No textures of our own: the glass is LibGlass's.
    $files = @("GlassQuestTracker.toc", "LICENSE") + $lua
    foreach ($f in $files) {
        $src = Join-Path $RepoRoot $f
        $to = Join-Path $dest $f
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $to) | Out-Null
        if ($f -like "*.toc") {
            (Get-Content -LiteralPath $src -Raw) -replace '## Version: @project-version@', '## Version: dev' |
                Set-Content -LiteralPath $to -NoNewline
        } else {
            Copy-Item -LiteralPath $src -Destination $to -Force
        }
        Write-Host "  $f"
    }
    # A Lua file removed from the repo must not linger where the client finds it.
    $keep = $files | ForEach-Object { $_.Replace("/", "\") }
    Get-ChildItem -LiteralPath $dest -File -Recurse | Where-Object { $_.FullName -notlike (Join-Path $dest "Libs\*") } |
        ForEach-Object {
            $rel = $_.FullName.Substring($dest.Length + 1)
            if ($keep -notcontains $rel) {
                Write-Host "  removing stale $rel" -ForegroundColor DarkYellow
                Remove-Item -LiteralPath $_.FullName -Force
            }
        }
}

function Deploy-Probe {
    # The host first (ForeverProbe guide, section 6).
    $hostDeploy = Join-Path $ForeverProbe "Tools\deploy.ps1"
    if (-not (Test-Path -LiteralPath $hostDeploy)) {
        Write-Error "ForeverProbe checkout not found at $ForeverProbe (or set `$env:FOREVERPROBE)"; exit 1
    }
    & pwsh -NoProfile -File $hostDeploy -AddOnsPath $AddOnsPath
    if ($LASTEXITCODE -ne 0) { Write-Error "ForeverProbe deploy refused; TrackerProbe was not touched"; exit 1 }
    $dest = Join-Path $AddOnsPath "TrackerProbe"
    Write-Host "Deploying TrackerProbe -> $dest" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    # The TOC and Lua only: not forever-probe.pin (CI's).
    Get-ChildItem -LiteralPath (Join-Path $RepoRoot "Tools\TrackerProbe") -File |
        Where-Object { $_.Extension -in ".toc", ".lua" } | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dest $_.Name) -Force
            Write-Host "  $($_.Name)"
        }
}

if (-not $ProbeOnly) { Deploy-Addon }
if ($Probe -or $ProbeOnly) { Deploy-Probe }

Write-Host ""
Write-Host "/reload in game loads it, a brand-new addon folder included (ForeverProbe guide, section 7)." -ForegroundColor Yellow
Write-Host "In game:  /console scriptErrors 1   then   /gqt help   (probe: /fp gqt, /fp steps gqt look)" -ForegroundColor Green
