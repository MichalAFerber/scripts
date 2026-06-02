# Archive-ExtraOneDriveFolders
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Finds extra OneDrive folders under the user profile (beyond the active OneDrive account), compresses each one into a timestamped .zip archive saved to the active OneDrive's Documents folder, and optionally deletes the originals after confirmation. A log file is created to record each action taken.
### How to Use
Run from a PowerShell prompt (elevated recommended):
```powershell
# Set execution policy if needed, then run:
Set-ExecutionPolicy -Scope Process Bypass
.\Archive-ExtraOneDriveFolders.ps1

# Dry run - see what would be archived/deleted without making changes:
.\Archive-ExtraOneDriveFolders.ps1 -DryRun

# Or use -WhatIf:
.\Archive-ExtraOneDriveFolders.ps1 -WhatIf
```
The script will prompt before deleting each original folder. Tested on Windows 11 / PowerShell 5+.
### What and Where to Tweak
- **Destination folder** (line 53): Archives go to `<ActiveOneDrive>\Documents`. Change `'Documents'` to a different subfolder if desired.
- **Compression level** (line 104): Set to `Optimal`. Change to `Fastest` or `NoCompression` if speed matters more than size.
- **Folder detection pattern** (line 63): Looks for folders matching `OneDrive*` under `$env:USERPROFILE`. Adjust if your OneDrive folders use a different naming convention.
- **Active account selection** (line 42): When multiple OneDrive accounts exist, the one with the most recent write time is chosen. Modify the sort logic if you prefer a different selection strategy.
