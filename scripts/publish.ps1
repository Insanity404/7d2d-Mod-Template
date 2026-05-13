<#
.SYNOPSIS
    Packages the mod into a distributable ZIP file.

.DESCRIPTION
    Validates all XML then creates a versioned ZIP archive in releases/.
    The ZIP contains the mod folder(s) ready to drop into a 7D2D Mods/ directory.

.PARAMETER Version
    Override the version string (default: modVersion from mod.config.json).

.PARAMETER ModName
    Override which mod to package (default: modName from mod.config.json).
    Use "all" to package every mod in src/Mods/ into separate ZIPs.

.PARAMETER SkipValidation
    Skip XML validation before packaging.

.PARAMETER IncludeServerConfig
    Include serverconfig_dev.xml in the release ZIP.

.EXAMPLE
    .\scripts\publish.ps1
    .\scripts\publish.ps1 -Version "1.2.0"
    .\scripts\publish.ps1 -ModName "all"
#>
param(
    [string]$Version             = "",
    [string]$ModName             = "",
    [switch]$SkipValidation,
    [switch]$IncludeServerConfig
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# === Load Config =============================================================

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$Config      = Get-Content (Join-Path $ProjectRoot "mod.config.json") | ConvertFrom-Json
$SourceDir   = Join-Path $ProjectRoot "src\Mods"
$ReleasesDir = Join-Path $ProjectRoot "releases"
$ServerDir   = Join-Path $ProjectRoot "server"

if (-not $ModName) { $ModName = $Config.modName }
if (-not $Version) { $Version = $Config.modVersion }

$modsToPack = if ($ModName -eq "all") {
    (Get-ChildItem -Path $SourceDir -Directory).Name
} else {
    @($ModName)
}

$datestamp = Get-Date -Format "yyyyMMdd"

Write-Host ""
Write-Host "=== 7D2D Mod Publisher ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Mod(s):  $($modsToPack -join ', ')"
Write-Host "  Version: $Version"
Write-Host "  Output:  $ReleasesDir"

# === Validate ================================================================

if (-not $SkipValidation) {
    Write-Host ""
    Write-Host "Validating XML..." -ForegroundColor Cyan

    $validateScript = Join-Path $PSScriptRoot "validate-xml.ps1"
    $hasErrors = $false

    foreach ($mod in $modsToPack) {
        $modPath = Join-Path $SourceDir $mod
        if (Test-Path $validateScript) {
            & $validateScript -ModPath $modPath -ServerDir $ServerDir -Strict
            if ($LASTEXITCODE -ne 0) { $hasErrors = $true }
        } else {
            foreach ($f in Get-ChildItem -Path $modPath -Filter "*.xml" -Recurse) {
                try { $null = [xml](Get-Content $f.FullName -Raw -Encoding UTF8) }
                catch {
                    Write-Host "  [FAIL] $($f.Name): $($_.Exception.Message)" -ForegroundColor Red
                    $hasErrors = $true
                }
            }
        }
    }

    if ($hasErrors) {
        Write-Host ""
        Write-Host "Publish aborted - fix validation errors first." -ForegroundColor Red
        exit 1
    }

    Write-Host "  Validation passed." -ForegroundColor Green
}

# === Package =================================================================

New-Item -ItemType Directory -Path $ReleasesDir -Force | Out-Null

$publishedZips = @()

foreach ($mod in $modsToPack) {
    $modPath = Join-Path $SourceDir $mod
    if (-not (Test-Path $modPath)) {
        Write-Host "  [SKIP] $mod - source not found." -ForegroundColor Yellow
        continue
    }

    # Read version from ModInfo.xml if available
    $modVersion  = $Version
    $modInfoPath = Join-Path $modPath "ModInfo.xml"
    if (Test-Path $modInfoPath) {
        try {
            [xml]$modInfo = Get-Content $modInfoPath -Raw -Encoding UTF8
            $vNode = $modInfo.SelectSingleNode("//Version")
            if ($vNode -and $vNode.GetAttribute("value")) {
                $modVersion = $vNode.GetAttribute("value")
            }
        } catch { }
    }

    $zipName = "${mod}-v${modVersion}-${datestamp}.zip"
    $zipPath = Join-Path $ReleasesDir $zipName

    Write-Host ""
    Write-Host "  Packaging: $mod v$modVersion" -ForegroundColor White

    $stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) "7d2d-publish-$mod"
    if (Test-Path $stagingDir) { Remove-Item $stagingDir -Recurse -Force }
    New-Item -ItemType Directory -Path $stagingDir | Out-Null


    # Only include: ModInfo.xml, Config/, Resources/, Textures/, *.dll (root), README.md (if present)
    $deployList = @()
    $modInfoPath = Join-Path $modPath "ModInfo.xml"
    if (Test-Path $modInfoPath) { $deployList += $modInfoPath }
    $configPath = Join-Path $modPath "Config"
    if (Test-Path $configPath) { $deployList += $configPath }
    $resourcesPath = Join-Path $modPath "Resources"
    if (Test-Path $resourcesPath) { $deployList += $resourcesPath }
    $texturesPath = Join-Path $modPath "Textures"
    if (Test-Path $texturesPath) { $deployList += $texturesPath }
    $dlls = @(Get-ChildItem -Path $modPath -Filter "*.dll" -File -ErrorAction SilentlyContinue)
    if ($dlls.Count -gt 0) { $deployList += @($dlls | ForEach-Object { $_.FullName }) }
    $readmePath = Join-Path $modPath "README.md"
    if (Test-Path $readmePath) { $deployList += $readmePath }

    $modStaging = Join-Path $stagingDir $mod
    New-Item -ItemType Directory -Path $modStaging -Force | Out-Null
    foreach ($item in $deployList) {
        $dest = Join-Path $modStaging ([System.IO.Path]::GetFileName($item))
        if (Test-Path $item -PathType Container) {
            Copy-Item $item $dest -Recurse -Force
        } else {
            Copy-Item $item $dest -Force
        }
    }

    if ($IncludeServerConfig) {
        $devConfig = Join-Path $ServerDir "serverconfig_dev.xml"
        if (Test-Path $devConfig) {
            Copy-Item $devConfig (Join-Path $stagingDir "serverconfig_example.xml")
        }
    }

    $readmeTxt = @"
$($Config.modDisplayName) v$modVersion
$("=" * 40)
Author:  $($Config.modAuthor)
Website: $($Config.modWebsite)
Built:   $(Get-Date -Format "yyyy-MM-dd")

INSTALLATION
------------
1. Copy the '$mod' folder into your server's Mods/ directory.
2. Restart the server.

DESCRIPTION
-----------
$($Config.modDescription)
"@
    Set-Content -Path (Join-Path $stagingDir "README.txt") -Value $readmeTxt -Encoding UTF8

    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path "$stagingDir\*" -DestinationPath $zipPath
    Remove-Item $stagingDir -Recurse -Force

    $sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
    Write-Host "    Created: $zipName ($sizeMB MB)" -ForegroundColor Green
    $publishedZips += $zipPath
}

# === Summary =================================================================

Write-Host ""
Write-Host "Published $($publishedZips.Count) package(s) to: $ReleasesDir" -ForegroundColor Green
Write-Host ""
