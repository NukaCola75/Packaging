############################################################################################
######################################## 30/10/2018 ########################################
########################################   V02.20   ########################################
################################ Script de déinstallation ##################################
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
$user = [Environment]::UserName

$Global:Err_Return = 0
$CurrentPath = Get-Location
$PathExecute = (Convert-Path $CurrentPath)


######################################## Fin de déclaration des variables GLOBALE ########################################

#########################################################################################
######################################## Fonctions ######################################
#########################################################################################


Function LOG_WRITE($Text_ToWrite, $Result_ToWrite)
{
    # Ecriture dans le fichier log
    $Time = (Get-Date -format 'HH:mm:ss')
    $LogPath = "C:\temp\sccm_logs\R_" + $Application_Name + " " + $Application_Version + ".LOG"                    #Creation du chemin + nom du log
    $Line_ToWrite = $Time + " - " + $Text_ToWrite + "       " + $Result_ToWrite     #Concatenation du texte
    ADD-content -path $LogPath -value "$Line_ToWrite" -Encoding UTF8                                #Ecriture
    ADD-content -path $LogPath -value "`n"                                          #Ecriture
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
            Stop-Process -name $process -force -ErrorAction 'SilentlyContinue'
        }
        Catch [Microsoft.PowerShell.Commands.ProcessCommandException]
        {
            LOG_WRITE "Processus inactif:" $process
            EventLog 1 Information "Kill process" $Process_ToKill "Inactive Process."
        }
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
        If (Test-Path -path $path\CLS\INVENTORY\Packages\$Reg_Name)
		{
			Remove-Item $path\CLS\INVENTORY\Packages\$Reg_Name -force -ErrorAction 'SilentlyContinue'

			LOG_WRITE "Suppression signature par clés de registre:" "Succes"
			EventLog 1 Information "Suppression des signatures:" "Succes" "Suppression des anciennes clés de registre."
        }
    }
    Catch
    {
        LOG_WRITE "Suppression signature par clés de registre:" "Erreur"
        EventLog 3 Error "Suppression des signatures:" "Error" "Suppression des anciennes clés de registre."
    }     
}


Function DETECT_INSTALLATION($Key_ToCheck, $File_ToCheck, $regPart) 
{
        # Verification présence ou non + Installation si besoin
    If ($regPart -eq 32)                           #Definition path registre 32/64
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


Function EXECUTE_UNINSTALL_APPX($InstallName)
{
    DETECT_APPX $InstallName

    If ([string]::IsNullOrEmpty($Global:scanAppx))
    {
        LOG_WRITE "L'application n'est pas installée:" $InstallFile
        EventLog 1 Information "L'application n'est pas installée:" $InstallFile "Aucune action effectuée."
    }
    else 
    {
        Remove-AppxPackage -Package $Global:AppxFullName -ErrorAction 'SilentlyContinue'

        LOG_WRITE "Désinstallation de l'application:" $Global:AppxName
        EventLog 1 Information "Désinstallation de l'application:" $Global:AppxName "Désinstallation de l'application."

        DETECT_APPX $InstallName

        If ([string]::IsNullOrEmpty($Global:scanAppx))
        {
            LOG_WRITE "Désinstallation réussie:" $InstallFile
            EventLog 1 Information "Désinstallation réussie:" $InstallFile "Désinstallation de l'application réussie."
        }
        else 
        {
            $Global:Err_Return = 1
            LOG_WRITE "Echec de la désinstallation:" $InstallFile
            EventLog 3 Error "Echec de la désinstallation:" $InstallFile "Désinstallation de l'application échoué."
        }
    }
}


Function EXECUTE_UNINSTALL_MSI($Product_Code, $Parameters, $Registry_Key, $File_Check, $Tempo, $regPart)
{
    # Verification présence V N-1, N-2 etc... ou non + désinstallation si besoin
    DETECT_INSTALLATION $Registry_Key $File_Check $regPart
    
    if ($Global:Err_Return -eq 0) 
    {
        if (($Global:FileDetect -eq $true -OR $Global:KeyDetect -eq $true) -OR ($Global:Key_ToCheck_isEmpty -eq $true -AND $Global:File_ToCheck_isEmpty -eq $true)) 
        {
            LOG_WRITE "Désinstallation:" $Product_Code
            EventLog 1 Information "Désinstallation:" $Product_Code "Désinstallation de l'application."

			$Arguments = "/X $Product_Code $Parameters"
			
			Start-Process -FilePath 'msiexec.exe' -ArgumentList "$Arguments" -Wait -Passthru
            Start-Sleep -s 60
            
            LOG_WRITE "Delais requis:" $Tempo " secondes"

            Start-Sleep -s $Tempo

            DETECT_INSTALLATION $Registry_Key $File_Check $regPart

            if (($Global:FileDetect -eq $false -AND $Global:KeyDetect -eq $false) -OR ($Global:Key_ToCheck_isEmpty -eq $true -AND $Global:File_ToCheck_isEmpty -eq $true))
            {
                LOG_WRITE "Désinstallation réussie:" $Product_Code
                EventLog 1 Information "Désinstallation réussie:" $Product_Code "Désinstallation de l'application réussie."
            }
            else 
            {
                $Global:Err_Return = 1
                LOG_WRITE "Echec de la désinstallation:" $Product_Code
                EventLog 3 Error "Echec de la désinstallation:" $Product_Code "Désinstallation de l'application échoué."
            }
        }
		else 
        {
            LOG_WRITE "Application non installée:" $Product_Code
            EventLog 1 Information "Désinstallation:" $Product_Code "L'application n'est pas installée."
        }
    }
}


Function EXECUTE_UNINSTALL_EXE($RemoveExe, $Parameters, $Registry_Key, $File_Check, $Tempo, $regPart)
{
    # Verification présence V N-1, N-2 etc... ou non + désinstallation si besoin
    DETECT_INSTALLATION $Registry_Key $File_Check $regPart
    
    if ($Global:Err_Return -eq 0) 
    {
        if (($Global:FileDetect -eq $true -OR $Global:KeyDetect -eq $true) -OR ($Global:Key_ToCheck_isEmpty -eq $true -AND $Global:File_ToCheck_isEmpty -eq $true)) 
        {

            LOG_WRITE "Désinstallation:" $RemoveExe
            EventLog 1 Information "Désinstallation:" $RemoveExe "Désinstallation de l'application."

			Start-Process -FilePath `"$RemoveExe`" -ArgumentList "$Parameters" -Wait -Passthru
            Start-Sleep -s 60
            
            LOG_WRITE "Delais requis:" $Tempo " secondes"

            Start-Sleep -s $Tempo

            DETECT_INSTALLATION $Registry_Key $File_Check $regPart

            if (($Global:FileDetect -eq $false -AND $Global:KeyDetect -eq $false) -OR ($Global:Key_ToCheck_isEmpty -eq $true -AND $Global:File_ToCheck_isEmpty -eq $true)) 
            {
                LOG_WRITE "Désinstallation réussie:" $RemoveExe
                EventLog 1 Information "Désinstallation réussie:" $RemoveExe "Désinstallation de l'application réussie."
            }
            else 
            {
                $Global:Err_Return = 1
                LOG_WRITE "Echec de la désinstallation:" $RemoveExe
                EventLog 3 Error "Echec de la désinstallation:" $RemoveExe "Désinstallation de l'application échoué."
            }
        }
		else 
        {
            LOG_WRITE "Application non installée:" $RemoveExe
            EventLog 1 Information "Désinstallation:" $RemoveExe "L'application n'est pas installée."
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
        EventLog 2 Warning "Reboot:" "Requis" "L'ordinateur doit redémarrer pour finaliser la désinstallation du package."
    }  
    else 
    {   
        LOG_WRITE "Reboot requis:" "NON"
        EventLog 1 Information "Reboot:" "Non requis" "L'ordinateur n'a pas besoin de redémarrer pour finaliser la désinstallation du package."
    }
    [System.Environment]::Exit($RCode)
}


######################################## Déclaration des variables d'installation ########################################

$Installtype = ""               # USER for user installation or SYSTEM for a system installation
$Application_Name = ""          # Nom de l'application
$Application_Version = ""       # Version de l'application Vxx.xx.xx
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

$LogPath = "C:\temp\sccm_logs\R_" + $Application_Name + " " + $Application_Version + ".LOG"
$LogExist = (Test-Path $LogPath)


If ($LogExist -eq $true)
{
    Remove-Item $LogPath
}

EVALUATE_COMPUTER
KILL_PROCESS $Kill_Process

######################################## END Begin Bloc ##############################

######################################## UNINSTALL ########################################

        # Bloc de désinstallation/Migration
#EXECUTE_UNINSTALL "EXECUTABLE" "ARGUMENTS" "REGISTRY KEYS" "FILE CHECK" "TEMPO" "ARCHI"
#EXECUTE_UNINSTALL_EXE "C:\Program Files\Mozilla Firefox\uninstall\helper.exe" "/S" "" "C:\Program Files\Mozilla Firefox\firefox.exe=57.0.2" 0 32
#EXECUTE_UNINSTALL_MSI "{23170F69-40C1-2702-1801-000001000000}" "/qn /l* `"C:\temp\sccm_logs\Remove_7ZIP V18.01.log`"" "{23170F69-40C1-2702-1801-000001000000}" "" 0 64
#EXECUTE_UNINSTALL_APPX "B4D42709.CheckPointVPN"


If ($Global:Err_Return -eq 0)
{
    ### Execute other actions: Suppress file, shortcuts...
    CLS_REMOVEREGSIGN $Application_Name $Application_Version $Arch
}        

######################################## Fin UNINSTALL ########################################

######################################## Debut Finalisation ########################################
REBOOT_DEMAND $Reboot_Code
######################################## Fin Finalisation ########################################