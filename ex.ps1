$Poste = $env:COMPUTERNAME
# R�cup�ration de l'adresse ip de la machine
$IpLocale = ((ipconfig | findstr [0-9].\.)[0]).Split()[-1]
# R�cup�ration de l'architecture de l'OS, renvoie 4 pour du 32bits et 8 pour du 64bits
$ArchiOS = [IntPtr]::Size
# Acc�s � la base de registre de la machine
$Type = [Microsoft.Win32.RegistryHive]::LocalMachine
$RemoteRegistry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($Type, $Poste)
# D�finition des cl�s de registre comportant les programmes
$Clef = "SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
$ClefBis = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
# Stockage du chemin de registre pour parcours ult�rieur
$RegKey = $RemoteRegistry.OpenSubKey($Clef)
$RegKeyBis = $RemoteRegistry.OpenSubKey($ClefBis)
# Nom du logiciel
$Logiciel = "CCleaner"
# Variable de versions des diff�rents logiciels
$Version = "5.02"
# D�finition du chemin d'acc�s au fichier de log
$LogFile="\\serveur\chemin\du\fichier\log $poste .txt"
# D�finition du chemin des fichiers ex�cutables
$FichierInstallation = "\\serveur\chemin\de\lexecutable\ccsetup502.exe"
$FichierDesinstallation = ""
# D�finition des param�tres d'installation silencieuse pour CCleaner
$ParametreInstallation = "/S EULA_ACCEPT=YES /L=1036"
 
# ========================================================================
# Pr�paration du fichier de logs
# ========================================================================
 
# Ajout d'une ligne de s�paration pour chaque pc dans le fichier de log
ADD-content -path $LogFile -value "====================================================="
Add-Content -Path $LogFile -Value "$(Get-Date) : DEBUT D'EXECUTION DU SCRIPT"
# Ajout du nom de l'ordinateur et de son ip
ADD-content -path $LogFile -value "$(Get-Date) : Nom de la machine : $Poste"
# Ajout de l'architecture de l'OS
if ($ArchiOS -eq "4") { ADD-content -path $LogFile -value "$(Get-Date) : Architecture : 32 bits" }
if ($ArchiOS -eq "8") { ADD-content -path $LogFile -value "$(Get-Date) : Architecture : 64 bits" }
# Ajout de l'adresse ip
Add-Content -Path $LogFile -Value "$(Get-DAte) : Adresse IP : $IpLocale"
 
# ========================================================================
# Fonction qui v�rifie la pr�sence du logiciel et renvoie 0 s'il n'est pas
# pr�sent, 1 s'il est pr�sent dans la mauvaise version, et 2 s'il est
# pr�sent dans la bonne version.
# ========================================================================
 
function presence_registre {
    # D�finition des param�tres n�cessaires � la fonction
    param([String]$logiciel,[String]$version)
    # On initialise la variable de retour � 0
    $etat = 0
    #Parcours des programmes via les clefs de registre
    if (Test-Path "HKLM:\\$Clef")
    {
        foreach($Key in $RegKey.GetSubKeyNames())
            {
             # R�cup�ration du nom du programmes, de sa version, et de son ex�cutable de d�sinstallation
             $SubKey = $RegKey.OpenSubKey($key)
             $MonObjet = "" | Select DisplayName,Version,UninstallString
             $MonObjet.DisplayName = $SubKey.GetValue("DisplayName")
             $MonObjet.Version = $SubKey.GetValue("DisplayVersion")
             $MonObjet.UninstallString = $Subkey.GetValue("UninstallString")
                 
             # V�rification de la pr�sence des programmes, et de la pr�sence de la bonne version
             if($MonObjet.DisplayName -match $logiciel) { #Si le logiciel est install�, 1
                    $etat = 1
                    # R�cup�ration du chemin de l'ex�cutable de d�sinstallation
                    $global:FichierDesinstallation = $MonObjet.UninstallString
              if($MonObjet.Version -eq $version) { #Si la version est bonne, 2
               $etat = 2
              } #if
                    #Si le programme a �t� trouv�, on sort de la fonction et on renvoie son r�sultat
                    if ($etat -ne 0) {
                        return $etat
                    }#if
             } #if
            }#foreach
    }#if         
     
    if (Test-Path "HKLM:\\$ClefBis")
    {   
        foreach($Key in $RegKeyBis.GetSubKeyNames())
        {
         # R�cup�ration du nom du programmes, de sa version, et de son ex�cutable de d�sinstallation
         $SubKey = $RegKeyBis.OpenSubKey($key)
         $MonObjet = "" | Select DisplayName,Version,UninstallString
         $MonObjet.DisplayName = $SubKey.GetValue("DisplayName")
         $MonObjet.Version = $SubKey.GetValue("DisplayVersion")
         $MonObjet.UninstallString = $Subkey.GetValue("UninstallString")
             
         # V�rification de la pr�sence des programmes, et de la pr�sence de la bonne version
         if($MonObjet.DisplayName -match $logiciel) { #Si le logiciel est install�, 1
                $etat = 1
                # R�cup�ration du chemin de l'ex�cutable de d�sinstallation
                $global:FichierDesinstallation = $MonObjet.UninstallString
          if($MonObjet.Version -eq $version) { #Si la version est bonne, 2
           $etat = 2
          } #if
                #Si le programme a �t� trouv�, on sort de la fonction et on renvoie son r�sultat
                if ($etat -ne 0) {
                    return $etat
                }#if
         } #if
             
        }#foreach
    }#if       
    return $etat
         
} #presence
 
 
 
 
$action = presence_registre -logiciel $Logiciel -version $Version
 
# Si le programme n'est pas pr�sent sur la machine, $action = 0, on installe le logiciel avec �criture dans le fichier de logs
if ($action -eq 0) {
    Add-Content -Path $LogFile -Value "$(Get-Date) : CCleaner absent, d�but de l'installation"
    # Installation de l'application � jour avec les param�tres d�finis au d�but du script
    Start-Process $FichierInstallation $ParametreInstallation
    Start-Sleep -Seconds 60
    # V�rification de l'installation de CCleaner
    $ActionRealisee = presence_registre -logiciel $Logiciel -version $version
    # Ecriture dans le fichier de log de l'�chec ou du succ�s de l'installation
    if ($ActionRealisee -eq 2) {
        Add-Content -Path $LogFile -Value "$(Get-Date) : Installation de la version � jour de CCleaner r�ussie"
    } else {
        Add-Content -Path $LogFile -Value "$(Get-Date) : Echec de l'installation de CCleaner"
    }
}
 
# Si le programme est pr�sent dans la mauvaise version, $action = 0,
# on d�sinstalle la version obsol�te et on installe la bonne avec �criture dans le fichier de logs
if ($action -eq 1) {
    Add-Content -Path $LogFile -Value "$(Get-Date) : Version obsol�te de CCLeaner, d�sinstallation"
    # D�sinstallation silencieuse (/S)
    Start-Process $FichierDesinstallation "/S"
    Start-Sleep -Seconds 40
    #Test de la d�sinstallation
    $DesinstallationOK = presence_registre -logiciel $Logiciel -Version $Version
    # Ecriture dans le fichier de log de l'�chec ou du succ�s de la d�sinstallation
    if($DesinstallationOK -eq 0)
    {
        Add-Content -Path $LogFile -Value "$(Get-Date) : D�sinstallation de la version obsol�te de CCleaner r�ussie"
    } else {
        Add-Content -Path $LogFile -Value "$(Get-Date) : Echec de la d�sinstallation de la version obsol�te de CCleaner"
    }
     
    Add-Content -Path $LogFile -Value "$(Get-Date) : D�but de l'installation de la version � jour de CCleaner"
    # Installation de l'application � jour avec les param�tres d�finis au d�but du script
    Start-Process $FichierInstallation $ParametreInstallation
    Start-Sleep -Seconds 60
    # V�rification de l'installation de CCleaner
    $actionRealisee = presence_registre -logiciel $Logiciel -Version $Version
    # Ecriture dans le fichier de log de l'�chec ou du succ�s de l'installation
    if ($actionRealisee -eq 2) {
        Add-Content -Path $LogFile -Value "$(Get-Date) : Installation de la version � jour de CCleaner r�ussie"
    } else {
        Add-Content -Path $LogFile -Value "$(Get-Date) : Echec de l'installation de la version � jour de CCleaner"
    }
}
 
# Si le programme est pr�sent sur la machine, $action = 2, on �crit dans le fichier de log
if ($action -eq 2) {
    Add-Content -Path $LogFile -Value "$(Get-Date) : La version install�e de CCleaner est � jour"
}
 
Add-Content -Path $LogFile -Value "$(Get-Date) : FIN D'EXECUTION DU SCRIPT"












function Run-MsiExec($installShare, $msiPackage, $Transform, $options){
    $Arguments = "/i `"$env:temp\$msiPackage`" ALLUSERS=2 TRANSFORMS=`"$env:temp\$Transform`" /qn $options"
   
    Copy-Item "$installShare\$msiPackage" "$env:temp\$msiPackage"

    if($Transform){
           Copy-Item "$installShare\$Transform" "$env:temp\$Transform"
    }else{
           $Arguments = "/i `"$env:temp\$msiPackage`" ALLUSERS=2 /qn $options"
    }
    Write-Host "Installing $msiPackage"
 Write-Host "Start-Process -FilePath 'msiexec.exe' -ArgumentList "$Arguments" -Wait -Passthru"
    return (Start-Process -FilePath "msiexec.exe" -ArgumentList "$Arguments" -Wait -Passthru).ExitCode

} 