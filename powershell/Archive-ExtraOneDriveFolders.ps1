<#
Archives (zips) any extra OneDrive folders under the user profile and deletes them
after a successful archive. Archives are saved to the active OneDrive's Documents folder.

Tested on Windows 11 / PowerShell 5+.

Usage:
  - Right-click PowerShell -> Run as administrator (not strictly required, but helpful).
  - Run:  Set-ExecutionPolicy -Scope Process Bypass; .\Archive-ExtraOneDriveFolders.ps1
  - Dry run:  .\Archive-ExtraOneDriveFolders.ps1 -DryRun
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$DryRun
)

if ($DryRun) { $WhatIfPreference = $true }

$ErrorActionPreference = 'Stop'

Write-Host "=== Archive Extra OneDrive Folders ===" -ForegroundColor Cyan

# 1) Discover the active OneDrive account + root
$accountKeys = Get-ChildItem -Path "HKCU:\Software\Microsoft\OneDrive\Accounts" -ErrorAction SilentlyContinue
if (-not $accountKeys) {
    throw "No active OneDrive accounts found in HKCU:\Software\Microsoft\OneDrive\Accounts. Aborting."
}

# Pick the first 'Business*' or 'Personal' record that has a valid UserFolder
$active = $accountKeys |
  ForEach-Object { Get-ItemProperty $_.PsPath } |
  Where-Object { $_.UserFolder -and (Test-Path $_.UserFolder) } |
  Select-Object DisplayName, UserEmail, UserFolder

if (-not $active) { throw "Found OneDrive Accounts, but none had a valid UserFolder path. Aborting." }

# If there are multiple, choose the one that matches what the OneDrive UI shows most often:
# Prefer a record whose UserFolder name matches an existing 'OneDrive*' folder with the most recent write time.
if ($active.Count -gt 1) {
    $active = $active | Sort-Object { (Get-Item $_.UserFolder).LastWriteTime } -Descending | Select-Object -First 1
}

$activeRoot      = $active.UserFolder
$activeLabel     = $active.DisplayName
$activeEmail     = $active.UserEmail

Write-Host ("Active OneDrive: {0}  ({1})" -f $activeLabel, $activeEmail)
Write-Host ("Active Root     : {0}" -f $activeRoot)
if (-not (Test-Path $activeRoot)) { throw "Active OneDrive root path does not exist on disk: $activeRoot" }

# Ensure destination folder = Active OneDrive\Documents
$destFolder = Join-Path $activeRoot 'Documents'
if (-not (Test-Path $destFolder)) {
    if ($PSCmdlet.ShouldProcess($destFolder, "Create destination directory")) {
        Write-Host "Creating destination folder: $destFolder"
        New-Item -ItemType Directory -Path $destFolder | Out-Null
    }
}

# 2) Find all OneDrive* folders in the user profile
$userProfile = $env:USERPROFILE
$allOneDriveFolders = Get-ChildItem -Path $userProfile -Directory |
    Where-Object { $_.Name -like 'OneDrive*' } |
    Select-Object -ExpandProperty FullName

if (-not $allOneDriveFolders) {
    Write-Host "No OneDrive* folders found under $userProfile. Nothing to do."
    return
}

# 3) Exclude the active OneDrive root
$extras = $allOneDriveFolders | Where-Object {
    $_.TrimEnd('\') -ne $activeRoot.TrimEnd('\')
}

if (-not $extras) {
    Write-Host "Only the active OneDrive folder exists. Nothing to archive."
    return
}

Write-Host "`nWill process the following extra OneDrive folders:" -ForegroundColor Yellow
$extras | ForEach-Object { Write-Host "  - $_" }

# Optional: create a log file inside active Documents
$logPath = Join-Path $destFolder ("OneDrive_Archive_Log_{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
if (-not $WhatIfPreference) {
    "Archive run at $(Get-Date)" | Out-File -FilePath $logPath -Encoding UTF8
}

foreach ($extraPath in $extras) {
    try {
        if (-not (Test-Path $extraPath)) {
            Write-Warning "Skipped missing path: $extraPath"
            if (-not $WhatIfPreference) { "SKIP  Missing: $extraPath" | Add-Content $logPath }
            continue
        }

        $name = Split-Path $extraPath -Leaf
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $zipName = ("{0}-{1}.zip" -f $name, $timestamp)
        $zipPath = Join-Path $destFolder $zipName

        Write-Host "`nZipping: $extraPath" -ForegroundColor Cyan
        Write-Host "   -> $zipPath"

        if ($PSCmdlet.ShouldProcess($extraPath, "Compress to $zipPath")) {
            # Ensure the zip doesn't already exist
            if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

            # 4) Zip the folder
            Compress-Archive -Path (Join-Path $extraPath '*') -DestinationPath $zipPath -CompressionLevel Optimal

            # Verify zip creation and non-zero length
            if (-not (Test-Path $zipPath)) { throw "Archive was not created: $zipPath" }
            $zipInfo = Get-Item $zipPath
            if ($zipInfo.Length -le 0)     { throw "Archive appears empty: $zipPath" }

            "OK    Archived $extraPath -> $zipPath  ($([math]::Round($zipInfo.Length/1MB,2)) MB)" | Add-Content $logPath
        }

        # 5) Confirm deletion
        if ($PSCmdlet.ShouldProcess($extraPath, "Delete original folder")) {
            $confirm = Read-Host "Delete the original folder? [Y/N] `n  $extraPath"
            if ($confirm -match '^(y|yes)$') {
                Write-Host "Removing: $extraPath" -ForegroundColor Yellow
                Remove-Item -LiteralPath $extraPath -Recurse -Force
                if (Test-Path $extraPath) {
                    throw "Deletion reported success but path still exists: $extraPath"
                }
                "DEL   $extraPath" | Add-Content $logPath
            } else {
                Write-Host "Skipped deletion for: $extraPath"
                "SKIP  Delete: $extraPath" | Add-Content $logPath
            }
        }
    }
    catch {
        $msg = $_.Exception.Message
        Write-Error "Failed on $extraPath : $msg"
        if (-not $WhatIfPreference) { "ERR   $extraPath : $msg" | Add-Content $logPath }
        # continue to next folder
    }
}

if (-not $WhatIfPreference) {
    Write-Host "`nDone. Log saved to: $logPath" -ForegroundColor Green
} else {
    Write-Host "`nDry run complete. No changes were made." -ForegroundColor Green
}
