############################################################################################
######################################## 27/02/2019 ########################################
########################################   V03.00   ########################################
###################################### RemovingScript ######################################
############################################################################################
# .Net methods - Masque la fenetre powershell
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


$ScriptVersion = "V03.00 - 27/02/2019"
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
	$LogPath = "C:\temp\sccm_logs\R_" + $Application_Name + " " + $Application_Version + ".LOG"
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
		Write-EventLog –LogName "CLS_Script" –Source $Global:SourceName –EntryType $ErrorType –EventID $EventCat –Message $EventMessage
	}
}


# Evaluate computer status
Function EVALUATE_COMPUTER()
{
    LOG_WRITE "Installation date:" $InstallDate
    LOG_WRITE "Remove script version:" $ScriptVersion
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
			Stop-Process -name $process -force -ErrorAction 'SilentlyContinue'
		}
		Catch [Microsoft.PowerShell.Commands.ProcessCommandException]
		{
			LOG_WRITE "Inactive process:" $process
			WriteInEventLog 1 Information "Kill process" $Process_ToKill "Inactive Process."
		}
	}
}


# Remove the application signature for inventory
Function CLS_REMOVEREGSIGN($App_Name, $App_Version, $Archi)
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
		If (Test-Path -path $path\CLS\INVENTORY\Packages\$Reg_Name)
		{
			Remove-Item $path\CLS\INVENTORY\Packages\$Reg_Name -force -ErrorAction 'SilentlyContinue'

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
	########## For MSI product code ##########
	If ([string]::IsNullOrEmpty($ProductCode_ToCheck))
	{
		$Global:ProductCodeCheck = $false
		$Global:ProductCodeDetect = $false
		$Global:ProductCode_ToCheck_isEmpty = $true
	}
	Else
	{
		$Global:ProductCodeCheck = $true
		$TestProductCode = Get-WmiObject -Class win32_product | Where-Object IdentifyingNumber -eq $ProductCode_ToCheck
		If ($TestProductCode)
		{
			$Global:ProductCodeDetect = $true
		}
		else
		{
			$Global:ProductCodeDetect = $false
		}
	}


	########## For registry key ##########
	If ([string]::IsNullOrEmpty($Key_ToCheck)) #Verification si la cle registre est renseignee
	{
		$Global:RegCheck = $false
		$Global:KeyDetect = $false
		$Global:Key_ToCheck_isEmpty = $true
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

		$Global:RegCheck = $true
		$KeyExist = Test-Path $regkey

		If ($KeyExist -eq $true)
		{
			$Global:KeyDetect = $true
		}
		Else
		{
			$Global:KeyDetect = $false
		}
	}

	########## For file ##########
	If ([string]::IsNullOrEmpty($File_ToCheck))
	{
		$Global:FileCheck = $false
		$Global:FileDetect = $false
		$Global:File_ToCheck_isEmpty = $true
	}
	Else
	{
		$Global:FileCheck = $true
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
				$Global:FileDetect = $true
			}
			Else
			{
				$Global:FileDetect = $false
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
					$Global:FileDetect = $true
				}
				Else
				{
					$Global:FileDetect = $false
				}
			}
			Else
			{
				$Global:FileDetect = $false
			}
		}
	}
}


# Detect APPX application (Windows Store)
Function DETECT_APPX($Name)
{
    $Global:scanAppx = (Get-AppxPackage -Name $Name -User $user)
    $Global:AppxName = ($Global:scanAppx).Name
    $Global:AppxVersion = ($Global:scanAppx).Version
    $Global:AppxLocation = ($Global:scanAppx).InstallLocation
    $Global:AppxFullName = ($Global:scanAppx).PackageFullName
}


# Uninstall APPX or APPXBUNDLE application
Function EXECUTE_UNINSTALL_APPX($InstallName)
{
    DETECT_APPX $InstallName

    If ([string]::IsNullOrEmpty($Global:scanAppx))
    {
        LOG_WRITE "Application not installed:" $InstallFile
        WriteInEventLog 1 Information "Application not installed:" $InstallFile "Nothing to do here."
    }
    else 
    {
        Remove-AppxPackage -Package $Global:AppxFullName -ErrorAction 'SilentlyContinue'

        LOG_WRITE "Removing application:" $Global:AppxName
        WriteInEventLog 1 Information "Removing application:" $Global:AppxName "Removing in progress."

        DETECT_APPX $InstallName

        If ([string]::IsNullOrEmpty($Global:scanAppx))
        {
            LOG_WRITE "Removing success:" $InstallFile
            WriteInEventLog 1 Information "Removing success:" $InstallFile "This application is gone."
        }
        else 
        {
            $Global:Err_Return = 1
            LOG_WRITE "Removing failed:" $InstallFile
            WriteInEventLog 3 Error "Removing failed:" $InstallFile "There is a problem here !"
        }
    }
}


# MSI Uninstall
Function EXECUTE_UNINSTALL_MSI($Product_Code, $Parameters, $ProductCode, $Registry_Key, $File_Check, $Tempo, $regPart)
{
	DETECT_INSTALLATION $ProductCode $Registry_Key $File_Check $regPart

	if ($Global:Err_Return -eq 0) 
	{
		if (($Global:FileDetect -eq $true -OR $Global:KeyDetect -eq $true -OR $Global:ProductCodeDetect -eq $true) -OR ($Global:Key_ToCheck_isEmpty -eq $true -AND $Global:File_ToCheck_isEmpty -eq $true -AND $Global:ProductCode_ToCheck_isEmpty -eq $true)) 
		{
			LOG_WRITE "Removing Application:" $Product_Code
			WriteInEventLog 1 Information "Removing Application:" $Product_Code "Removing in progress."

			$Arguments = "/X $Product_Code $Parameters"

			Start-Process -FilePath 'msiexec.exe' -ArgumentList "$Arguments" -Wait -Passthru
			Start-Sleep -s 60

			LOG_WRITE "Wait required:" $Tempo " seconds"
			Start-Sleep -s $Tempo

			DETECT_INSTALLATION $ProductCode $Registry_Key $File_Check $regPart

			if (($Global:FileDetect -eq $false -AND $Global:KeyDetect -eq $false -AND $Global:ProductCodeDetect -eq $false) -OR ($Global:Key_ToCheck_isEmpty -eq $true -AND $Global:File_ToCheck_isEmpty -eq $true -AND $Global:ProductCode_ToCheck_isEmpty -eq $true)) 
			{
				LOG_WRITE "Removing success:" $Product_Code
				WriteInEventLog 1 Information "Removing success:" $Product_Code "Removing success."
			}
			else 
			{
				$Global:Err_Return = 1
				LOG_WRITE "Removing failed:" $Product_Code
				WriteInEventLog 3 Error "Removing failed:" $Product_Code "Oh no ! There is a problem here !"
			}
		}
		else 
		{
			LOG_WRITE "Application not installed:" $Product_Code
			WriteInEventLog 1 Information "Application not installed:" $Product_Code "Nothing to do here."
		}
	}
}


# EXE Migration
Function EXECUTE_UNINSTALL_EXE($RemoveExe, $Parameters, $Registry_Key, $File_Check, $Tempo, $regPart)
{
	DETECT_INSTALLATION "" $Registry_Key $File_Check $regPart

	if ($Global:Err_Return -eq 0) 
	{
		if (($Global:FileDetect -eq $true -OR $Global:KeyDetect -eq $true) -OR ($Global:Key_ToCheck_isEmpty -eq $true -AND $Global:File_ToCheck_isEmpty -eq $true))
		{
			LOG_WRITE "Removing application:" $RemoveExe
			WriteInEventLog 1 Information "Removing application:" $RemoveExe "Removing in progress."

			Start-Process -FilePath `"$RemoveExe`" -ArgumentList "$Parameters" -Wait -Passthru
			Start-Sleep -s 60

			LOG_WRITE "Wait required:" $Tempo " seconds"
			Start-Sleep -s $Tempo

			DETECT_INSTALLATION "" $Registry_Key $File_Check $regPart

			if (($Global:FileDetect -eq $false -AND $Global:KeyDetect -eq $false) -OR ($Global:Key_ToCheck_isEmpty -eq $true -AND $Global:File_ToCheck_isEmpty -eq $true)) 
			{
				LOG_WRITE "Removing success:" $RemoveExe
				WriteInEventLog 1 Information "Removing success:" $RemoveExe "Good job !"
			}
			else 
			{
				$Global:Err_Return = 1
				LOG_WRITE "Removing failed:" $RemoveExe
				WriteInEventLog 3 Error "Removing failed:" $RemoveExe "Something gone wrong here."
			}
		}
		else 
		{
			LOG_WRITE "Application not installed:" $RemoveExe
			WriteInEventLog 1 Information "Application not installed:" $RemoveExe "I have nothing to do here."
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
$Arch =                         # 32 or 64
$Kill_Process = @()             # Process to kil. If neccessary. Ex: $Kill_Process = @("chrome","iexplore","firefox")
$Reboot_Code = 0                # 3010 for reboot

######################################## END installation variables declaration ########################################


######################################## Begin Bloc ###############################

$Global:SourceName = "SCCM_" + $Application_Name + "_" + $Application_Version

New-EventLog -LogName "CLS_Script" -Source $Global:SourceName -ErrorAction 'SilentlyContinue'

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

$LogPath = "C:\temp\sccm_logs\R_" + $Application_Name + " " + $Application_Version + ".LOG"
$LogExist = (Test-Path $LogPath)


If ($LogExist -eq $true)
{
    Remove-Item $LogPath
}

EVALUATE_COMPUTER
KILL_PROCESS $Kill_Process

######################################## END Begin Bloc ##############################

######################################## BEGIN Removing ########################################

#EXECUTE_UNINSTALL_EXE "C:\Program Files\Mozilla Firefox\uninstall\helper.exe" "/S" "REG KEY" "C:\Program Files\Mozilla Firefox\firefox.exe=57.0.2" TEMPO ARCHI
#EXECUTE_UNINSTALL_MSI "{23170F69-40C1-2702-1801-000001000000}" "/qn /l* `"C:\temp\sccm_logs\Remove_7ZIP V18.01.log`"" "{23170F69-40C1-2702-1801-000001000000}" "REG KEY" "FILE" 0 64
#EXECUTE_UNINSTALL_APPX "B4D42709.CheckPointVPN"


If ($Global:Err_Return -eq 0)
{
    ### Execute other actions: Suppress file, shortcuts...
    CLS_REMOVEREGSIGN $Application_Name $Application_Version $Arch
}        

######################################## END Removing ########################################

######################################## BEGIN Final ########################################
REBOOT_DEMAND $Reboot_Code
######################################## END Final ########################################