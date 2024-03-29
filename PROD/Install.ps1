############################################################################################
######################################## 09/01/2024 ########################################
########################################   V04.00   ########################################
#################################### Installation Script ###################################
############################################################################################
# .Net methods - For hiding powershell console host
#Add-Type -Name Window -Namespace Console -MemberDefinition '
#[DllImport("Kernel32.dll")]
#public static extern IntPtr GetConsoleWindow();

#[DllImport("user32.dll")]
#public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
#'
#function HIDE-CONSOLE($hide)
#{
#    $consolePtr = [Console.Window]::GetConsoleWindow()
	#0 hide
#    [Console.Window]::ShowWindow($consolePtr, $hide)
#}
#Hide-Console 0

######################################## BEGIN GLOBAL variables declaration ########################################


$ScriptVersion = "V04.00 - 09/01/2024"							# English date format
$CompanyHive = "Cosmos IT"												# Provide your company name here
$OSVersion = [Environment]::OSVersion                           # Detect Windows version
$OSLang = Get-Culture                                           # Detect Windows language
$InstallDate = Get-Date                                         # Get current date
$user = [Environment]::UserName                                 # Detect current username

$Global:Err_Return = 0                                          # Error variable
$CurrentPath = Get-Location                                     # Get current directory
$PathExecute = (Convert-Path $CurrentPath)                      # Convert current directory


######################################## END GLOBAL variables declaration ########################################

#########################################################################################
######################################## Functions ######################################
#########################################################################################


# Writing in log file
Function LOG_WRITE($Text_ToWrite, $Result_ToWrite)
{
	$Time = (Get-Date -format 'HH:mm:ss')
	$LogPath = "C:\temp\sccm_logs\I_" + $Application_Name + " " + $Application_Version + ".LOG"
	$Line_ToWrite = $Time + " - " + $Text_ToWrite + "       " + $Result_ToWrite
	ADD-content -path $LogPath -value "$Line_ToWrite" -Encoding UTF8
	ADD-content -path $LogPath -value "`n"
}


# Write in events observer (Only for SYSTEM installation - Require admin rights)
function WriteInEventLog($EventCat, $ErrorType, $Step, $Result, $ErrorText)
{
	If ($Installtype -eq "SYSTEM")
	{
		$EventMessage = "Step: $Step.`n Action: $Result `r Error Type: $ErrorText"
		Write-EventLog -LogName $CompanyHive"_Script" -Source $Global:SourceName -EntryType $ErrorType -EventID $EventCat -Message $EventMessage
	}
}


# Evaluate computer status
Function EVALUATE_COMPUTER()
{
	LOG_WRITE "Installation date:" $InstallDate
	LOG_WRITE "Install script version:" $ScriptVersion
	LOG_WRITE "User Account:" $user
	LOG_WRITE "OS Version:" $OSVersion
	LOG_WRITE "OS Langage:" $OSLang
	LOG_WRITE "Install from:" $PathExecute
}


# Kill required process
Function KILL_PROCESS($Process_ToKill)
{
	Foreach ($process in $Process_ToKill)
	{
		LOG_WRITE "Process to kill:" $process
		WriteInEventLog 1 Information "Kill process" $Process "Process to kill."
		Try 
		{
			Stop-Process -name $process -force -ErrorAction 'Stop'
		}
		Catch [Microsoft.PowerShell.Commands.ProcessCommandException]
		{
			LOG_WRITE "Inactive process:" $process
			WriteInEventLog 1 Information "Kill process" $Process_ToKill "Inactive Process."
		}
	}
}


# Sign the application for inventory
Function INVENTORY_SETREGSIGN($App_Name, $App_Version, $App_Editor, $Install_Dir, $Techno, $Archi)
{
	$Reg_Name = $App_Name + " " + $App_Version
	If ($Archi -eq 32)
	{
		If ($Installtype -eq "SYSTEM")
		{
			$path = "HKLM:\Software\WOW6432Node"
		}
		else
		{
			$path = "HKCU:\Software"
		}
	}
	Else
	{
		If ($Installtype -eq "SYSTEM")
		{
			$path = "HKLM:\Software"
		}
		else
		{
			$path = "HKCU:\Software" 
		}
	}

	Try
	{
		# new-item -path $path\$CompanyHive -ErrorAction 'SilentlyContinue'
		# new-item -path $path\$CompanyHive\INVENTORY -ErrorAction 'SilentlyContinue'
		# new-item -path $path\$CompanyHive\INVENTORY\Packages -ErrorAction 'SilentlyContinue'
		new-item -path $path\$CompanyHive\INVENTORY\Packages\$Reg_Name -Force -ErrorAction 'SilentlyContinue'

		new-itemproperty -path $path\$CompanyHive\INVENTORY\Packages\$Reg_Name -name "InstallDate" -value $InstallDate -ErrorAction 'SilentlyContinue'
		new-itemproperty -path $path\$CompanyHive\INVENTORY\Packages\$Reg_Name -name "InstallLocation" -value $Install_Dir -ErrorAction 'SilentlyContinue'
		new-itemproperty -path $path\$CompanyHive\INVENTORY\Packages\$Reg_Name -name "Name" -value $App_Name -ErrorAction 'SilentlyContinue'
		new-itemproperty -path $path\$CompanyHive\INVENTORY\Packages\$Reg_Name -name "Publisher" -value $App_Editor -ErrorAction 'SilentlyContinue'
		new-itemproperty -path $path\$CompanyHive\INVENTORY\Packages\$Reg_Name -name "Version" -value $App_Version -ErrorAction 'SilentlyContinue'

		LOG_WRITE "Signed by registry key:" "Success"
		WriteInEventLog 1 Information "Signed by registry key:" "Success" "Application registered."
	}
	Catch
	{
		LOG_WRITE "Signed by registry key:" "Fail"
		WriteInEventLog 3 Error "Signed by registry key:" "Fail" "Application not registered."
	}
}


# Remove the application signature for inventory
Function INVENTORY_REMOVEREGSIGN($App_Name, $App_Version, $Archi)
{
	$Reg_Name = $App_Name + " " + $App_Version
	If ($Archi -eq 32)
	{
		If ($Installtype -eq "SYSTEM")
		{
			$path = "HKLM:\Software\WOW6432Node"
		}
		else
		{
			$path = "HKCU:\Software"
		}
	}
	Else
	{
		If ($Installtype -eq "SYSTEM")
		{
			$path = "HKLM:\Software"
		}
		else
		{
			$path = "HKCU:\Software"
		}
	}

	Try
	{
		If (Test-Path -path $path\$CompanyHive\INVENTORY\Packages\$Reg_Name)
		{
			Remove-Item $path\$CompanyHive\INVENTORY\Packages\$Reg_Name -Force -ErrorAction 'SilentlyContinue'

			LOG_WRITE "Remove application signature:" "Success"
			WriteInEventLog 1 Information "Remove application signature:" "Success" "Application signature removed."
		}
	}
	Catch
	{
		LOG_WRITE "Remove application signature:" "Fail"
		WriteInEventLog 3 Error "Remove application signature:" "Fail" "Application signature not removed."
	}
}


# Detect application on the computer
Function DETECT_INSTALLATION($ProductCode_ToCheck, $Key_ToCheck, $File_ToCheck, $regPart)
{
    $detectionTable = @{
        ProductCodeCheck = $false;
        ProductCodeDetect = $false;
        ProductCode_ToCheck_isEmpty = $true;
        RegCheck = $false;
		KeyDetect = $false;
		Key_ToCheck_isEmpty = $true;
        FileCheck = $false;
        FileDetect = $false;
        File_ToCheck_isEmpty = $true;
    }
	########## For MSI product code ##########
	If ([string]::IsNullOrEmpty($ProductCode_ToCheck))
	{
		$detectionTable.ProductCodeCheck = $false
		$detectionTable.ProductCodeDetect = $false
		$detectionTable.ProductCode_ToCheck_isEmpty = $true
	}
	Else
	{
		$detectionTable.ProductCodeCheck = $true
		$TestProductCode = Get-WmiObject -Class win32_product | Where-Object IdentifyingNumber -eq $ProductCode_ToCheck
		If ($TestProductCode)
		{
			$detectionTable.ProductCodeDetect = $true
		}
		else
		{
			$detectionTable.ProductCodeDetect = $false
		}
	}


	########## For registry key ##########
	If ([string]::IsNullOrEmpty($Key_ToCheck)) #Verification si la cle registre est renseignee
	{
		$detectionTable.RegCheck = $false
		$detectionTable.KeyDetect = $false
		$detectionTable.Key_ToCheck_isEmpty = $true
	}
	Else
	{
		If ($regPart -eq 32)
		{
			If ($Installtype -eq "SYSTEM")
			{
				$CurrentV = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\"
			}
			else
			{
				$CurrentV = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\"
			}
		}
		Else
		{
			If ($Installtype -eq "SYSTEM")
			{
				$CurrentV = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\"
			}
			else
			{
				$CurrentV = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\"
			}
		}
		$regkey = $CurrentV + $Key_ToCheck

		$detectionTable.RegCheck = $true
		$KeyExist = Test-Path $regkey

		If ($KeyExist -eq $true)
		{
			$detectionTable.KeyDetect = $true
		}
		Else
		{
			$detectionTable.KeyDetect = $false
		}
	}

	########## For file ##########
	If ([string]::IsNullOrEmpty($File_ToCheck))
	{
		$detectionTable.FileCheck = $false
		$detectionTable.FileDetect = $false
		$detectionTable.File_ToCheck_isEmpty = $true
	}
	Else
	{
		$detectionTable.FileCheck = $true
		$PosLastAntiSlash = $File_ToCheck.LastIndexOf("\")
		$file = $File_ToCheck.Substring($PosLastAntiSlash+1)
		$filepath = $File_ToCheck.Substring(0, $PosLastAntiSlash)

		If (($file).Contains("=") -eq $true)
		{
			$Fsplit = $file.Split("=")
			$FileName = $Fsplit[0]
			$FileVersion = $Fsplit[1]
		}
		Else
		{
			$FileName = $file
		}

		If ([string]::IsNullOrEmpty($FileVersion))
		{
			$TestFile = Test-Path $File_ToCheck
			If ($TestFile -eq $True)
			{
				$detectionTable.FileDetect = $true
			}
			Else
			{
				$detectionTable.FileDetect = $false
			}
		}
		Else
		{
			$Filename_AndPath = $filepath + "\" + $filename
			If ((Test-Path $Filename_AndPath) -eq $True)
			{
				$InstalledFileVersion = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($Filename_AndPath).FileVersion)
				If ($InstalledFileVersion -eq $FileVersion)
				{
					$detectionTable.FileDetect = $true
				}
				Else
				{
					$detectionTable.FileDetect = $false
				}
			}
			Else
			{
				$detectionTable.FileDetect = $false
			}
		}
	}
    return $detectionTable
}


# Detect APPX application (Microsoft Store)
Function DETECT_APPX($Name)
{
	$scanAppx = (Get-AppxPackage -Name $Name -User $user)
	return $scanAppx
}


# Install MSI file
Function EXECUTE_INSTALLATION_MSI($InstallFile, $Transform, $InstallParameters, $ProductCode, $Registry_Key, $File_Check, $Tempo, $regPart) 
{
	$InstallTable = DETECT_INSTALLATION $ProductCode $Registry_Key $File_Check $regPart

	if ($Global:Err_Return -eq 0)
	{
		if (($InstallTable.FileDetect -eq $false -AND $InstallTable.KeyDetect -eq $false -AND $InstallTable.ProductCodeDetect -eq $false) -OR ($InstallTable.Key_ToCheck_isEmpty -eq $true -AND $InstallTable.File_ToCheck_isEmpty -eq $true -AND $InstallTable.ProductCode_ToCheck_isEmpty -eq $true))
		{
			$Arguments = "/i `"$InstallFile`" TRANSFORMS=`"$Transform`" $InstallParameters"

			LOG_WRITE "Installation:" $InstallFile
			WriteInEventLog 1 Information "Installation:" $InstallFile "Install application."

			Start-Process -FilePath 'msiexec.exe' -ArgumentList "$Arguments" -Wait -Passthru
			Start-Sleep -s 60

			LOG_WRITE "Wait required:" $Tempo " seconds"
			Start-Sleep -s $Tempo

			$InstallTable = DETECT_INSTALLATION $ProductCode $Registry_Key $File_Check $regPart

			if (($InstallTable.FileDetect -eq $true) -OR ($InstallTable.KeyDetect -eq $true) -OR ($InstallTable.ProductCodeDetect -eq $true) -OR ($InstallTable.Key_ToCheck_isEmpty -eq $true -AND $InstallTable.File_ToCheck_isEmpty -eq $true -AND $InstallTable.ProductCode_ToCheck_isEmpty -eq $true))
			{
				LOG_WRITE "Installation Success:" $InstallFile
				WriteInEventLog 1 Information "Installation:" $InstallFile "Installation Success."
			}
			else 
			{
				$Global:Err_Return++
				LOG_WRITE "Installation Failed:" $InstallFile
				WriteInEventLog 3 Error "Installation Failed:" $InstallFile "Oh no ! I don't have a brain..."
			}
		}
		else 
		{
			LOG_WRITE "Application is already installed:" $InstallFile
			WriteInEventLog 1 Information "Application is already installed:" $InstallFile "Application is already installed. I go to bed."
		}
	}	
}


# Install MSI patch (MSP)
Function EXECUTE_PATCH_MSI($InstallFile, $InstallParameters, $ProductCode, $Registry_Key, $File_Check, $Tempo, $regPart) 
{
	$InstallTable = DETECT_INSTALLATION $ProductCode $Registry_Key $File_Check $regPart

	if ($Global:Err_Return -eq 0) 
	{
		if (($InstallTable.FileDetect -eq $false -AND $InstallTable.KeyDetect -eq $false -AND $InstallTable.ProductCodeDetect -eq $false) -OR ($InstallTable.Key_ToCheck_isEmpty -eq $true -AND $InstallTable.File_ToCheck_isEmpty -eq $true -AND $InstallTable.ProductCode_ToCheck_isEmpty -eq $true))
		{
			$Arguments = "/p `"$InstallFile`" $InstallParameters"

			LOG_WRITE "Patch installation:" $InstallFile
			WriteInEventLog 1 Information "Patch installation:" $InstallFile "Patch installation."
			
			Start-Process -FilePath 'msiexec.exe' -ArgumentList "$Arguments" -Wait -Passthru
			Start-Sleep -s 60

			LOG_WRITE "Wait required:" $Tempo " seconds"
			Start-Sleep -s $Tempo

			$InstallTable = DETECT_INSTALLATION $ProductCode $Registry_Key $File_Check $regPart

			if (($InstallTable.FileDetect -eq $true) -OR ($InstallTable.KeyDetect -eq $true) -OR ($InstallTable.ProductCodeDetect -eq $true) -OR ($InstallTable.Key_ToCheck_isEmpty -eq $true -AND $InstallTable.File_ToCheck_isEmpty -eq $true -AND $InstallTable.ProductCode_ToCheck_isEmpty -eq $true))
			{
				LOG_WRITE "Installation Success:" $InstallFile
				WriteInEventLog 1 Information "Installation Success:" $InstallFile "Patch installation success. I'm the best !"
			}
			else 
			{
				$Global:Err_Return++
				LOG_WRITE "Installation Failed:" $InstallFile
				WriteInEventLog 3 Error "Installation Failed:" $InstallFile "Patch installation failed. Please, don't tell it to mom !"
			}
		}
		else
		{
			LOG_WRITE "Patch already installed:" $InstallFile
			WriteInEventLog 1 Information "Patch already installed:" $InstallFile "Patch already installed. I like to do nothing."
		}
	}
}


# Install EXE file
Function EXECUTE_INSTALLATION_EXE($InstallFile, $InstallParameters, $Registry_Key, $File_Check, $Tempo, $regPart) 
{
	$InstallTable = DETECT_INSTALLATION "" $Registry_Key $File_Check $regPart
	
	if ($Global:Err_Return -eq 0) 
	{
		if (($InstallTable.FileDetect -eq $false -AND $InstallTable.KeyDetect -eq $false) -OR ($InstallTable.Key_ToCheck_isEmpty -eq $true -AND $InstallTable.File_ToCheck_isEmpty -eq $true))
		{
			LOG_WRITE "Application installation:" $InstallFile
			WriteInEventLog 1 Information "Application installation:" $InstallFile "Application installation."

			Start-Process -FilePath `"$InstallFile`" -ArgumentList "$InstallParameters" -Wait -Passthru
			Start-Sleep -s 60
			
			LOG_WRITE "Wait required:" $Tempo " seconds"
			Start-Sleep -s $Tempo

			$InstallTable = DETECT_INSTALLATION "" $Registry_Key $File_Check $regPart

			if (($InstallTable.FileDetect -eq $true) -OR ($InstallTable.KeyDetect -eq $true) -OR ($InstallTable.Key_ToCheck_isEmpty -eq $true -AND $InstallTable.File_ToCheck_isEmpty -eq $true)) 
			{
				LOG_WRITE "Installation Success:" $InstallFile
				WriteInEventLog 1 Information "Installation Success:" $InstallFile "Application installed. Oh yeah baby !"
			}
			else 
			{
				$Global:Err_Return++
				LOG_WRITE "Installation failed:" $InstallFile
				WriteInEventLog 3 Error "Installation failed:" $InstallFile "Application not installed. I need a break..."
			}
		}
		else 
		{
			LOG_WRITE "Application already installed:" $InstallFile 
			WriteInEventLog 1 Information "Application already installed:" $InstallFile "Application already installed. This is a good computer."
		}
	}
}


# Install APPX or APPBUNDLE file (MS Store)
Function EXECUTE_INSTALLATION_APPX($InstallExec, $InstallName, $Version)
{
	$InstallFile = $PathExecute + "\" + $InstallExec

	$appxEntry = DETECT_APPX $InstallName

	If ([string]::IsNullOrEmpty($appxEntry))
	{
		Add-AppxPackage -Path $InstallFile -ForceApplicationShutdown -ErrorAction 'SilentlyContinue'

		$appxEntry = DETECT_APPX $InstallName

		If (($appxEntry.Name -eq $InstallName) -AND ($appxEntry.Version -eq $Version))
		{
			LOG_WRITE "Installation Success:" $appxEntry.Name
			WriteInEventLog 1 Information "Installation Success:" $appxEntry.Name "Installation Success. Time to take a break."
		}
		else 
		{
			$Global:Err_Return++
			LOG_WRITE "Installation failed:" $InstallFile
			WriteInEventLog 3 Error "Installation failed:" $InstallFile "Installation failed. It's not my fault, don't kick me please..."
		} 
	}
	elseif ($appxEntry.Version -eq $Version) 
	{
		LOG_WRITE "Application already installed:" $appxEntry.Name
		WriteInEventLog 1 Information "Application already installed:" $appxEntry.Name "Application already installed..."
	}
	else 
	{
		Remove-AppxPackage -Package $appxEntry.PackageFullName -ErrorAction 'SilentlyContinue'

		LOG_WRITE "Migration:" $appxEntry.Name
		WriteInEventLog 1 Information "Migration:" $appxEntry.Name "Application migration in progress. I don't like old stuff."

		$appxEntry = DETECT_APPX $InstallName

		If ([string]::IsNullOrEmpty($appxEntry))
		{
			LOG_WRITE "Migration success:" $appxEntry.Name
			WriteInEventLog 1 Information "Migration success:" $appxEntry.Name "Migration success. :)"

			If ($Global:Err_Return -eq 0)
			{
				Add-AppxPackage -Path $InstallFile -ForceApplicationShutdown -ErrorAction 'SilentlyContinue'

				$appxEntry = DETECT_APPX $InstallName

				If (([String]::IsNullOrEmpty($appxEntry)) -OR ($appxEntry.Version -ne $Version))
				{
					$Global:Err_Return++
					LOG_WRITE "Installation failed:" $InstallFile
					WriteInEventLog 3 Error "Installation failed:" $InstallFile "Installation failed. Ooops"
				}
				else 
				{
					LOG_WRITE "Installation success:" $appxEntry.Name
					WriteInEventLog 1 Information "Installation success:" $appxEntry.Name "Installation success. Yeah !"
				}
			}
		}
		else 
		{
			$Global:Err_Return++
			LOG_WRITE "Migration failed:" $InstallFile
			WriteInEventLog 3 Error "Migration failed:" $InstallFile "Migration failed. I need administrator's help..."
		}
	}
}


# Install CAB file
Function EXECUTE_INSTALLATION_CAB($InstallExec)
{
	LOG_WRITE "Installation:" $InstallExec
	WriteInEventLog 1 Information "Installation:" $InstallExec "Application installation."

	$path = $PathExecute + "\" + $InstallExec
	dism /online /add-package /packagepath:"$path" /NoRestart /Quiet
	Start-Sleep -s 45

	LOG_WRITE "Installation done:" $InstallExec
	WriteInEventLog 1 Information "Installation completed:" $InstallExec "Must be tested."
}


# Install MSU file (KB, Windows update)
Function EXECUTE_INSTALLATION_MSU($InstallExec)
{
	LOG_WRITE "Installation:" $InstallExec
	WriteInEventLog 1 Information "Installation:" $InstallExec "Install Windows update file."

	$path = $PathExecute + "\" + $InstallExec
	wusa $path /quiet /NoRestart
	Start-Sleep -s 45

	LOG_WRITE "Installation done:" $InstallExec
	WriteInEventLog 1 Information "Installation completed:" $InstallExec "Windows is (maybe) up to date."
}


# MSI Migration
Function EXECUTE_MIGRATION_MSI($Product_Code, $Parameters, $ProductCode, $Registry_Key, $File_Check, $Tempo, $regPart)
{
	$InstallTable = DETECT_INSTALLATION $ProductCode $Registry_Key $File_Check $regPart

	if ($Global:Err_Return -eq 0) 
	{
		if (($InstallTable.FileDetect -eq $true -OR $InstallTable.KeyDetect -eq $true -OR $InstallTable.ProductCodeDetect -eq $true) -OR ($InstallTable.Key_ToCheck_isEmpty -eq $true -AND $InstallTable.File_ToCheck_isEmpty -eq $true -AND $InstallTable.ProductCode_ToCheck_isEmpty -eq $true)) 
		{
			LOG_WRITE "Application migration:" $Product_Code
			WriteInEventLog 1 Information "Application migration:" $Product_Code "Application migration. Va de retro Satanas !"

			$Arguments = "/X $Product_Code $Parameters"

			Start-Process -FilePath 'msiexec.exe' -ArgumentList "$Arguments" -Wait -Passthru
			Start-Sleep -s 60

			LOG_WRITE "Wait required:" $Tempo " seconds"
			Start-Sleep -s $Tempo

			$InstallTable = DETECT_INSTALLATION $ProductCode $Registry_Key $File_Check $regPart

			if (($InstallTable.FileDetect -eq $false -AND $InstallTable.KeyDetect -eq $false -AND $InstallTable.ProductCodeDetect -eq $false) -OR ($InstallTable.Key_ToCheck_isEmpty -eq $true -AND $InstallTable.File_ToCheck_isEmpty -eq $true -AND $InstallTable.ProductCode_ToCheck_isEmpty -eq $true)) 
			{
				LOG_WRITE "Migration success:" $Product_Code
				WriteInEventLog 1 Information "Migration success:" $Product_Code "Migration success. The devil is gone !"
			}
			else 
			{
				$Global:Err_Return++
				LOG_WRITE "Migration failed:" $Product_Code
				WriteInEventLog 3 Error "Migration failed:" $Product_Code "Migration failed. Run ! He is coming for you !"
			}
		}
		else 
		{
			LOG_WRITE "Application not installed:" $Product_Code
			WriteInEventLog 1 Information "Migration:" $Product_Code "Application not installed. This is a good day of hard work."
		}
	}
}


# EXE Migration
Function EXECUTE_MIGRATION_EXE($RemoveExe, $Parameters, $Registry_Key, $File_Check, $Tempo, $regPart)
{
	$InstallTable = DETECT_INSTALLATION "" $Registry_Key $File_Check $regPart

	if ($Global:Err_Return -eq 0) 
	{
		if (($InstallTable.FileDetect -eq $true -OR $InstallTable.KeyDetect -eq $true) -OR ($InstallTable.Key_ToCheck_isEmpty -eq $true -AND $InstallTable.File_ToCheck_isEmpty -eq $true))
		{
			LOG_WRITE "Application migration:" $RemoveExe
			WriteInEventLog 1 Information "Application migration:" $RemoveExe "Application migration. I have nothing to tell you."

			Start-Process -FilePath `"$RemoveExe`" -ArgumentList "$Parameters" -Wait -Passthru
			Start-Sleep -s 60

			LOG_WRITE "Wait required:" $Tempo " seconds"
			Start-Sleep -s $Tempo

			$InstallTable = DETECT_INSTALLATION "" $Registry_Key $File_Check $regPart

			if (($InstallTable.FileDetect -eq $false -AND $InstallTable.KeyDetect -eq $false) -OR ($InstallTable.Key_ToCheck_isEmpty -eq $true -AND $InstallTable.File_ToCheck_isEmpty -eq $true)) 
			{
				LOG_WRITE "Migration success:" $RemoveExe
				WriteInEventLog 1 Information "Migration success:" $RemoveExe "Migration success. Thanks to me."
			}
			else 
			{
				$Global:Err_Return++
				LOG_WRITE "Migration failed:" $RemoveExe
				WriteInEventLog 3 Error "Migration failed:" $RemoveExe "Migration failed. I'm a bad computer !"
			}
		}
		else 
		{
			LOG_WRITE "Application not installed:" $RemoveExe
			WriteInEventLog 1 Information "Application not installed:" $RemoveExe "Application not installed. I love Coca-Cola."
		}
	}
}


# Ask SCCM reboot
Function REBOOT_DEMAND($RCode)
{
	If ($RCode -eq 3010) 
	{
		LOG_WRITE "Reboot required:" "YES"
		WriteInEventLog 2 Warning "Reboot:" "Required" "Computer must be rebooted."
	}  
	else 
	{   
		LOG_WRITE "Reboot required:" "NO"
		WriteInEventLog 1 Information "Reboot:" "Not required" "Computer not need to be rebooted."
	}
	[System.Environment]::Exit($RCode)
}


######################################## BEGIN installation variables declaration ########################################

$Installtype = ""               # USER for user installation or SYSTEM for a system installation
$Application_Name = ""          # Application name
$Application_Version = ""       # Application version
$Editor = ""                    # Editor
$Install_Path = ""              # Install folder of the application
$Technologie = ""               # MSI, EXE, APPX, CAB, MSU or SCRIPT
$Arch = 64                        # 32 or 64
$Kill_Process = @()             # Process to kil. If neccessary. Ex: $Kill_Process = @("chrome","iexplore","firefox")
$Reboot_Code = 0                # 3010 for reboot - 0 by default

######################################## END installation variables declaration ########################################


######################################## Begin Bloc ###############################
$Global:SourceName = "SCCM_" + $Application_Name + "_" + $Application_Version

New-EventLog -LogName $CompanyHive"_Script" -Source $Global:SourceName -ErrorAction 'SilentlyContinue'

$RepTemp = (Test-Path -path 'C:\temp')
$RepLog = (Test-Path -path 'C:\temp\sccm_logs')

If ($RepTemp -eq $false) 
{
	New-Item -name 'temp' -path 'C:\' -type 'directory' -ErrorAction 'SilentlyContinue'
}

If ($RepLog -eq $false)
{
	New-Item -name 'sccm_logs' -path 'C:\temp' -type 'directory' -ErrorAction 'SilentlyContinue'
}

$LogPath = "C:\temp\sccm_logs\I_" + $Application_Name + " " + $Application_Version + ".LOG"
$LogExist = (Test-Path $LogPath)


If ($LogExist -eq $true)
{
	Remove-Item $LogPath
}

EVALUATE_COMPUTER
KILL_PROCESS $Kill_Process

######################################## END Begin Bloc ##############################

######################################## BEGIN Migration ########################################

# Bloc for Uninstall/Migration
#EXECUTE_MIGRATION_EXE "C:\Program Files\Mozilla Firefox\uninstall\helper.exe" "/S" "REG KEY" "C:\Program Files\Mozilla Firefox\firefox.exe=57.0.2" 0 32
#EXECUTE_MIGRATION_MSI "PRODUCT CODE or MSI FILE" "/qn /l* `"C:\temp\sccm_logs\Remove_7ZIP V18.01.log`"" "PRODUCT CODE" "REG KEY" "FILE" 0 64


If ($Global:Err_Return -eq 0)
{
	### Execute other actions: Suppress file, shortcuts...
	#INVENTORY_REMOVEREGSIGN "APP NAME" "APP VERSION" $Arch
}

######################################## END Migration ########################################


######################################## BEGIN Installation ########################################

### EXECUTE_INSTALLATION_EXE "EXECUTABLE" "ARGUMENTS" "REGISTRY KEYS" "FILE CHECK" TEMPO ARCH
### EXECUTE_INSTALLATION_MSI "EXECUTABLE" "TRANSFORM" "ARGUMENTS" "PRODUCT CODE" "REGISTRY KEY" "FILE CHECK" TEMPO ARCH
### EXECUTE_PATCH_MSI "EXECUTABLE" "ARGUMENTS" "PRODUCT CODE" "REGISTRY KEY" "FILE CHECK" TEMPO ARCH
### EXECUTE_INSTALLATION_APPX "EXECUTABLE" "PKG Name" "PKG Version"

#EXECUTE_INSTALLATION_MSI "7ZIP V18.01.msi" "" "/qn /l* `"C:\temp\sccm_logs\Install_7ZIP V18.01.log`"" "{23170F69-40C1-2702-1801-000001000000}" "" "" 0 64
#EXECUTE_INSTALLATION_EXE "Firefox V57.0.02.exe" " /S" "" "C:\Program Files\Mozilla Firefox\firefox.exe=57.0.2" 0 32        
#EXECUTE_INSTALLATION_APPX "CheckPointVPN_1.0.14.0_x64.Appx" "B4D42709.CheckPointVPN" 1.0.14.0
#EXECUTE_INSTALLATION_CAB "moncab.CAB"
#EXECUTE_INSTALLATION_MSU "monkb.MSU"

If ($Global:Err_Return -eq 0)
{
	### Execute other actions: Copy file, shortcuts...
	INVENTORY_SETREGSIGN $Application_Name $Application_Version $Editor $Install_Path $Technologie $Arch
}

######################################## END Installation #####################################

######################################## BEGIN Final ########################################
REBOOT_DEMAND $Reboot_Code
######################################## END Final ########################################