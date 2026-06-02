<#
.SYNOPSIS
    Installs the IIS URL Rewrite Module and configures allowed server variables.
.DESCRIPTION
    Downloads and installs the IIS URL Rewrite Module 2.0, then adds required
    rewrite allowedServerVariables (HTTPS, HTTP_X_FORWARDED_FOR,
    HTTP_X_FORWARDED_PROTO, REMOTE_ADDR) to applicationHost.config.
.PARAMETER DryRun
    If set, displays what actions would be taken without making any changes.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$DryRun
)

if ($DryRun) { $WhatIfPreference = $true }

Import-Module WebAdministration -ErrorAction Stop

$rewriteMsiUrl = "http://download.microsoft.com/download/6/7/D/67D80164-7DD0-48AF-86E3-DE7A182D6815/rewrite_2.0_rtw_x64.msi"
$productName   = "IIS URL Rewrite Module 2"
$productId     = "EB675D0A-2C95-405B-BEE8-B42A65D23E11"

# 1) Install URL Rewrite module if not present
$installed = Get-WmiObject -Class Win32_Product | Where-Object { $_.IdentifyingNumber -eq "{$productId}" }
if (-not $installed) {
    if ($PSCmdlet.ShouldProcess($productName, "Download and install from $rewriteMsiUrl")) {
        Write-Host "Installing $productName..."
        $msiPath = Join-Path $env:TEMP "rewrite_2.0_rtw_x64.msi"
        Invoke-WebRequest -Uri $rewriteMsiUrl -OutFile $msiPath
        Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msiPath`" /quiet"
        Write-Host "$productName installed successfully."
    }
}
else {
    Write-Host "$productName is already installed. Skipping..."
}

# 2) Add rewrite allowedServerVariables
$expected = @("HTTPS", "HTTP_X_FORWARDED_FOR", "HTTP_X_FORWARDED_PROTO", "REMOTE_ADDR")
$current  = Get-WebConfiguration /system.webServer/rewrite/allowedServerVariables |
    Select-Object -ExpandProperty collection |
    Where-Object { $_.ElementTagName -eq "add" } |
    Select-Object -ExpandProperty name

$missing = $expected | Where-Object { $current -notcontains $_ }

if ($missing) {
    if ($PSCmdlet.ShouldProcess("allowedServerVariables: $($missing -join ', ')", "Add to applicationHost.config")) {
        Write-Host "Adding missing allowedServerVariables: $($missing -join ', ')"
        try {
            Start-WebCommitDelay
            $missing | ForEach-Object {
                Add-WebConfiguration /system.webServer/rewrite/allowedServerVariables -atIndex 0 -value @{ name = "$_" } -Verbose
            }
            Stop-WebCommitDelay -Commit $true
            Write-Host "Server variables added successfully."
        }
        catch [System.Exception] {
            Write-Error "Failed to add server variables: $_"
        }
    }
}
else {
    Write-Host "All expected allowedServerVariables are already configured."
}
