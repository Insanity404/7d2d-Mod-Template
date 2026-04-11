<#
.SYNOPSIS
    Validates 7 Days to Die mod XML files.

.DESCRIPTION
    Runs three validation phases:
      Phase 1 - XML well-formedness (all files)
      Phase 2 - Patch operation syntax (xpath, known operations)
      Phase 3 - Schema check against vanilla Data/Config/ XML files
      Phase 4 - (Experimental) Assembly-CSharp.dll identifier scanning

.PARAMETER ModPath
    Path to the mod folder (contains ModInfo.xml + Config/).

.PARAMETER ServerDir
    Path to the dev server directory. Used to locate vanilla XML files
    and Assembly-CSharp.dll. Defaults to ../server relative to the script.

.PARAMETER Strict
    Fail on warnings as well as errors.

.PARAMETER Quiet
    Suppress per-file OK messages; only print warnings and errors.

.PARAMETER DllScan
    Enable experimental DLL string scanning (Phase 4). Off by default.

.EXAMPLE
    .\scripts\validate-xml.ps1
    .\scripts\validate-xml.ps1 -ModPath "src\Mods\MyMod" -Strict
    .\scripts\validate-xml.ps1 -DllScan
#>
param(
    [string]$ModPath   = "",
    [string]$ServerDir = "",
    [switch]$Strict,
    [switch]$Quiet,
    [switch]$DllScan
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# === Setup ===================================================================

$ProjectRoot = Split-Path $PSScriptRoot -Parent

if (-not $ModPath) {
    $ConfigPath = Join-Path $ProjectRoot "mod.config.json"
    if (Test-Path $ConfigPath) {
        $cfg     = Get-Content $ConfigPath | ConvertFrom-Json
        $ModPath = Join-Path $ProjectRoot "src\Mods\$($cfg.modName)"
    }
}

if (-not $ServerDir) {
    $ServerDir = Join-Path $ProjectRoot "server"
}

$Errors   = [System.Collections.Generic.List[string]]::new()
$Warnings = [System.Collections.Generic.List[string]]::new()

function Add-Error([string]$msg)   { $Errors.Add($msg);   Write-Host "  [ERROR] $msg" -ForegroundColor Red }
function Add-Warning([string]$msg) { $Warnings.Add($msg); Write-Host "  [WARN]  $msg" -ForegroundColor Yellow }
function Add-OK([string]$msg)      { if (-not $Quiet) { Write-Host "  [OK]    $msg" -ForegroundColor Green } }

$KnownOperations = @(
    "append", "insertAfter", "insertBefore",
    "set", "setIfExists",
    "remove", "removeAttribute", "setAttribute"
)

# === Phase 1: Well-Formedness ================================================

Write-Host ""
Write-Host "--- Phase 1: XML Well-Formedness ---" -ForegroundColor DarkCyan

$xmlFiles = Get-ChildItem -Path $ModPath -Filter "*.xml" -Recurse -ErrorAction SilentlyContinue
if ($xmlFiles.Count -eq 0) {
    Add-Warning "No XML files found in: $ModPath"
} else {
    foreach ($file in $xmlFiles) {
        $rel = $file.FullName.Substring($ModPath.Length).TrimStart('\', '/')
        try {
            [xml]$doc = Get-Content $file.FullName -Raw -Encoding UTF8
            Add-OK $rel
        } catch {
            Add-Error "${rel}: $($_.Exception.Message)"
        }
    }
}

# === Phase 2: Patch Syntax ===================================================

Write-Host ""
Write-Host "--- Phase 2: Patch Operation Syntax ---" -ForegroundColor DarkCyan

$patchFiles = Get-ChildItem -Path $ModPath -Filter "*.xml" -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.DirectoryName -match "\\Config(\\|$)" }

foreach ($file in $patchFiles) {
    $rel = $file.FullName.Substring($ModPath.Length).TrimStart('\', '/')

    try {
        [xml]$doc = Get-Content $file.FullName -Raw -Encoding UTF8
    } catch {
        continue
    }

    $root = $doc.DocumentElement

    # Check all nodes with an xpath attribute
    $patchNodes = $doc.SelectNodes("//*[@xpath]")
    foreach ($node in $patchNodes) {
        $op    = $node.LocalName
        $xpath = $node.GetAttribute("xpath")

        if ($op -notin $KnownOperations -and $op -ne $root.LocalName) {
            Add-Warning "${rel}: Unknown patch operation '$op' (expected: $($KnownOperations -join ', '))"
        }

        if ([string]::IsNullOrWhiteSpace($xpath)) {
            Add-Error "${rel}: Patch node <$op> has an empty xpath attribute."
        }

        # Only warn if the xpath looks like a path expression (contains / or [ operators)
        # but is missing a leading / or . A bare root name like xpath="items" is valid.
        if ($xpath -and ($xpath -match '[/\[\]]') -and -not $xpath.StartsWith("/") -and -not $xpath.StartsWith(".")) {
            Add-Warning "${rel}: xpath '$xpath' contains path operators but doesn't start with / or // - may not match anything."
        }
    }

    # Validate ModInfo.xml required fields
    if ($file.Name -eq "ModInfo.xml") {
        foreach ($field in @("Name", "DisplayName", "Author", "Version")) {
            $node = $doc.SelectSingleNode("//xml/$field")
            if (-not $node -or [string]::IsNullOrWhiteSpace($node.GetAttribute("value"))) {
                Add-Warning "ModInfo.xml: Missing or empty <$field> element."
            }
        }
    }

    if ($Errors.Count -eq 0 -and $Warnings.Count -eq 0) {
        Add-OK $rel
    }
}

# === Phase 3: Vanilla Schema Check ===========================================

Write-Host ""
Write-Host "--- Phase 3: Vanilla Schema Check ---" -ForegroundColor DarkCyan

$vanillaConfigDir = Join-Path $ServerDir "Data\Config"

if (-not (Test-Path $vanillaConfigDir)) {
    Write-Host "  Skipped - vanilla config not found at: $vanillaConfigDir" -ForegroundColor DarkGray
    Write-Host "  (Run setup-server.ps1 to enable schema validation)" -ForegroundColor DarkGray
} else {
    $vanillaSchema = @{}

    foreach ($vFile in Get-ChildItem -Path $vanillaConfigDir -Filter "*.xml" -ErrorAction SilentlyContinue) {
        try {
            [xml]$vDoc = Get-Content $vFile.FullName -Raw -Encoding UTF8
            $attrs = $vDoc.SelectNodes("//@*") | ForEach-Object { $_.LocalName } | Sort-Object -Unique
            $vanillaSchema[$vFile.Name.ToLower()] = [System.Collections.Generic.HashSet[string]]::new(
                [string[]]$attrs,
                [System.StringComparer]::OrdinalIgnoreCase
            )
        } catch { }
    }

    Write-Host "  Loaded schema from $($vanillaSchema.Count) vanilla XML files." -ForegroundColor DarkGray

    foreach ($file in $patchFiles) {
        $rel = $file.FullName.Substring($ModPath.Length).TrimStart('\', '/')
        $key = $file.Name.ToLower()

        if (-not $vanillaSchema.ContainsKey($key)) { continue }

        $knownAttrs = $vanillaSchema[$key]

        try {
            [xml]$doc = Get-Content $file.FullName -Raw -Encoding UTF8
        } catch { continue }

        # xpath/op/type are patch system meta-attributes; cond is 7D2D's conditional
        # loader directive - valid in mod files but rarely in the vanilla base files.
        $skipAttrs    = @("xpath", "op", "type", "cond")
        $unknownAttrs = @($doc.SelectNodes("//@*") |
            Where-Object { $_.LocalName -notin $skipAttrs } |
            Where-Object { -not $knownAttrs.Contains($_.LocalName) } |
            ForEach-Object { $_.LocalName } |
            Sort-Object -Unique)

        foreach ($attr in $unknownAttrs) {
            Add-Warning "${rel}: Attribute '$attr' not found in vanilla $($file.Name) - check spelling."
        }

        if ($unknownAttrs.Count -eq 0) {
            Add-OK "${rel}: All attributes match vanilla schema."
        }
    }
}

# === Phase 4: DLL Identifier Scan (Experimental) ============================

if ($DllScan) {
    Write-Host ""
    Write-Host "--- Phase 4: Assembly-CSharp.dll Identifier Scan (Experimental) ---" -ForegroundColor DarkCyan

    $dllPath = Join-Path $ServerDir "7DaysToDie_Data\Managed\Assembly-CSharp.dll"

    if (-not (Test-Path $dllPath)) {
        Write-Host "  Skipped - DLL not found at: $dllPath" -ForegroundColor DarkGray
    } else {
        Write-Host "  Scanning: $dllPath" -ForegroundColor DarkGray

        try {
            # Read DLL bytes and search for string literals in the .NET metadata heap.
            # We look for null-bounded ASCII strings matching XML identifier patterns.
            $bytes = [System.IO.File]::ReadAllBytes($dllPath)
            $text  = [System.Text.Encoding]::UTF8.GetString($bytes)

            $candidates = [regex]::Matches($text, '(?<=[^\w])[a-z][a-zA-Z0-9]{2,39}(?=[^\w])') |
                ForEach-Object { $_.Value } |
                Sort-Object -Unique

            $xmlLike = $candidates | Where-Object {
                $_ -match '^[a-z][a-zA-Z]+$' -and
                $_.Length -ge 4 -and $_.Length -le 30 -and
                $_ -notmatch '^(this|null|true|false|void|bool|int|float|string|object|value|type|name|class|base)$'
            }

            Write-Host "  Found $($candidates.Count) candidates, $($xmlLike.Count) XML-like identifiers." -ForegroundColor DarkGray

            foreach ($file in $patchFiles) {
                $rel = $file.FullName.Substring($ModPath.Length).TrimStart('\', '/')
                try {
                    [xml]$doc = Get-Content $file.FullName -Raw -Encoding UTF8
                } catch { continue }

                $skipAttrs = @("xpath", "op", "type", "cond", "value", "name")
                $modAttrs  = @($doc.SelectNodes("//@*") |
                    Where-Object { $_.LocalName -notin $skipAttrs } |
                    ForEach-Object { $_.LocalName } |
                    Sort-Object -Unique)

                foreach ($attr in $modAttrs) {
                    if ($attr -notin $xmlLike -and $attr.Length -gt 3) {
                        Add-Warning "${rel}: '$attr' not found in DLL string table - possible typo?"
                    }
                }
            }
        } catch {
            Write-Host "  DLL scan failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# === Summary =================================================================

Write-Host ""
Write-Host "-----------------------------------------" -ForegroundColor DarkGray

$errCount  = $Errors.Count
$warnCount = $Warnings.Count

if ($errCount -eq 0 -and $warnCount -eq 0) {
    Write-Host "Validation passed - no issues found." -ForegroundColor Green
    exit 0
} elseif ($errCount -eq 0) {
    Write-Host "Validation passed with $warnCount warning(s)." -ForegroundColor Yellow
    if ($Strict) {
        Write-Host "Strict mode: treating warnings as errors." -ForegroundColor Red
        exit 1
    }
    exit 0
} else {
    Write-Host "Validation FAILED - $errCount error(s), $warnCount warning(s)." -ForegroundColor Red
    exit 1
}
