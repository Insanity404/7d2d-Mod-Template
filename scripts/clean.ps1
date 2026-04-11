<#
.SYNOPSIS
    Removes deployed mod files from the dev server's Mods/ directory.

.DESCRIPTION
    By default only removes mods whose names match folders in src/Mods/.
    Use -All to remove every mod from the server.

.PARAMETER All
    Remove ALL mods from server/Mods/, not just the ones from src/Mods/.

.PARAMETER ModName
    Remove only a specific mod by name.

.EXAMPLE
    .\scripts\clean.ps1
    .\scripts\clean.ps1 -All
    .\scripts\clean.ps1 -ModName "MyMod"
#>
param(
    [switch]$All,
    [string]$ModName = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$Config      = Get-Content (Join-Path $ProjectRoot "mod.config.json") | ConvertFrom-Json
$ServerDir   = Join-Path $ProjectRoot "server"
$SourceDir   = Join-Path $ProjectRoot "src\Mods"
$ModsDir     = Join-Path $ServerDir "Mods"

if (-not (Test-Path $ModsDir)) {
    Write-Host "No Mods directory found at: $ModsDir" -ForegroundColor Yellow
    exit 0
}

$toRemove = @()

if ($ModName) {
    $toRemove = @($ModName)
} elseif ($All) {
    $toRemove = @(Get-ChildItem -Path $ModsDir -Directory | Select-Object -ExpandProperty Name)
} else {
    if (Test-Path $SourceDir) {
        $toRemove = @(Get-ChildItem -Path $SourceDir -Directory | Select-Object -ExpandProperty Name)
    } else {
        $toRemove = @($Config.modName)
    }
}

if ($toRemove.Count -eq 0) {
    Write-Host "Nothing to clean." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "=== Cleaning Deployed Mods ===" -ForegroundColor Cyan
Write-Host ""

$removed = 0
foreach ($name in $toRemove) {
    $modPath = Join-Path $ModsDir $name
    if (Test-Path $modPath) {
        Remove-Item $modPath -Recurse -Force
        Write-Host "  Removed: $name" -ForegroundColor Green
        $removed++
    } else {
        Write-Host "  Not deployed: $name" -ForegroundColor DarkGray
    }
}

$buildInfo = Join-Path $ServerDir ".mod-build-info"
if (Test-Path $buildInfo) {
    Remove-Item $buildInfo -Force
}

Write-Host ""
Write-Host "Cleaned $removed mod(s)." -ForegroundColor Green
