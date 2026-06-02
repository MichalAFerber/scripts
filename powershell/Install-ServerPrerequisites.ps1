function Install-ServerPrerequisites {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$NoDatabases,
        [switch]$DryRun
    )

    #download URLs
    $webpi = "https://download.microsoft.com/download/C/F/F/CFF3A0B8-99D4-41A2-AE1A-496C08BEB904/WebPlatformInstaller_amd64_en-US.msi"
    $dac64 = "https://download.microsoft.com/download/5/E/4/5E4FCC45-4D26-4CBE-8E2D-79DB86A85F09/EN/x64/DacFramework.msi"
    $dac86 = "https://download.microsoft.com/download/5/E/4/5E4FCC45-4D26-4CBE-8E2D-79DB86A85F09/EN/x86/DacFramework.msi"
    $clr2016 = "https://download.microsoft.com/download/8/7/2/872BCECA-C849-4B40-8EBE-21D48CDF1456/ENU/x64/SQLSysClrTypes.msi"
    $smo = "https://download.microsoft.com/download/8/7/2/872BCECA-C849-4B40-8EBE-21D48CDF1456/ENU/x64/SharedManagementObjects.msi"
    $aspnet462 = "https://download.microsoft.com/download/F/9/4/F942F07D-F26F-4F30-B4E3-EBD54FABA377/NDP462-KB3151800-x86-x64-AllOS-ENU.exe"

    if ($DryRun) { $WhatIfPreference = $true }

    #for WMF
    Write-Verbose "Checking server for Windows Features - IIS..."
    $feature = Get-WindowsOptionalFeature -Online -FeatureName "IIS-WebServerRole" -Verbose:$VerbosePreference
    if ($feature.State -ne "Enabled") {
        if ($PSCmdlet.ShouldProcess("IIS-WebServerRole", "Enable Windows Feature")) {
            Write-Verbose "Windows Feature - IIS is not installed. Installing..."
            Enable-WindowsOptionalFeature -Online -All -FeatureName "IIS-WebServerRole" -Verbose:$VerbosePreference
            Write-Verbose "Windows Feature - IIS has been installed."
        }
    }
    else {
        Write-Verbose "Windows Feature - IIS has been detected. Skipping..."
    }

    Write-Verbose "Checking server for Windows Features - IIS Management Console..."
    $feature = Get-WindowsOptionalFeature -Online -FeatureName "IIS-WebServerManagementTools" -Verbose:$VerbosePreference
    if ($feature.State -ne "Enabled") {
        if ($PSCmdlet.ShouldProcess("IIS-WebServerManagementTools", "Enable Windows Feature")) {
            Write-Verbose "Windows Feature - IIS Management Console is not installed. Installing..."
            Enable-WindowsOptionalFeature -Online -All -FeatureName "IIS-WebServerManagementTools" -Verbose:$VerbosePreference
            Write-Verbose "Windows Feature - IIS Management Console has been installed."
        }
    }
    else {
        Write-Verbose "Windows Feature - IIS Management Console has been detected. Skipping..."
    }

    Write-Verbose "Checking server for Windows Features - ASP.NET 4.5..."
    $feature = Get-WindowsOptionalFeature -Online -FeatureName "IIS-ASPNET45" -Verbose:$VerbosePreference
    if ($feature.State -ne "Enabled") {
        if ($PSCmdlet.ShouldProcess("IIS-ASPNET45", "Enable Windows Feature")) {
            Write-Verbose "Windows Feature - ASP.NET 4.5 has not been installed. Installing..."
            Enable-WindowsOptionalFeature -Online -All -FeatureName "IIS-ASPNET45" -Verbose:$VerbosePreference
            Write-Verbose "ASP.NET 4.5 has been installed."
        }
    }
    else {
        Write-Verbose "Windows Feature - ASP.NET 4.5 has been detected. Skipping..."
    }

    #install webpi
    Write-Verbose "Checking server for Web Platform Installer..."
    if (-not (Test-Path "C:\Program Files\Microsoft\Web Platform Installer\WebpiCmd-x64.exe")) {
        if ($PSCmdlet.ShouldProcess("Web Platform Installer", "Download and install")) {
            Write-Verbose "Web Platform Installer was not detected. Installing..."
            Write-Verbose "Downloading Web Platform Installer from $webpi..."
            Invoke-WebRequest -Uri $webpi -OutFile WebPlatformInstaller_amd64_en-US.msi -Verbose:$VerbosePreference
            Write-Verbose "Installing Web Platform Installer..."
            Start-Process msiexec.exe -Wait -ArgumentList "/i WebPlatformInstaller_amd64_en-US.msi /quiet /qn /norestart"
            Write-Verbose "Web Platform Installer installed successfully."
        }
    }
    else {
        Write-Verbose "Web Platform Installer has been detected. Skipping..."
    }

    #install web deploy
    Write-Verbose "Checking server for Web Deploy 3.6..."
    #catch exception from Get-ChildItem
    if ((-not (Test-Path "hklm:software\microsoft\iis extensions\msdeploy")) -and ($null -eq (Get-ChildItem "hklm:software\microsoft\iis extensions\msdeploy"))) {
        if ($PSCmdlet.ShouldProcess("Web Deploy 3.6", "Install via Web PI")) {
            Write-Verbose "Web Deploy 3.6 was not detected. Installing with Web PI..."
            Start-Process "$env:programfiles\Microsoft\Web Platform Installer\WebpiCmd-x64.exe" -ArgumentList "/install /products:WDeploy36 /AcceptEULA" -NoNewWindow -Wait
            Write-Verbose "Web Deploy 3.6 has been successfully installed."
        }
    }
    else {
        Write-Verbose "Web Deploy 3.6 has been detected. Skipping..."
    }

    #install URL rewrite
    Write-Verbose "Checking server for URL Rewrite..."
    #catch exception from Get-ChildItem
    if ((-not (Test-Path "hklm:software\microsoft\iis extensions\url rewrite")) -and ($null -eq (Get-ChildItem "hklm:software\microsoft\iis extensions\url rewrite"))) {
        if ($PSCmdlet.ShouldProcess("URL Rewrite 2", "Install via Web PI")) {
            Write-Verbose "URL Rewrite was not detected. Installing with Web PI..."
            Start-Process "$env:programfiles\Microsoft\Web Platform Installer\WebpiCmd-x64.exe" -ArgumentList "/install /products:UrlRewrite2 /AcceptEULA" -NoNewWindow -Wait
            Write-Verbose "URL Rewrite has been successfully installed."
        }
    }
    else {
        Write-Verbose "URL Rewrite has been detected. Skipping..."
    }

    if (-not $NoDatabases) {
        #install dacfx
        Write-Verbose "Checking server for SQL Server 2016 Data-Tier Application Framework..."
        if (-not (Test-Path "${env:programfiles(x86)}\Microsoft SQL Server\130\DAC\bin\Microsoft.SqlServer.Dac.dll")) {
            if ($PSCmdlet.ShouldProcess("DACFx 2016 (x64 + x86)", "Download and install")) {
                Write-Verbose "SQL Server 2016 Data-Tier Application Framework was not detected. Installing..."

                Write-Verbose "Downloading DACFx x64 from $dac64..."
                Invoke-WebRequest -Uri $dac64 -OutFile DacFramework2016-x64.msi -Verbose:$VerbosePreference
                Write-Verbose "Download of DACFx x64 successful."
                Write-Verbose "Installing DACFx x64..."
                Start-Process msiexec.exe -NoNewWindow -Wait -ArgumentList "/i DacFramework2016-x64.msi /quiet /qn /norestart"
                Write-Verbose "Installation of DACFx x64 successful."

                Write-Verbose "Downloading DACFx x86 from $dac86..."
                Invoke-WebRequest -Uri $dac86 -OutFile DacFramework2016-x86.msi -Verbose:$VerbosePreference
                Write-Verbose "Download of DACFx x86 successful."
                Write-Verbose "Installing DACFx x86..."
                Start-Process msiexec.exe -NoNewWindow -Wait -ArgumentList "/i DacFramework2016-x86.msi /quiet /qn /norestart"
                Write-Verbose "Installation of DACFx x86 successful."

                Write-Verbose "SQL Server 2016 Data-Tier Application Framework has been successfully installed."
            }
        }
        else {
            Write-Verbose "SQL Server 2016 Data-Tier Application Framework has been detected. Skipping..."
        }

        #install CLR Types
        Write-Verbose "Checking server for CLR Types for SQL Server 2016..."
        if (-not (Test-Path "${env:programfiles(x86)}\Microsoft SQL Server\130\DAC\bin\Microsoft.SqlServer.Types.dll")) {
            if ($PSCmdlet.ShouldProcess("CLR Types for SQL Server 2016", "Download and install")) {
                Write-Verbose "CLR Types for SQL Server 2016 was not detected. Installing..."
                Write-Verbose "Downloading CLR Types 2016 from $clr2016..."
                Invoke-WebRequest -Uri $clr2016 -OutFile SQLSysClrTypes2016-x64.msi -Verbose:$VerbosePreference
                Write-Verbose "Download of CLR Types 2016 successful."
                Write-Verbose "Installing CLR Types 2016..."
                Start-Process msiexec.exe -ArgumentList "/i SQLSysClrTypes2016-x64.msi /quiet /qn /norestart" -NoNewWindow -Wait
                Write-Verbose "CLR Types for SQL Server 2016 has been successfully installed."
            }
        }
        else {
            Write-Verbose "CLR Types for SQL Server 2016 has been detected. Skipping..."
        }

        #install SQLSMO
        Write-Verbose "Checking server for SQL Server 2016 Management Objects..."
        if (-not (Test-Path "${env:programfiles(x86)}\Microsoft SQL Server\130\SDK\Assemblies\Microsoft.SqlServer.Smo.dll")) {
            if ($PSCmdlet.ShouldProcess("SQL Server 2016 Management Objects", "Download and install")) {
                Write-Verbose "SQL Server 2016 Management Objects was not detected. Installing..."
                Write-Verbose "Downloading SMO 2016 from $smo..."
                Invoke-WebRequest -Uri $smo -OutFile SharedManagementObjects-x64.msi -Verbose:$VerbosePreference
                Write-Verbose "Download of SMO 2016 successful."
                Write-Verbose "Installing SMO 2016..."
                Start-Process msiexec.exe -NoNewWindow -Wait -ArgumentList "/i SharedManagementObjects-x64.msi /quiet /qn /norestart"
                Write-Verbose "SQL Server 2016 Management Objects has been successfully installed."
            }
        }
        else {
            Write-Verbose "SQL Server 2016 Management Objects has been detected. Skipping..."
        }
    }

    #install .net 4.6.2
    Write-Verbose "Checking server for ASP.NET 4.6.2..."
    if (Get-ChildItem "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" | Get-ItemPropertyValue -Name Release | ForEach-Object { $_ -lt 394802 }) {
        if ($PSCmdlet.ShouldProcess("ASP.NET 4.6.2", "Download and install")) {
            Write-Verbose "ASP.NET 4.6.2 was not detected. Installing..."
            Write-Verbose "Downloading ASP.NET 4.6.2 from $aspnet462..."
            Invoke-WebRequest -Uri $aspnet462 -OutFile NDP462-KB3151800-x86-x64-AllOS-ENU.exe -Verbose:$VerbosePreference
            Write-Verbose "Download of ASP.NET 4.6.2 successful."
            Write-Verbose "Installing ASP.NET 4.6.2..."
            Start-Process NDP462-KB3151800-x86-x64-AllOS-ENU.exe -ArgumentList "/install /quiet" -NoNewWindow -Wait
            Write-Verbose "ASP.NET 4.6.2 has been successfully installed."
        }
    }
    else {
        Write-Verbose "ASP.NET 4.6.2 has been detected. Skipping..."
    }
}
