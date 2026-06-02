# Install-ServerPrerequisites
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Installs a suite of prerequisites on a Windows Server for hosting ASP.NET web applications. It enables IIS and ASP.NET Windows Features, installs Web Platform Installer, Web Deploy 3.6, URL Rewrite, SQL Server 2016 DACFx, CLR Types, Shared Management Objects (SMO), and ASP.NET 4.6.2. Each component is checked before installation and skipped if already present.
### How to Use
Run from an elevated PowerShell prompt:
```powershell
# Import and run:
. .\Install-ServerPrerequisites.ps1
Install-ServerPrerequisites -Verbose

# Skip database-related components (DACFx, CLR Types, SMO):
Install-ServerPrerequisites -NoDatabases -Verbose

# Dry run - shows what would be installed without making changes:
Install-ServerPrerequisites -DryRun -Verbose
# Or use the built-in -WhatIf:
Install-ServerPrerequisites -WhatIf -Verbose
```
Requires administrator privileges and internet access to download installers.
### What and Where to Tweak
- **Download URLs** (lines 8-13): Update `$webpi`, `$dac64`, `$dac86`, `$clr2016`, `$smo`, and `$aspnet462` if newer versions are available or URLs change.
- **Web PI install path** (line 63): The check path `C:\Program Files\Microsoft\Web Platform Installer\WebpiCmd-x64.exe` assumes default install location.
- **SQL Server version paths** (lines 104, 130, 143): The `130` in the registry/file paths corresponds to SQL Server 2016. Update these if targeting a different SQL Server version.
- **ASP.NET version check** (line 162): The release number `394802` corresponds to .NET 4.6.2. Update for different .NET Framework versions.
