param(
  [string]$Src,
  [string]$DestSub,
  [ValidateSet('copy','sync')]
  [string]$Mode = 'copy',
  [switch]$DryRun,
  [switch]$Verify,
  [int]$Transfers = 8,
  [int]$Checkers = 16,
  [string]$Bwlimit,
  [string]$LogDir = "$HOME/Logs",
  [string]$Excludes
)

# Load .env if present (simple KEY="VALUE" lines)
$envFile = Join-Path (Get-Location) ".env"
if (Test-Path -LiteralPath $envFile) {
  Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*#') { return }
    if ($_ -match '^\s*$') { return }
    $kv = $_ -replace '^export\s+',''
    $pair = $kv -split '=',2
    if ($pair.Count -eq 2) {
      $k = $pair[0].Trim()
      $v = $pair[1].Trim().Trim('"')
      if ($k -and $v) { set-item -path env:$k -value $v -ErrorAction SilentlyContinue }
    }
  }
}

$RemoteName = $env:WUB_REMOTE
if (-not $RemoteName) { $RemoteName = "wasabi-ferber" }
$Bucket = $env:WUB_BUCKET
if (-not $Bucket) { $Bucket = "ferber-storage" }
$Remote = "$RemoteName`:$Bucket"

if (-not $Src)     { $Src     = Read-Host "Source folder path" }
if (-not $DestSub) { $DestSub = "backup-$env:COMPUTERNAME/$(Get-Date -Format yyyy-MM-dd)"; Write-Host "Using default destination subfolder: $DestSub" }

if (-not (Test-Path -LiteralPath $Src)) {
  Write-Error "Source not found: $Src"
  exit 1
}

if (-not (Test-Path -LiteralPath $LogDir)) {
  New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
}

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $LogDir "wasabi-backup-$ts.txt"

$dest  = "$Remote/$DestSub"
$flags = @(
  "--fast-list",
  "--checkers", "$Checkers",
  "--transfers", "$Transfers",
  "--s3-storage-class","STANDARD",
  "--create-empty-src-dirs",
  "--progress",
  "--human-readable",
  "--log-file", "$logFile",
  "--log-level","INFO"
)

if ($Bwlimit) { $flags += @("--bwlimit",$Bwlimit) }
if ($DryRun)  { $flags += @("--dry-run") }
if ($Excludes) {
  if (-not (Test-Path -LiteralPath $Excludes)) {
    Write-Error "Excludes file not found: $Excludes"
    exit 2
  }
  $flags += @("--exclude-from", $Excludes)
}

Write-Host "========== Universal Wasabi Backup =========="
Write-Host ("Start:       {0}" -f (Get-Date))
Write-Host "Source:      $Src"
Write-Host "Destination: $dest"
Write-Host "Mode:        $Mode"
Write-Host "Dry-run:     $DryRun"
Write-Host "Verify:      $Verify"
Write-Host ("Excludes:    {0}" -f ($(if ($Excludes) { $Excludes } else { "<none>" })))
Write-Host "Log file:    $logFile"
Write-Host "============================================="
Write-Host ""

# record the exact command used
"----- COMMAND LINE -----" | Out-File -FilePath $logFile -Encoding UTF8
("rclone {0} ""{1}"" ""{2}"" {3}" -f $Mode, $Src, $dest, ($flags -join ' ')) | Out-File -FilePath $logFile -Append -Encoding UTF8
"------------------------`n" | Out-File -FilePath $logFile -Append -Encoding UTF8

# run transfer
& rclone $Mode "$Src" "$dest" $flags
if ($LASTEXITCODE -ne 0) {
  Write-Error "Transfer failed. See log: $logFile"
  ("End (failed): {0}" -f (Get-Date)) | Out-File -FilePath $logFile -Append -Encoding UTF8
  exit 3
}

if ($Verify) {
  Write-Host ""
  Write-Host "Starting verify pass (rclone check)..."
  "----- VERIFY (rclone check) -----" | Out-File -FilePath $logFile -Append -Encoding UTF8
  ("rclone check ""{0}"" ""{1}"" --one-way --size-only" -f $Src, $dest) | Out-File -FilePath $logFile -Append -Encoding UTF8
  & rclone check "$Src" "$dest" --one-way --size-only --log-file "$logFile" --log-level INFO
  if ($LASTEXITCODE -ne 0) {
    Write-Error "VERIFY differences detected. See log: $logFile"
    ("End (verify differences): {0}" -f (Get-Date)) | Out-File -FilePath $logFile -Append -Encoding UTF8
    exit 4
  }
}

Write-Host ""
Write-Host "All done."
("End: {0}" -f (Get-Date)) | Out-File -FilePath $logFile -Append -Encoding UTF8
Write-Host "Log: $logFile"
