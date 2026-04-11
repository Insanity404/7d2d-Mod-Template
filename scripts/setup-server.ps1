<#
.SYNOPSIS
    Sets up a local 7 Days to Die dedicated server for mod development.

.DESCRIPTION
    Copies a 7D2D server installation to the local server/ directory and
    generates a dev-optimized server config. Auto-detects existing Steam
    installations or can use SteamCMD to download the dedicated server.

.PARAMETER SourcePath
    Path to an existing 7D2D server or game installation to copy from.
    If omitted, auto-detects from common Steam library paths.

.PARAMETER UseSteamCmd
    Download the dedicated server via SteamCMD (App ID 294420).
    SteamCMD must be available on PATH or in common install locations.

.PARAMETER Force
    Overwrite an existing server/ directory.

.PARAMETER ConfigOnly
    Regenerate serverconfig_dev.xml and start-dev.bat without re-copying
    the server files. Use this after changing mod.config.json server settings.

.EXAMPLE
    .\scripts\setup-server.ps1
    .\scripts\setup-server.ps1 -SourcePath "D:\SteamLibrary\steamapps\common\7 Days to Die"
    .\scripts\setup-server.ps1 -UseSteamCmd
    .\scripts\setup-server.ps1 -ConfigOnly
#>
param(
    [string]$SourcePath = "",
    [switch]$UseSteamCmd,
    [switch]$Force,
    [switch]$ConfigOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# === Load Config =============================================================

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$ConfigPath  = Join-Path $ProjectRoot "mod.config.json"

if (-not (Test-Path $ConfigPath)) {
    Write-Error "mod.config.json not found at: $ConfigPath"
    exit 1
}

$Config    = Get-Content $ConfigPath | ConvertFrom-Json
$ModName   = $Config.modName
$ServerCfg = $Config.server

$ServerDir  = Join-Path $ProjectRoot "server"
$DataDir    = Join-Path $ProjectRoot "data"
$MarkerFile = Join-Path $ServerDir ".7d2d-dev-server"

# === ConfigOnly: skip server copy, go straight to config gen =================

if ($ConfigOnly) {
    if (-not (Test-Path $MarkerFile)) {
        Write-Error "Dev server not found at '$ServerDir'. Run setup-server.ps1 without -ConfigOnly first."
        exit 1
    }
    Write-Host ""
    Write-Host "=== Regenerating Dev Server Config ===" -ForegroundColor Cyan
}

# === Server Copy (skipped when -ConfigOnly) ===================================

if (-not $ConfigOnly) {

    # Check for existing server
    if (Test-Path $MarkerFile) {
        if (-not $Force) {
            Write-Host ""
            Write-Host "Dev server already exists at: $ServerDir" -ForegroundColor Yellow
            Write-Host "Use -Force to overwrite, or -ConfigOnly to just regenerate the config." -ForegroundColor Yellow
            Write-Host ""
            exit 0
        }
        Write-Host "Force flag set - overwriting existing server..." -ForegroundColor Yellow
    }

    if ($UseSteamCmd) {
        Write-Host ""
        Write-Host "=== Downloading 7D2D Dedicated Server via SteamCMD ===" -ForegroundColor Cyan

        # Check PATH first, then common install locations
        $steamCmdPath = $null
        $fromPath = Get-Command steamcmd.exe -ErrorAction SilentlyContinue
        if ($fromPath) { $steamCmdPath = $fromPath.Source }

        if (-not $steamCmdPath) {
            $commonLocations = @(
                "C:\steamcmd\steamcmd.exe",
                "C:\SteamCMD\steamcmd.exe",
                "D:\steamcmd\steamcmd.exe",
                "D:\SteamCMD\steamcmd.exe",
                "C:\Program Files (x86)\Steam\steamcmd.exe",
                "C:\Program Files\Steam\steamcmd.exe"
            )
            foreach ($loc in $commonLocations) {
                if (Test-Path $loc) { $steamCmdPath = $loc; break }
            }
        }

        if (-not $steamCmdPath) {
            Write-Error "steamcmd.exe not found on PATH or in common locations. Download from https://developer.valvesoftware.com/wiki/SteamCMD"
            exit 1
        }

        Write-Host "  SteamCMD: $steamCmdPath" -ForegroundColor DarkGray

        New-Item -ItemType Directory -Path $ServerDir -Force | Out-Null
        & $steamCmdPath `
            +force_install_dir "$ServerDir" `
            +login anonymous `
            +app_update 294420 validate `
            +quit

        if ($LASTEXITCODE -ne 0) {
            Write-Error "SteamCMD failed with exit code $LASTEXITCODE"
            exit 1
        }

    } else {
        if (-not $SourcePath) {
            Write-Host ""
            Write-Host "=== Auto-detecting 7 Days to Die installation... ===" -ForegroundColor Cyan

            $steamPaths = @(
                "C:\Program Files (x86)\Steam\steamapps\common\7 Days to Die",
                "C:\Program Files\Steam\steamapps\common\7 Days to Die",
                "D:\Steam\steamapps\common\7 Days to Die",
                "D:\SteamLibrary\steamapps\common\7 Days to Die",
                "E:\Steam\steamapps\common\7 Days to Die",
                "E:\SteamLibrary\steamapps\common\7 Days to Die",
                "C:\Program Files (x86)\Steam\steamapps\common\7 Days to Die Dedicated Server",
                "D:\SteamLibrary\steamapps\common\7 Days to Die Dedicated Server"
            )

            $vdfPath = "C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf"
            if (Test-Path $vdfPath) {
                $vdf = Get-Content $vdfPath -ErrorAction SilentlyContinue
                $extraPaths = $vdf | Select-String '"path"\s+"(.+)"' | ForEach-Object {
                    $_.Matches[0].Groups[1].Value -replace '\\\\', '\'
                }
                foreach ($p in $extraPaths) {
                    $steamPaths += Join-Path $p "steamapps\common\7 Days to Die"
                    $steamPaths += Join-Path $p "steamapps\common\7 Days to Die Dedicated Server"
                }
            }

            foreach ($p in $steamPaths) {
                if (Test-Path (Join-Path $p "7DaysToDieServer.exe")) { $SourcePath = $p; break }
                if (Test-Path (Join-Path $p "7DaysToDie.exe"))       { $SourcePath = $p; break }
            }
        }

        if (-not $SourcePath -or -not (Test-Path $SourcePath)) {
            Write-Host ""
            Write-Host "ERROR: Could not find a 7D2D installation." -ForegroundColor Red
            Write-Host ""
            Write-Host "Options:" -ForegroundColor Yellow
            Write-Host "  1. Specify the path:   .\scripts\setup-server.ps1 -SourcePath `"C:\Path\To\7D2D`""
            Write-Host "  2. Download via Steam: .\scripts\setup-server.ps1 -UseSteamCmd"
            Write-Host ""
            exit 1
        }

        Write-Host ""
        Write-Host "=== Copying 7D2D Server ===" -ForegroundColor Cyan
        Write-Host "  Source: $SourcePath"
        Write-Host "  Dest:   $ServerDir"
        Write-Host ""
        Write-Host "This may take several minutes (~4-6 GB)..." -ForegroundColor Yellow

        if (Test-Path $ServerDir) { Remove-Item $ServerDir -Recurse -Force }

        # robocopy exit codes 0-7 are success (bit flags for copied/skipped/etc.)
        robocopy $SourcePath $ServerDir /E /NP /NFL /NDL /NJH /NJS | Out-Null
        if ($LASTEXITCODE -ge 8) {
            Write-Error "Robocopy failed with exit code $LASTEXITCODE"
            exit 1
        }
    }

    # Verify the server exe exists
    $serverExe = Join-Path $ServerDir "7DaysToDieServer.exe"
    if (-not (Test-Path $serverExe)) {
        Write-Error "7DaysToDieServer.exe not found in $ServerDir. Is this a dedicated server installation?"
        exit 1
    }
    Write-Host "  Server executable found." -ForegroundColor Green

    $dllPath = Join-Path $ServerDir "7DaysToDie_Data\Managed\Assembly-CSharp.dll"
    if (Test-Path $dllPath) {
        Write-Host "  Assembly-CSharp.dll found - XML schema validation will be available." -ForegroundColor Green
    } else {
        Write-Host "  Assembly-CSharp.dll not found - DLL-based validation will be skipped." -ForegroundColor Yellow
    }

    New-Item -ItemType Directory -Path (Join-Path $ServerDir "Mods") -Force | Out-Null
}

# === Generate Server Config ===================================================

$devConfigPath = Join-Path $ServerDir "serverconfig_dev.xml"

$serverConfigContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<ServerSettings>

  <!-- Server Identity -->
  <property name="ServerName"           value="$($ServerCfg.name)" />
  <property name="ServerDescription"    value="Development server for $($Config.modDisplayName)" />
  <property name="ServerWebsiteURL"     value="$($Config.modWebsite)" />
  <property name="ServerPassword"       value="$($ServerCfg.password)" />
  <property name="ServerPort"           value="$($ServerCfg.port)" />
  <property name="ServerMaxPlayerCount" value="$($ServerCfg.maxPlayers)" />

  <!-- Game Settings -->
  <property name="GameWorld"            value="$($ServerCfg.gameWorld)" />
  <property name="GameName"             value="DevWorld" />
  <property name="GameDifficulty"       value="$($ServerCfg.gameDifficulty)" />
  <property name="GameMode"             value="GameModeSurvival" />

  <!-- Day/Night -->
  <property name="DayNightLength"       value="$($ServerCfg.dayNightLength)" />
  <property name="DayLightLength"       value="18" />

  <!-- Blood Moon -->
  <property name="BloodMoonFrequency"   value="$($ServerCfg.bloodMoonFrequency)" />
  <property name="BloodMoonRange"       value="0" />
  <property name="BloodMoonEnemyCount"  value="8" />

  <!-- Loot / Drop -->
  <property name="LootAbundance"        value="100" />
  <property name="LootRespawnDays"      value="7" />
  <property name="DropOnDeath"          value="$($ServerCfg.dropOnDeath)" />
  <property name="DropOnQuit"           value="$($ServerCfg.dropOnQuit)" />

  <!-- Network (all off for fast dev iteration) -->
  <property name="TelnetEnabled"        value="false" />
  <property name="WebDashboardEnabled"  value="false" />
  <property name="EACEnabled"           value="false" />

  <!-- Keep all data local to this project (gitignored) -->
  <property name="UserDataFolder"       value="$DataDir\UserData" />

</ServerSettings>
"@

Set-Content -Path $devConfigPath -Value $serverConfigContent -Encoding UTF8
Write-Host "  Created: serverconfig_dev.xml" -ForegroundColor Green

# === Generate Batch Launcher ==================================================

$batchPath    = Join-Path $ServerDir "start-dev.bat"
$batchContent = "@echo off`r`nsetlocal`r`nset STEAM_APPID=251570`r`n" +
    "if not exist `"..\data\logs`" mkdir `"..\data\logs`"`r`n" +
    "if not exist `"..\data\Saves`" mkdir `"..\data\Saves`"`r`n" +
    "if not exist `"..\data\UserData`" mkdir `"..\data\UserData`"`r`n" +
    "for /f `"tokens=2 delims==`" %%I in ('wmic os get localdatetime /value') do set DT=%%I`r`n" +
    "7DaysToDieServer.exe -configfile=serverconfig_dev.xml -logfile `"..\data\logs\server_%DT:~0,8%_%DT:~8,6%.log`" -quit -batchmode -nographics`r`n"

Set-Content -Path $batchPath -Value $batchContent -Encoding ASCII
Write-Host "  Created: start-dev.bat" -ForegroundColor Green

# === Marker + Data Dirs =======================================================

$markerContent = "Generated by setup-server.ps1 on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`nMod: $($Config.modDisplayName)"
Set-Content -Path $MarkerFile -Value $markerContent -Encoding UTF8

foreach ($sub in @("logs", "Saves", "UserData")) {
    New-Item -ItemType Directory -Path (Join-Path $DataDir $sub) -Force | Out-Null
}

# === Done =====================================================================

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
if (-not $ConfigOnly) {
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Edit your mod XML in:  src\Mods\$ModName\Config\"
    Write-Host "  2. Build and deploy:       .\scripts\build.ps1"
    Write-Host "  3. Start the dev server:   .\scripts\start-server.ps1"
    Write-Host "     - OR - press F5 in VS Code"
    Write-Host ""
}
