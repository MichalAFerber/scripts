# UrlRewriteResources
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Installs the IIS URL Rewrite Module 2.0 and configures the required allowed server variables (HTTPS, HTTP_X_FORWARDED_FOR, HTTP_X_FORWARDED_PROTO, REMOTE_ADDR) in the IIS applicationHost.config. This is commonly needed for reverse proxy setups where IIS needs to forward or rewrite headers.
### How to Use
Run from an elevated PowerShell prompt on a server with IIS installed:
```powershell
# Install and configure:
.\UrlRewriteResources.ps1

# Dry run - see what would happen without making changes:
.\UrlRewriteResources.ps1 -DryRun

# Or use -WhatIf:
.\UrlRewriteResources.ps1 -WhatIf
```
Prerequisites: IIS must be installed and the WebAdministration module must be available.
### What and Where to Tweak
- **$rewriteMsiUrl** (line 21): URL to the URL Rewrite MSI installer. Update if a newer version is released.
- **$productId** (line 23): The product GUID used to detect whether URL Rewrite is already installed. Must match the MSI's ProductCode.
- **$expected** (line 39): The list of server variables to add. Add or remove variable names as needed for your reverse proxy or rewrite rules.
