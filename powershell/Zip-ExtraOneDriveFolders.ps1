<#
.SYNOPSIS
    Zips extra OneDrive folders to the active OneDrive\Documents, then removes the extras.
.DESCRIPTION
    Finds all OneDrive* folders under the user profile except the active one,
    compresses each into a timestamped zip in the active OneDrive's Documents folder,
    and removes the original folder after successful archiving.
.PARAMETER DryRun
    If set, displays what actions would be taken without making any changes.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$DryRun
)

if ($DryRun) { $WhatIfPreference = $true }

$ErrorActionPreference = 'Stop'

# 1) Find active OneDrive root from registry
$activeRoot = (Get-ItemProperty "HKCU:\Software\Microsoft\OneDrive\Accounts\*" |
  Where-Object { $_.UserFolder -and (Test-Path $_.UserFolder) } |
  Select-Object -ExpandProperty UserFolder -First 1)

if (-not $activeRoot) { throw "Active OneDrive root not found." }

$dest = Join-Path $activeRoot 'Documents'

# Make sure destination exists
if (-not (Test-Path $dest)) {
    if ($PSCmdlet.ShouldProcess($dest, "Create destination directory")) {
        New-Item -ItemType Directory -Path $dest | Out-Null
    }
}

# 2) Find all OneDrive* folders under the profile except the active one
$extras = Get-ChildItem $env:USERPROFILE -Directory |
  Where-Object { $_.Name -like 'OneDrive*' -and ($_.FullName.TrimEnd('\') -ne $activeRoot.TrimEnd('\')) } |
  Select-Object -ExpandProperty FullName

if (-not $extras) { Write-Host "No extra OneDrive folders found."; return }

Write-Host "Active: $activeRoot"
Write-Host "Will archive these:"; $extras | ForEach-Object { Write-Host "  - $_" }

foreach ($src in $extras) {
  $name = Split-Path $src -Leaf
  $zip  = Join-Path $dest ("{0}-{1}.zip" -f $name,(Get-Date -Format 'yyyyMMdd-HHmmss'))

  Write-Host "`nArchiving: $src"
  Write-Host "     --> $zip"

  if ($PSCmdlet.ShouldProcess($src, "Compress to $zip")) {
    # 3a) Create the archive
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $src '*') -DestinationPath $zip -CompressionLevel Optimal

    # Verify archive then remove source
    if ((Test-Path $zip) -and ((Get-Item $zip).Length -gt 0)) {
      Write-Host "Archive created: $zip  [Size=$([math]::Round((Get-Item $zip).Length/1MB,2)) MB]"
    } else {
      Write-Warning "Archive failed/empty for: $src. Source not deleted."
      continue
    }
  }

  if ($PSCmdlet.ShouldProcess($src, "Remove original folder")) {
    Remove-Item -LiteralPath $src -Recurse -Force
    Write-Host "Removed: $src"
  }
}

Write-Host "`nDone. Zips are in: $dest"
