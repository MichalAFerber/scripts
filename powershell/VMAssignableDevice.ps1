<#
.SYNOPSIS
    Configures Hyper-V GPU/device passthrough (DDA) for a virtual machine.
.DESCRIPTION
    Dismounts a PnP device from the host and assigns it to a Hyper-V VM using
    Discrete Device Assignment (DDA). Also configures the VM for TurnOff stop
    action and dynamic memory.
.PARAMETER VMName
    Name of the Hyper-V VM to assign the device to. Default: EMSHVAC
.PARAMETER InstanceId
    Wildcard pattern for the PnP device InstanceId. Default: *VID_047D&PID_00F2&MI_01*
.PARAMETER DryRun
    If set, displays what actions would be taken without making any changes.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$VMName = 'EMSHVAC',
    [string]$InstanceId = '*VID_047D&PID_00F2&MI_01*',
    [switch]$DryRun
)

if ($DryRun) { $WhatIfPreference = $true }

# Discovery
Write-Host "Listing PnpDevice commands:"
Get-Command -Module PnpDevice

Write-Host "`nPresent PnP devices by class:"
Get-PnpDevice -PresentOnly | Sort-Object -Property Class

Write-Host "`nCurrent VM host assignable devices:"
Get-VMHostAssignableDevice

# Locate target device and VM
$vm  = Get-VM -Name $VMName
$dev = (Get-PnpDevice -PresentOnly).Where{ $_.InstanceId -like $InstanceId }

if (-not $dev) {
    Write-Error "No PnP device found matching InstanceId pattern: $InstanceId"
    return
}

Write-Host "`nTarget device: $($dev.FriendlyName) [$($dev.InstanceId)]"
Write-Host "Target VM:     $VMName"

# Disable the device on the host
if ($PSCmdlet.ShouldProcess($dev.InstanceId, "Disable PnP device")) {
    Disable-PnpDevice -InstanceId $dev.InstanceId -Confirm:$false
}

# Get the location path for DDA
$locationPath = (Get-PnpDeviceProperty -KeyName DEVPKEY_Device_LocationPaths -InstanceId $dev.InstanceId).Data[0]
Write-Host "Location path: $locationPath"

# Dismount from host
if ($PSCmdlet.ShouldProcess($locationPath, "Dismount device from VM host")) {
    Dismount-VmHostAssignableDevice -LocationPath $locationPath -Force -Verbose
}

Write-Host "`nDevice status after dismount:"
(Get-PnpDevice -PresentOnly).Where{ $_.InstanceId -like $InstanceId }

# Configure VM settings
if ($PSCmdlet.ShouldProcess($VMName, "Set AutomaticStopAction to TurnOff")) {
    Set-VM -VM $vm -AutomaticStopAction TurnOff
}

if ($PSCmdlet.ShouldProcess($VMName, "Configure dynamic memory (1024MB-4096MB)")) {
    Set-VM -VM $vm -DynamicMemory -MemoryMinimumBytes 1024MB -MemoryMaximumBytes 4096MB -MemoryStartupBytes 1024MB
}

# Assign device to VM
if ($PSCmdlet.ShouldProcess("$VMName <- $locationPath", "Add assignable device to VM")) {
    Add-VMAssignableDevice -VM $vm -LocationPath $locationPath -Verbose
}

Write-Host "`nDone. Device assigned to $VMName."
