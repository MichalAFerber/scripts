# Zip-ExtraOneDriveFolders
## Michal Ferber
## Revised Date: 03/27/2026
### Description
A streamlined version of the OneDrive folder archiver. Finds all extra OneDrive folders under the user profile (excluding the active one), compresses each into a timestamped .zip file in the active OneDrive's Documents folder, and automatically removes the originals after successful archiving. Unlike Archive-ExtraOneDriveFolders, this script does not prompt for deletion confirmation.
### How to Use
Run from a PowerShell prompt:
```powershell
# Archive and remove extra OneDrive folders:
.\Zip-ExtraOneDriveFolders.ps1

# Dry run - see what would be archived/deleted without making changes:
.\Zip-ExtraOneDriveFolders.ps1 -DryRun

# Or use -WhatIf:
.\Zip-ExtraOneDriveFolders.ps1 -WhatIf
```
No special prerequisites beyond PowerShell 5+ and an active OneDrive account.
### What and Where to Tweak
- **Destination folder** (line 29): Archives go to `<ActiveOneDrive>\Documents`. Change `'Documents'` to target a different subfolder.
- **Compression level** (line 60): Set to `Optimal`. Change to `Fastest` if speed is preferred over compression ratio.
- **Folder detection pattern** (line 39): Matches `OneDrive*` under `$env:USERPROFILE`. Adjust the wildcard if needed.
- **Auto-delete behavior** (line 69): The original folder is removed automatically after a successful archive. Comment out the `Remove-Item` block if you want to keep originals.
