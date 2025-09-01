# Zip extra OneDrive folders to the active OneDrive\Documents, then remove the extras

$ErrorActionPreference = 'Stop'

# 1) Find active OneDrive root from registry
$activeRoot = (Get-ItemProperty "HKCU:\Software\Microsoft\OneDrive\Accounts\*" |
  Where-Object { $_.UserFolder -and (Test-Path $_.UserFolder) } |
  Select-Object -ExpandProperty UserFolder -First 1)

if (-not $activeRoot) { throw "Active OneDrive root not found." }

$dest = Join-Path $activeRoot 'Documents'

# Make sure destination exists
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }

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

  # 3a) Create the archive
  if (Test-Path $zip) { Remove-Item $zip -Force }
  Compress-Archive -Path (Join-Path $src '*') -DestinationPath $zip -CompressionLevel Optimal

  # Verify archive then remove source
  if ((Test-Path $zip) -and ((Get-Item $zip).Length -gt 0)) {
    Write-Host "Archive created: $zip  [Size=$([math]::Round((Get-Item $zip).Length/1MB,2)) MB]"
    # Delete the original (comment this next line out if you want to keep the folders)
    Remove-Item -LiteralPath $src -Recurse -Force
    Write-Host "Removed: $src"
  } else {
    Write-Warning "Archive failed/empty for: $src. Source not deleted."
  }
}

Write-Host "`nDone. Zips are in: $dest"
