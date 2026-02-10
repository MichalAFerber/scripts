Get-Command -Module PnpDevice
Get-PnpDevice –PresentOnly | Sort-Object –Property Class
Get-VMHostAssignableDevice

$vmName = 'EMSHVAC'
$instanceId = '*VID_047D&PID_00F2&MI_01*'
$vm = Get-VM -Name $vmName
$dev = (Get-PnpDevice -PresentOnly).Where{ $_.InstanceId -like $instanceId }
Disable-PnpDevice -InstanceId $dev.InstanceId -Confirm:$false
Enable-PnpDevice -InstanceId $dev.InstanceId -Confirm:$true
$locationPath = (Get-PnpDeviceProperty -KeyName DEVPKEY_Device_LocationPaths -InstanceId $dev.InstanceId).Data[0] 
Dismount-VmHostAssignableDevice -LocationPath $locationPath -Force –Verbose
(Get-PnpDevice -PresentOnly).Where{ $_.InstanceId -like $instanceId }
Set-VM -VM $vm -AutomaticStopAction TurnOff
Set-VM -VM $vm -DynamicMemory -MemoryMinimumBytes 1024MB -MemoryMaximumBytes 4096MB -MemoryStartupBytes 1024MB
Add-VMAssignableDevice -VM $vm -LocationPath $locationPath –Verbose