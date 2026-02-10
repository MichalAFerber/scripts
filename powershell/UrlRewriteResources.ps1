

			Package UrlRewrite
			{
				#Install URL Rewrite module for IIS
				DependsOn = "[WindowsFeaturesWebServer]windowsFeatures"
				Ensure = "Present"
				Name = "IIS URL Rewrite Module 2"
				Path = "http://download.microsoft.com/download/6/7/D/67D80164-7DD0-48AF-86E3-DE7A182D6815/rewrite_2.0_rtw_x64.msi"
				Arguments = "/quiet"
				ProductId = "EB675D0A-2C95-405B-BEE8-B42A65D23E11"
			}

			Script ReWriteRules
			{
				#Adds rewrite allowedServerVariables to applicationHost.config
				DependsOn = "[Package]UrlRewrite"
				SetScript = {
					$current = Get-WebConfiguration /system.webServer/rewrite/allowedServerVariables | select -ExpandProperty collection | ?{$_.ElementTagName -eq "add"} | select -ExpandProperty name
					$expected = @("HTTPS", "HTTP_X_FORWARDED_FOR", "HTTP_X_FORWARDED_PROTO", "REMOTE_ADDR")
					$missing = $expected | where {$current -notcontains $_}
					try
					{
						Start-WebCommitDelay 
						$missing | %{ Add-WebConfiguration /system.webServer/rewrite/allowedServerVariables -atIndex 0 -value @{name="$_"} -Verbose }
						Stop-WebCommitDelay -Commit $true 
					} 
					catch [System.Exception]
					{ 
						$_ | Out-String
					}
				}
				TestScript = {
					$current = Get-WebConfiguration /system.webServer/rewrite/allowedServerVariables | select -ExpandProperty collection | select -ExpandProperty name
					$expected = @("HTTPS", "HTTP_X_FORWARDED_FOR", "HTTP_X_FORWARDED_PROTO", "REMOTE_ADDR")
					$result = -not @($expected| where {$current -notcontains $_}| select -first 1).Count
					return $result
				}
				GetScript = {
					$allowedServerVariables = Get-WebConfiguration /system.webServer/rewrite/allowedServerVariables | select -ExpandProperty collection
					return $allowedServerVariables
				}
			}