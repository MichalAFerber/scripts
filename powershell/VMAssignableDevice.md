# VMAssignableDevice
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Configures Hyper-V Discrete Device Assignment (DDA) to pass through a PnP device (such as a GPU or USB controller) from the host to a virtual machine. The script disables the device on the host, dismounts it, configures the VM with appropriate stop action and dynamic memory settings, then assigns the device to the VM.
### How to Use
Run from an elevated PowerShell prompt on a Hyper-V host:
```powershell
# Default settings (VM: EMSHVAC, device: VID_047D&PID_00F2&MI_01):
.\VMAssignableDevice.ps1

# Specify a different VM and device:
.\VMAssignableDevice.ps1 -VMName "MyVM" -InstanceId "*VID_10DE*"

# Dry run - see what would happen without making changes:
.\VMAssignableDevice.ps1 -DryRun

# Or use -WhatIf:
.\VMAssignableDevice.ps1 -WhatIf
```
Prerequisites: Hyper-V role must be installed, the PnpDevice module must be available, and the target VM must exist.
### What and Where to Tweak
- **$VMName** (default `EMSHVAC`): Change to match your target VM name, or pass via `-VMName` parameter.
- **$InstanceId** (default `*VID_047D&PID_00F2&MI_01*`): Wildcard pattern to match the PnP device. Use `Get-PnpDevice -PresentOnly` to find the correct InstanceId for your device.
- **Memory settings** (line 67): `MemoryMinimumBytes`, `MemoryMaximumBytes`, and `MemoryStartupBytes` are set to 1024MB, 4096MB, and 1024MB respectively. Adjust for your VM's requirements.
- **AutomaticStopAction** (line 63): Set to `TurnOff`. Other options are `Save` or `ShutDown`.
