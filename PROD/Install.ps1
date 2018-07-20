############################################################################################
######################################## 18/07/2018 ########################################
########################################   V02.10   ########################################
################################## Script D'installation ###################################
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

######################################## Déclaration des variables GLOBALE ########################################


$OSVersion = [Environment]::OSVersion                           #Detection de la version de Windows
$OSLang = Get-Culture                                           #Detection de la langue de Windows
$InstallDate = Get-Date                                         #Detection de la date du debut de l'installation
$user = [Environment]::UserName                                 #Detection username

$Global:Err_Return = 0                                          #Fixe Err_Return a 0
$CurrentPath = Get-Location                                     #Recupere le repertoire courrant
$PathExecute = (Convert-Path $CurrentPath)                      #Convertit le resultat pour exploitation


######################################## Fin de déclaration des variables GLOBALE ########################################

#########################################################################################
######################################## Fonctions ######################################
#########################################################################################


Function LOG_WRITE($Text_ToWrite, $Result_ToWrite)
{
	# Ecriture dans le fichier log
	$Time = (Get-Date -format 'HH:mm:ss')                                           #Recuperation heures/minutes/secondes
	$LogPath = "C:\temp\sccm_logs\I_" + $Application_Name + " " + $Application_Version + ".LOG"                   #Creation du chemin + nom du log
	$Line_ToWrite = $Time + " - " + $Text_ToWrite + "       " + $Result_ToWrite     #Concatenation du texte
	ADD-content -path $LogPath -value "$Line_ToWrite"                               #Ecriture
	ADD-content -path $LogPath -value "`n"                                          #Saut de ligne
}


function EventLog($EventCat, $ErrorType, $Step, $Result, $ErrorText)
{
	If ($Installtype -eq "SYSTEM")
	{
		#Ecriture dans l'observateur des evenements
		$EventMessage = "Step: $Step.`n Action: $Result `r Error Type: $ErrorText"                                                          #Concatenation
		Write-EventLog –LogName "CLS_Script" –Source $Global:SourceName –EntryType $ErrorType –EventID $EventCat –Message $EventMessage     #Ecriture
	}
}


Function EVALUATE_COMPUTER()
{
	LOG_WRITE "Installation date:" $InstallDate                     #Ecriture log
	LOG_WRITE "User Account:" $user
	LOG_WRITE "OS Version:" $OSVersion                              #Ecriture log
	LOG_WRITE "OS Langage:" $OSLang                                 #Ecriture log
	LOG_WRITE "Install from:" $PathExecute
}


Function KILL_PROCESS($Process_ToKill)
{
	# Processus a tuer
	Foreach ($process in $Process_ToKill)
	{
		LOG_WRITE "Processus a tuer:" $process
		EventLog 1 Information "Kill process" $Process "Process to kill."
		Try 
		{
			Stop-Process -name $process -force -ErrorAction 'SilentlyContinue'                      #Fermeture des process
		}
		Catch [Microsoft.PowerShell.Commands.ProcessCommandException]
		{
			LOG_WRITE "Processus inactif:" $process
			EventLog 1 Information "Kill process" $Process_ToKill "Inactive Process."
		}
	}
}


Function CLS_SETREGSIGN($App_Name, $App_Version, $App_Editor, $Install_Dir, $Techno, $Archi)
{
	# Signature du package par clés de registre

	$Reg_Name = $App_Name + " " + $App_Version
	If ($Archi -eq 32)                              #Definition du chemin en fonction de l'architecture de l'appli
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
		new-item -path $path\CLS -ErrorAction 'SilentlyContinue'
		new-item -path $path\CLS\INVENTORY -ErrorAction 'SilentlyContinue'
		new-item -path $path\CLS\INVENTORY\Packages -ErrorAction 'SilentlyContinue'
		new-item -path $path\CLS\INVENTORY\Packages\$Reg_Name -ErrorAction 'SilentlyContinue'

		new-itemproperty -path $path\CLS\INVENTORY\Packages\$Reg_Name -name "InstallDate" -value $InstallDate -ErrorAction 'SilentlyContinue'
		new-itemproperty -path $path\CLS\INVENTORY\Packages\$Reg_Name -name "InstallLocation" -value $Install_Dir -ErrorAction 'SilentlyContinue'
		new-itemproperty -path $path\CLS\INVENTORY\Packages\$Reg_Name -name "Name" -value $App_Name -ErrorAction 'SilentlyContinue'
		new-itemproperty -path $path\CLS\INVENTORY\Packages\$Reg_Name -name "Publisher" -value $App_Editor -ErrorAction 'SilentlyContinue'
		new-itemproperty -path $path\CLS\INVENTORY\Packages\$Reg_Name -name "Version" -value $App_Version -ErrorAction 'SilentlyContinue'

		LOG_WRITE "Signature par clés de registre:" "Succes"
		EventLog 1 Information "Signature par clés de registre:" "Succes" "Registry keys registered."
	}
	Catch
	{
		LOG_WRITE "Signature par clés de registre:" "Erreur"
		EventLog 3 Error "Signature par clés de registre:" "Erreur" "Error on registry keys."
	}
}


Function CLS_REMOVEREGSIGN($App_Name, $App_Version, $Archi)
{
	# Suppression des anciennes signatures
	$Reg_Name = $App_Name + " " + $App_Version
	If ($Archi -eq 32)                              #Definition du chemin en fonction de l'architecture de l'appli
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
		Remove-Item $path\CLS\INVENTORY\Packages\$Reg_Name -force -ErrorAction 'SilentlyContinue'

		LOG_WRITE "Suppression signature par clés de registre:" "Succes"
		EventLog 1 Information "Suppression des signatures:" "Succes" "Suppression des anciennes clés de registre."
	}
	Catch
	{
		LOG_WRITE "Suppression signature par clés de registre:" "Erreur"
		EventLog 3 Error "Suppression des signatures:" "Error" "Suppression des anciennes clés de registre."
	}
}


Function DETECT_INSTALLATION($Key_ToCheck, $File_ToCheck)
{
		# Verification présence ou non + Installation si besoin
	If ($Arch -eq 32)                           #Definition path registre 32/64
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

	$regkey = $CurrentV + $Key_ToCheck         #Concatenation clé registre + path

	If ([string]::IsNullOrEmpty($Key_ToCheck)) #Verification si la cle registre est renseignee
	{
		$Global:RegCheck = $false
		$Global:KeyDetect = $false
		$Global:Key_ToCheck_isEmpty = $true
	}
	Else
	{
		$Global:RegCheck = $true
		$KeyExist = Test-Path $regkey           #Verification existance cle

		If ($KeyExist -eq $true)
		{
			$Global:KeyDetect = $true
		}
		Else
		{
			$Global:KeyDetect = $false
		}
	}

	If ([string]::IsNullOrEmpty($File_ToCheck))   #Verification si fichier a verifier est fournit
	{
		$Global:FileCheck = $false
		$Global:FileDetect = $false
		$Global:File_ToCheck_isEmpty = $true
	}
	Else
	{
		$Global:FileCheck = $true
		$PosLastAntiSlash = $File_ToCheck.LastIndexOf("\")        #Detecte derniere occurence "\" dans le path
		$file = $File_ToCheck.Substring($PosLastAntiSlash+1)      #Coupe a partir de la dernière "\" pour obtenir le nom fichier
		$filepath = $File_ToCheck.Substring(0, $PosLastAntiSlash) #Obtient le path sans non de fichier

		If (($file).Contains("=") -eq $true)                   #Verifie si présence "=2.255.22" check versioning
		{
			$Fsplit = $file.Split("=")                          #Coupe a partir du "=" et supprime le "="
			$FileName = $Fsplit[0]                              #Avant "=" : nom fichier + extension
			$FileVersion = $Fsplit[1]                           #Après "=" : version fichier
		}
		Else
		{
			$FileName = $file                                   #Si versioning non présent: nom fichier sans découpe
		}

		If ([string]::IsNullOrEmpty($FileVersion))              #Verifie si versionning present
		{
			$TestFile = Test-Path $File_ToCheck
			If ($TestFile -eq $True)                            #Verifie existence du fichier sur le pc
			{
				$Global:FileDetect = $true
			}
			Else
			{
				$Global:FileDetect = $false
			}
		}
		Else                                                    #Si versionning non present
		{
			$Filename_AndPath = $filepath + "\" + $filename                 #Concatenation path + nom fichier
			If ((Test-Path $Filename_AndPath) -eq $True)                    #Si fichier existant sur le pc
			{
				$InstalledFileVersion = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($Filename_AndPath).FileVersion)       #Récupération version du fichier sur pc
				If ($InstalledFileVersion -eq $FileVersion)                 #Comparaison version theorique et version effective
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

Function DETECT_APPX($Name)
{
	$Global:scanAppx = (Get-AppxPackage -Name $Name -User $user)
	$Global:AppxName = ($Global:scanAppx).Name
	$Global:AppxVersion = ($Global:scanAppx).Version
	$Global:AppxLocation = ($Global:scanAppx).InstallLocation
	$Global:AppxFullName = ($Global:scanAppx).PackageFullName
}

Function EXECUTE_INSTALLATION_MSI($InstallFile, $Transform, $InstallParameters, $Registry_Key, $File_Check, $Tempo) 
{
	# Verification présence ou non + Installation si besoin
	DETECT_INSTALLATION $Registry_Key $File_Check

	if ($Global:Err_Return -eq 0)
	{
		if (($Global:FileDetect -eq $false -AND $Global:KeyDetect -eq $false) -OR ($Global:Key_ToCheck_isEmpty -eq $true -AND $Global:File_ToCheck_isEmpty -eq $true)) 
		{
			$Arguments = "/i `"$InstallFile`" TRANSFORMS=`"$Transform`" $InstallParameters"

			LOG_WRITE "Installation:" $InstallFile
			EventLog 1 Information "Installation:" $InstallFile "Installation de l'application."

			Start-Process -FilePath 'msiexec.exe' -ArgumentList "$Arguments" -Wait -Passthru            #Lancement de l'executable
			Start-Sleep -s 60                                                                           #Attente dernieres actions

			LOG_WRITE "Delais requis:" $Tempo " secondes"

			Start-Sleep -s $Tempo                                                                       #Attente supplementaire requis

			DETECT_INSTALLATION $Registry_Key $File_Check

			if (($Global:FileDetect -eq $true) -OR ($Global:KeyDetect -eq $true) -OR ($Global:Key_ToCheck_isEmpty -eq $true -AND $Global:File_ToCheck_isEmpty -eq $true)) 
			{
				LOG_WRITE "Installation Réussie:" $InstallFile
				EventLog 1 Information "Installation:" $InstallFile "Installation de l'application réussie."
			}
			else 
			{
				$Global:Err_Return = 1
				LOG_WRITE "Echec de l'installation:" $InstallFile
				EventLog 3 Error "Echec de l'installation:" $InstallFile "Installation de l'application échoué."
			}
		}
		else 
		{
			LOG_WRITE "Application déjà installée:" $InstallFile
			EventLog 1 Information "Application déjà installée:" $InstallFile "L'application est déjà présente."
		}
	}	
}


Function EXECUTE_PATCH_MSI($InstallFile, $InstallParameters, $Registry_Key, $File_Check, $Tempo) 
{
	# Verification présence ou non + Installation si besoin
	DETECT_INSTALLATION $Registry_Key $File_Check

	if ($Global:Err_Return -eq 0) 
	{
		if (($Global:FileDetect -eq $false -AND $Global:KeyDetect -eq $false) -OR ($Global:Key_ToCheck_isEmpty -eq $true -AND $Global:File_ToCheck_isEmpty -eq $true)) 
		{
			$Arguments = "/p `"$InstallFile`" $InstallParameters"

			LOG_WRITE "Installation du patch:" $InstallFile
			EventLog 1 Information "Installation:" $InstallFile "Installation du patch."
			
			Start-Process -FilePath 'msiexec.exe' -ArgumentList "$Arguments" -Wait -Passthru            #Lancement de l'executable
			Start-Sleep -s 60                                                                           #Attente dernieres actions

			LOG_WRITE "Delais requis:" $Tempo " secondes"

			Start-Sleep -s $Tempo                                                                       #Attente supplementaire requis

			DETECT_INSTALLATION $Registry_Key $File_Check

			if (($Global:FileDetect -eq $true) -OR ($Global:KeyDetect -eq $true) -OR ($Global:Key_ToCheck_isEmpty -eq $true -AND $Global:File_ToCheck_isEmpty -eq $true)) 
			{
				LOG_WRITE "Installation Réussie:" $InstallFile
				EventLog 1 Information "Installation:" $InstallFile "Installation du patch réussie."
			}
			else 
			{
				$Global:Err_Return = 1
				LOG_WRITE "Echec de l'installation:" $InstallFile
				EventLog 3 Error "Echec de l'installation:" $InstallFile "Installation du patch échouée."
			}
		}
		else 
		{
			LOG_WRITE "Patch déjà installé:" $InstallFile
			EventLog 1 Information "Patch déjà installé:" $InstallFile "Le patch est déjà présent."
		}
	}	
}


Function EXECUTE_INSTALLATION_EXE($InstallFile, $InstallParameters, $Registry_Key, $File_Check, $Tempo) 
{
	# Verification présence ou non + Installation si besoin
	DETECT_INSTALLATION $Registry_Key $File_Check
	
	if ($Global:Err_Return -eq 0) 
	{
		if (($Global:FileDetect -eq $false -AND $Global:KeyDetect -eq $false) -OR ($Global:Key_ToCheck_isEmpty -eq $true -AND $Global:File_ToCheck_isEmpty -eq $true)) 
		{
			LOG_WRITE "Installation:" $InstallFile
			EventLog 1 Information "Installation:" $InstallFile "Installation de l'application."

			Start-Process -FilePath `"$InstallFile`" -ArgumentList "$InstallParameters" -Wait -Passthru     #Lancement de l'executable
			Start-Sleep -s 60                                                                               #Attente dernieres actions
			
			LOG_WRITE "Delais requis:" $Tempo " secondes"

			Start-Sleep -s $Tempo                                                                           #Attente supplementaire requis

			DETECT_INSTALLATION $Registry_Key $File_Check

			if (($Global:FileDetect -eq $true) -OR ($Global:KeyDetect -eq $true) -OR ($Global:Key_ToCheck_isEmpty -eq $true -AND $Global:File_ToCheck_isEmpty -eq $true)) 
			{
				LOG_WRITE "Installation réussie:" $InstallFile
				EventLog 1 Information "Installation:" $InstallFile "Installation de l'application réussie."
			}
			else 
			{
				$Global:Err_Return = 1
				LOG_WRITE "Echec de l'installation:" $InstallFile
				EventLog 3 Error "Echec de l'installation:" $InstallFile "Installation de l'application échoué."
			}
		}
		else 
		{
			LOG_WRITE "Application déjà installée:" $InstallFile 
			EventLog 1 Information "Application déjà installée:" $InstallFile "L'application est déjà présente."
		}
	}	
}


Function EXECUTE_INSTALLATION_APPX($InstallExec, $InstallName, $Version)
{
	$InstallFile = $PathExecute + "\" + $InstallExec

	DETECT_APPX $InstallName

	If ([string]::IsNullOrEmpty($Global:scanAppx))
	{
		Add-AppxPackage -Path $InstallFile -ForceApplicationShutdown -ErrorAction 'SilentlyContinue'

		DETECT_APPX $InstallName

		If (($Global:AppxName -eq $InstallName) -AND ($Global:AppxVersion -eq $Version))
		{
			LOG_WRITE "Installation réussie:" $Global:AppxName
			EventLog 1 Information "Installation:" $Global:AppxName "Installation de l'application réussie."
		}
		else 
		{
			$Global:Err_Return = 1
			LOG_WRITE "Echec de l'installation:" $InstallFile
			EventLog 3 Error "Echec de l'installation:" $InstallFile "Installation de l'application échoué."
		} 
	}
	elseif ($Global:AppxVersion -eq $Version) 
	{
		LOG_WRITE "Application déjà installée:" $Global:AppxName
		EventLog 1 Information "Application déjà installée:" $Global:AppxName "L'application est déjà présente."
	}
	else 
	{
		Remove-AppxPackage -Package $Global:AppxFullName -ErrorAction 'SilentlyContinue'

		LOG_WRITE "Migration:" $Global:AppxName
		EventLog 1 Information "Migration:" $Global:AppxName "Migration de l'application."

		DETECT_APPX $InstallName

		If ([string]::IsNullOrEmpty($Global:scanAppx))
		{
			LOG_WRITE "Migration réussie:" $Global:AppxName
			EventLog 1 Information "Migration:" $Global:AppxName "Migration de l'application réussie."

			If ($Global:Err_Return -eq 0)
			{
				Add-AppxPackage -Path $InstallFile -ForceApplicationShutdown -ErrorAction 'SilentlyContinue'

				DETECT_APPX $InstallName

				If (([String]::IsNullOrEmpty($Global:scanAppx)) -OR ($Global:AppxVersion -ne $Version))
				{
					$Global:Err_Return = 1
					LOG_WRITE "Echec de l'installation:" $InstallFile
					EventLog 3 Error "Echec de l'installation:" $InstallFile "Installation de l'application échoué."
				}
				else 
				{
					LOG_WRITE "Installation réussie:" $Global:AppxName
					EventLog 1 Information "Installation:" $Global:AppxName "Installation de l'application réussie."
				}
			}
		}
		else 
		{
			$Global:Err_Return = 1
			LOG_WRITE "Echec de la migration:" $InstallFile
			EventLog 3 Error "Echec de la migration:" $InstallFile "Migration de l'application échoué."
		}
	}

}

Function EXECUTE_INSTALLATION_CAB($InstallExec)
{
	LOG_WRITE "Installation:" $InstallExec
	EventLog 1 Information "Installation:" $InstallExec "Installation de l'application."

	$path = $PathExecute + "\" + $InstallExec
	dism /online /add-package /packagepath:"$path" /NoRestart /Quiet
	Start-Sleep -s 45
}


Function EXECUTE_INSTALLATION_MSU($InstallExec)
{
	LOG_WRITE "Installation:" $InstallExec
	EventLog 1 Information "Installation:" $InstallExec "Installation de la mise a jour Windows."

	$path = $PathExecute + "\" + $InstallExec
	wusa $path /quiet /NoRestart

	Start-Sleep -s 45
}


Function EXECUTE_MIGRATION_MSI($Product_Code, $Parameters, $Registry_Key, $File_Check, $Tempo)
{
	# Verification présence V N-1, N-2 etc... ou non + désinstallation si besoin
	DETECT_INSTALLATION $Registry_Key $File_Check

	if ($Global:Err_Return -eq 0) 
	{
		if (($Global:FileDetect -eq $true -OR $Global:KeyDetect -eq $true) -OR ($Global:Key_ToCheck_isEmpty -eq $true -AND $Global:File_ToCheck_isEmpty -eq $true)) 
		{
			LOG_WRITE "Migration:" $Product_Code
			EventLog 1 Information "Migration:" $Product_Code "Migration de l'application."

			$Arguments = "/X $Product_Code $Parameters"

			Start-Process -FilePath 'msiexec.exe' -ArgumentList "$Arguments" -Wait -Passthru                #Lancement de l'executable
			Start-Sleep -s 60                                                                               #Attente dernieres actions

			LOG_WRITE "Delais requis:" $Tempo " secondes"

			Start-Sleep -s $Tempo                                                                           #Attente supplementaire requis

			DETECT_INSTALLATION $Registry_Key $File_Check

			if (($Global:FileDetect -eq $false -AND $Global:KeyDetect -eq $false) -OR ($Global:Key_ToCheck_isEmpty -eq $true -AND $Global:File_ToCheck_isEmpty -eq $true)) 
			{
				LOG_WRITE "Migration réussie:" $Product_Code
				EventLog 1 Information "Migration réussie:" $Product_Code "Migration de l'application réussie."
			}
			else 
			{
				$Global:Err_Return = 1
				LOG_WRITE "Echec de la migration:" $Product_Code
				EventLog 3 Error "Echec de la migration:" $Product_Code "Migration de l'application échoué."
			}
		}
		else 
		{
			LOG_WRITE "Application non installée:" $Product_Code
			EventLog 1 Information "Migration:" $Product_Code "L'application n'est pas installée."
		}
	}
}


Function EXECUTE_MIGRATION_EXE($RemoveExe, $Parameters, $Registry_Key, $File_Check, $Tempo)
{
	# Verification présence V N-1, N-2 etc... ou non + désinstallation si besoin
	DETECT_INSTALLATION $Registry_Key $File_Check

	if ($Global:Err_Return -eq 0) 
	{
		if (($Global:FileDetect -eq $true -OR $Global:KeyDetect -eq $true) -OR ($Global:Key_ToCheck_isEmpty -eq $true -AND $Global:File_ToCheck_isEmpty -eq $true))
		{
			LOG_WRITE "Migration:" $RemoveExe
			EventLog 1 Information "Migration:" $RemoveExe "Migration de l'application."

			Start-Process -FilePath `"$RemoveExe`" -ArgumentList "$Parameters" -Wait -Passthru              #Lancement de l'executable
			Start-Sleep -s 60                                                                               #Attente dernieres actions

			LOG_WRITE "Delais requis:" $Tempo " secondes"

			Start-Sleep -s $Tempo                                                                           #Attente supplementaire requis

			DETECT_INSTALLATION $Registry_Key $File_Check

			if (($Global:FileDetect -eq $false -AND $Global:KeyDetect -eq $false) -OR ($Global:Key_ToCheck_isEmpty -eq $true -AND $Global:File_ToCheck_isEmpty -eq $true)) 
			{
				LOG_WRITE "Migration réussie:" $RemoveExe
				EventLog 1 Information "Migration réussie:" $RemoveExe "Migration de l'application réussie."
			}
			else 
			{
				$Global:Err_Return = 1
				LOG_WRITE "Echec de la migration:" $RemoveExe
				EventLog 3 Error "Echec de la migration:" $RemoveExe "Migration de l'application échoué."
			}
		}
		else 
		{
			LOG_WRITE "Application non installée:" $RemoveExe
			EventLog 1 Information "Migration:" $RemoveExe "L'application n'est pas installée."
		}
	}	
}


Function REBOOT_DEMAND($RCode)
{
	# Retourne code 3010 si besoin d'un reboot
	# Code interprété par SCCM

	If ($RCode -eq 3010) 
	{
		LOG_WRITE "Reboot requis:" "OUI"
		EventLog 2 Warning "Reboot:" "Requis" "L'ordinateur doit redémarrer pour finaliser l'installation du package."
	}  
	else 
	{   
		LOG_WRITE "Reboot requis:" "NON"
		EventLog 1 Information "Reboot:" "Non requis" "L'ordinateur n'a pas besoin de redémarrer pour finaliser l'installation du package."
	}
	[System.Environment]::Exit($RCode)
}


######################################## Déclaration des variables d'installation ########################################

$Installtype = ""               # USER for user installation or SYSTEM for a system installation
$Application_Name = ""          # Nom de l'application
$Application_Version = ""       # Version de l'application Vxx.xx.xx
$Editor = ""                    # Editeur
$Install_Path = ""              # Install folder of the application
$Technologie = ""               # MSI, EXE, APPX, CAB or MSU
$Arch =                         # 32 or 64
$Kill_Process = @()             # Process to kil. If neccessary. Ex: $Kill_Process = @("chrome","iexplore","firefox")
$Reboot_Code = 0                # 3010 for reboot

######################################## Fin Déclaration des variables d'installation ########################################


######################################## Begin Bloc ###############################
$Global:SourceName = "SCCM_" + $Application_Name + "_" + $Application_Version
If ([System.Diagnostics.EventLog]::SourceExists("CLS_Script") -Match $false -And (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) 
{
	New-EventLog -LogName "CLS_Script" -Source $Global:SourceName -ErrorAction 'SilentlyContinue'
}
If ([System.Diagnostics.EventLog]::SourceExists("CLS_Script") -Match $true -And (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) 
{
	Try 
	{
		New-EventLog -LogName "CLS_Script" -Source $Global:SourceName -ErrorAction 'SilentlyContinue'
	}
	Catch 
	{

	}
}

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

######################################## Migration ########################################


		# Bloc de désinstallation/Migration
		#EXECUTE_MIGRATION "EXECUTABLE" "ARGUMENTS" "REGISTRY KEYS" "FILE CHECK" "TEMPO"
#EXECUTE_MIGRATION_EXE "C:\Program Files\Mozilla Firefox\uninstall\helper.exe" "/S" "" "C:\Program Files\Mozilla Firefox\firefox.exe=57.0.2" 0
#EXECUTE_MIGRATION_MSI "{23170F69-40C1-2702-1801-000001000000}" "/qn /l* `"C:\temp\sccm_logs\Remove_7ZIP V18.01.log`"" "{23170F69-40C1-2702-1801-000001000000}" "" 0

# Made by .MSI

If ($Global:Err_Return -eq 0)
{
	### Execute other actions: Suppress file, shortcuts...
	CLS_REMOVEREGSIGN "N-X APPLICATION NAME" "APP VERSION" $Arch
}

######################################## Fin Migration ########################################


######################################## Installation ########################################

		#Bloc d'installation

		### EXECUTE_INSTALLATION_EXE "EXECUTABLE" "ARGUMENTS" "REGISTRY KEYS" "FILE CHECK" "TEMPO"
		### EXECUTE_INSTALLATION_MSI "EXECUTABLE" "TRANSFORM" "ARGUMENTS" "REGISTRY KEYS" "FILE CHECK" "TEMPO"
		### EXECUTE_PATCH_MSI "EXECUTABLE" "ARGUMENTS" "REGISTRY KEYS" "FILE CHECK" "TEMPO"
		### EXECUTE_INSTALLATION_APPX "EXECUTABLE" "PKG Name" "PKG Version"

#EXECUTE_INSTALLATION_MSI "7ZIP V18.01.msi" "" "/qn /l* `"C:\temp\sccm_logs\Install_7ZIP V18.01.log`"" "{23170F69-40C1-2702-1801-000001000000}" "" 0
#EXECUTE_INSTALLATION_EXE "Firefox V57.0.02.exe" " /S" "" "C:\Program Files\Mozilla Firefox\firefox.exe=57.0.2" 0        
#EXECUTE_INSTALLATION_APPX "CheckPointVPN_1.0.14.0_x64.Appx" "B4D42709.CheckPointVPN" 1.0.14.0
#EXECUTE_INSTALLATION_CAB "moncab.CAB"
#EXECUTE_INSTALLATION_MSU "monkb.MSU"

If ($Global:Err_Return -eq 0)
{
	### Execute other actions: Copy file, shortcuts...
	CLS_SETREGSIGN $Application_Name $Application_Version $Editor $Install_Path $Technologie $Arch
}

######################################## Fin Installation #####################################

######################################## Debut Finalisation ########################################
REBOOT_DEMAND $Reboot_Code
######################################## Fin Finalisation ########################################