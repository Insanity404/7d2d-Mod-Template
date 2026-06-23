<#
.SYNOPSIS
    Validates mod XML files and deploys them to the dev server.

.DESCRIPTION
    Runs XML validation then copies the mod from src/Mods/ into server/Mods/.
    Safe to run while the server is running.

.PARAMETER ModName
    Override which mod to build. Defaults to modName in mod.config.json.
    Use "all" to build every mod in src/Mods/.

.PARAMETER ValidateOnly
    Run validation without deploying.

.PARAMETER NoClear
    Skip clearing the destination mod folder before deploying.

.PARAMETER SkipValidation
    Deploy without running XML validation (not recommended).

.EXAMPLE
    .\scripts\build.ps1
    .\scripts\build.ps1 -ModName "all"
    .\scripts\build.ps1 -ValidateOnly
#>
param(
    [string]$ModName       = "",
    [ValidateSet("all", "xml", "csharp")]
    [string]$BuildType     = "all",
    [switch]$ValidateOnly,
    [switch]$NoClear,
    [switch]$SkipValidation,
    [switch]$Strict,
    [switch]$DllScan
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# === Load Config =============================================================

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$ConfigPath  = Join-Path $ProjectRoot "mod.config.json"

if (-not (Test-Path $ConfigPath)) {
    Write-Error "mod.config.json not found. Run from the project root."
    exit 1
}

$Config = Get-Content $ConfigPath | ConvertFrom-Json

if (-not $ModName) { $ModName = "all" }

$SourceDir = Join-Path $ProjectRoot "src\Mods"
$ServerDir = Join-Path $ProjectRoot "server"
$DestDir   = Join-Path $ServerDir "Mods"

# === Helpers =================================================================

$ErrorCount   = 0
$WarningCount = 0

function Write-OK([string]$msg)   { Write-Host "  [OK]   $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "  [WARN] $msg" -ForegroundColor Yellow; $script:WarningCount++ }
function Write-Fail([string]$msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red;    $script:ErrorCount++ }

# === Determine Mods to Build =================================================

$modsToBuild = @()
if ($ModName -eq "all") {
    $modsToBuild = @(Get-ChildItem -Path $SourceDir -Directory -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Name)
} else {
    $modsToBuild = @($ModName)
}

if ($modsToBuild.Count -eq 0) {
    Write-Error "No mods found in $SourceDir"
    exit 1
}

Write-Host ""
Write-Host "7D2D Mod Build" -ForegroundColor White

Write-Host "  Mods:   $($modsToBuild -join ', ')"
Write-Host "  Source: $SourceDir"
Write-Host "  Build:  $BuildType"
if (-not $ValidateOnly) {
    Write-Host "  Deploy: $DestDir"
}


# === Build C# DLL if requested ==============================================
if ($BuildType -in @("all", "csharp")) {
    foreach ($mod in $modsToBuild) {
        $csprojPath = Join-Path $SourceDir "$mod\Scripts\$mod.csproj"
        if (Test-Path $csprojPath) {
            Write-Host ""
            Write-Host "--- Building C# DLL for $mod ---" -ForegroundColor Cyan
            & dotnet build $csprojPath -c Release
            if ($LASTEXITCODE -ne 0) {
                Write-Fail "DLL compilation failed for $mod"
                exit 1
            }
        }
    }
}

# === Validate XML if requested ==============================================
if ($BuildType -in @("all", "xml") -and -not $SkipValidation) {
    Write-Host ""
    Write-Host "--- Validating XML ---" -ForegroundColor Cyan

    $validateScript = Join-Path $PSScriptRoot "validate-xml.ps1"

    foreach ($mod in $modsToBuild) {
        $modSrc  = Join-Path $SourceDir $mod
        if (-not (Test-Path $modSrc)) {
            Write-Fail "Mod source not found: $modSrc"
            continue
        }

        Write-Host ""
        Write-Host "  [$mod]" -ForegroundColor White

        $xmlFiles = Get-ChildItem -Path $modSrc -Filter "*.xml" -Recurse -ErrorAction SilentlyContinue
        if ($xmlFiles.Count -eq 0) {
            Write-Warn "No XML files found in $modSrc"
            continue
        }

        foreach ($file in $xmlFiles) {
            try {
                [xml]$doc = Get-Content $file.FullName -Raw -Encoding UTF8
                Write-OK $file.Name
            } catch {
                Write-Fail "$($file.Name): $($_.Exception.Message)"
            }
        }

        # Run enhanced validator if available
        if (Test-Path $validateScript) {
            $validateArgs = @{ ModPath = $modSrc; ServerDir = $ServerDir; Quiet = $true }
            if ($Strict)  { $validateArgs.Strict  = $true }
            if ($DllScan) { $validateArgs.DllScan = $true }
            & $validateScript @validateArgs
            if ($LASTEXITCODE -ne 0) { $script:ErrorCount++ }
        }
    }

    if ($ErrorCount -gt 0) {
        Write-Host ""
        Write-Host "Validation failed: $ErrorCount error(s), $WarningCount warning(s)" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    if ($WarningCount -gt 0) {
        Write-Host "Validation passed with $WarningCount warning(s)." -ForegroundColor Yellow
    } else {
        Write-Host "Validation passed." -ForegroundColor Green
    }
}

if ($ValidateOnly) {
    Write-Host ""
    Write-Host "Validate-only mode - skipping deploy." -ForegroundColor Yellow
    exit 0
}

# === Check Server ============================================================

$markerFile = Join-Path $ServerDir ".7d2d-dev-server"
if (-not (Test-Path $markerFile)) {
    Write-Host ""
    Write-Host "Dev server not found. Run setup first:" -ForegroundColor Yellow
    Write-Host "  .\scripts\setup-server.ps1" -ForegroundColor Yellow
    exit 1
}

New-Item -ItemType Directory -Path $DestDir -Force | Out-Null

# === Deploy ==================================================================

Write-Host ""
Write-Host "--- Deploying Mods ---" -ForegroundColor Cyan

$deployedCount = 0

foreach ($mod in $modsToBuild) {
    $modSrc  = Join-Path $SourceDir $mod
    $modDest = Join-Path $DestDir $mod

    if (-not (Test-Path $modSrc)) {
        Write-Fail "Source not found: $modSrc"
        continue
    }

    Write-Host ""
    Write-Host "  [$mod]" -ForegroundColor White

    if (-not $NoClear -and (Test-Path $modDest)) {
        Remove-Item $modDest -Recurse -Force
    }

    New-Item -ItemType Directory -Path $modDest -Force | Out-Null



    # Only deploy: ModInfo.xml, Config/, Resources/, Textures/, *.dll (root), README.md (if present)
    $deployList = @()
    $modInfoPath = Join-Path $modSrc "ModInfo.xml"
    if (Test-Path $modInfoPath) { $deployList += $modInfoPath }
    $configPath = Join-Path $modSrc "Config"
    if (Test-Path $configPath) { $deployList += $configPath }
    $resourcesPath = Join-Path $modSrc "Resources"
    if (Test-Path $resourcesPath) { $deployList += $resourcesPath }
    $texturesPath = Join-Path $modSrc "Textures"
    if (Test-Path $texturesPath) { $deployList += $texturesPath }
    $dlls = @(Get-ChildItem -Path $modSrc -Filter "*.dll" -File -ErrorAction SilentlyContinue)
    if ($dlls.Count -gt 0) { $deployList += @($dlls | ForEach-Object { $_.FullName }) }
    $readmePath = Join-Path $modSrc "README.md"
    if (Test-Path $readmePath) { $deployList += $readmePath }

    foreach ($item in $deployList) {
        $dest = Join-Path $modDest ([System.IO.Path]::GetFileName($item))
        if (Test-Path $item -PathType Container) {
            Copy-Item $item $dest -Recurse -Force
        } else {
            Copy-Item $item $dest -Force
        }
    }

    $deployedFilesCount = (Get-ChildItem -Path $modDest -Recurse -File -ErrorAction SilentlyContinue).Count
    Write-OK "Deployed $deployedFilesCount file(s) -> $modDest"
    $deployedCount++
}

# === Build Info ==============================================================

$buildInfo = [ordered]@{
    timestamp  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    mods       = $modsToBuild
    modVersion = $Config.modVersion
} | ConvertTo-Json

Set-Content -Path (Join-Path $ServerDir ".mod-build-info") -Value $buildInfo -Encoding UTF8

# === Summary =================================================================

Write-Host ""
Write-Host "Build complete: $deployedCount mod(s) deployed." -ForegroundColor Green
if ($ErrorCount -gt 0) {
    Write-Host "  $ErrorCount error(s) encountered." -ForegroundColor Red
    exit 1
}
