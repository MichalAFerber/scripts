# dotnet-install
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Official Microsoft .NET CLI installer script. Downloads and installs the .NET SDK or a specific shared runtime. If an installation already exists in the target directory, it only updates if the requested version differs from the installed one. Supports channel-based (LTS, Current) or specific version installs.
### How to Use
Run from a PowerShell prompt:
```powershell
# Install latest LTS SDK:
.\dotnet-install.ps1

# Install a specific version:
.\dotnet-install.ps1 -Version 8.0.100

# Install a specific channel:
.\dotnet-install.ps1 -Channel 8.0

# Install only the ASP.NET Core runtime:
.\dotnet-install.ps1 -Runtime aspnetcore

# Install to a custom directory:
.\dotnet-install.ps1 -InstallDir "C:\dotnet"

# Dry run - shows what would be installed and download URLs without installing:
.\dotnet-install.ps1 -DryRun
```
No special prerequisites beyond PowerShell and internet access.
### What and Where to Tweak
- **-Channel** (default `LTS`): Set to `Current`, `LTS`, or a version like `8.0` or `8.0.1xx`.
- **-Version** (default `latest`): Specify a specific build version like `8.0.100`. Overrides channel.
- **-Quality**: Use `daily`, `signed`, `validated`, `preview`, or `GA` with a channel for quality-specific builds.
- **-InstallDir** (default `%LocalAppData%\Microsoft\dotnet`): Change where .NET gets installed.
- **-Architecture** (default auto-detected): Force `x64`, `x86`, `arm64`, or `arm`.
- **-Runtime**: Set to `dotnet`, `aspnetcore`, or `windowsdesktop` to install only a shared runtime instead of the full SDK.
- **-NoPath**: Prevents the script from modifying the PATH environment variable.
