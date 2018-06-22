$Poste = $env:COMPUTERNAME
# Récupération de l'adresse ip de la machine
$IpLocale = ((ipconfig | findstr [0-9].\.)[0]).Split()[-1]
# Récupération de l'architecture de l'OS, renvoie 4 pour du 32bits et 8 pour du 64bits
$ArchiOS = [IntPtr]::Size
# Accès à la base de registre de la machine
$Type = [Microsoft.Win32.RegistryHive]::LocalMachine
$RemoteRegistry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($Type, $Poste)
# Définition des clés de registre comportant les programmes
$Clef = "SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
$ClefBis = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
# Stockage du chemin de registre pour parcours ultérieur
$RegKey = $RemoteRegistry.OpenSubKey($Clef)
$RegKeyBis = $RemoteRegistry.OpenSubKey($ClefBis)
# Nom du logiciel
$Logiciel = "CCleaner"
# Variable de versions des différents logiciels
$Version = "5.02"
# Définition du chemin d'accès au fichier de log
$LogFile="\\serveur\chemin\du\fichier\log $poste .txt"
# Définition du chemin des fichiers exécutables
$FichierInstallation = "\\serveur\chemin\de\lexecutable\ccsetup502.exe"
$FichierDesinstallation = ""
# Définition des paramètres d'installation silencieuse pour CCleaner
$ParametreInstallation = "/S EULA_ACCEPT=YES /L=1036"
 
# ========================================================================
# Préparation du fichier de logs
# ========================================================================
 
# Ajout d'une ligne de séparation pour chaque pc dans le fichier de log
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
# Fonction qui vérifie la présence du logiciel et renvoie 0 s'il n'est pas
# présent, 1 s'il est présent dans la mauvaise version, et 2 s'il est
# présent dans la bonne version.
# ========================================================================
 
function presence_registre {
    # Définition des paramètres nécessaires à la fonction
    param([String]$logiciel,[String]$version)
    # On initialise la variable de retour à 0
    $etat = 0
    #Parcours des programmes via les clefs de registre
    if (Test-Path "HKLM:\\$Clef")
    {
        foreach($Key in $RegKey.GetSubKeyNames())
            {
             # Récupération du nom du programmes, de sa version, et de son exécutable de désinstallation
             $SubKey = $RegKey.OpenSubKey($key)
             $MonObjet = "" | Select DisplayName,Version,UninstallString
             $MonObjet.DisplayName = $SubKey.GetValue("DisplayName")
             $MonObjet.Version = $SubKey.GetValue("DisplayVersion")
             $MonObjet.UninstallString = $Subkey.GetValue("UninstallString")
                 
             # Vérification de la présence des programmes, et de la présence de la bonne version
             if($MonObjet.DisplayName -match $logiciel) { #Si le logiciel est installé, 1
                    $etat = 1
                    # Récupération du chemin de l'exécutable de désinstallation
                    $global:FichierDesinstallation = $MonObjet.UninstallString
              if($MonObjet.Version -eq $version) { #Si la version est bonne, 2
               $etat = 2
              } #if
                    #Si le programme a été trouvé, on sort de la fonction et on renvoie son résultat
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
         # Récupération du nom du programmes, de sa version, et de son exécutable de désinstallation
         $SubKey = $RegKeyBis.OpenSubKey($key)
         $MonObjet = "" | Select DisplayName,Version,UninstallString
         $MonObjet.DisplayName = $SubKey.GetValue("DisplayName")
         $MonObjet.Version = $SubKey.GetValue("DisplayVersion")
         $MonObjet.UninstallString = $Subkey.GetValue("UninstallString")
             
         # Vérification de la présence des programmes, et de la présence de la bonne version
         if($MonObjet.DisplayName -match $logiciel) { #Si le logiciel est installé, 1
                $etat = 1
                # Récupération du chemin de l'exécutable de désinstallation
                $global:FichierDesinstallation = $MonObjet.UninstallString
          if($MonObjet.Version -eq $version) { #Si la version est bonne, 2
           $etat = 2
          } #if
                #Si le programme a été trouvé, on sort de la fonction et on renvoie son résultat
                if ($etat -ne 0) {
                    return $etat
                }#if
         } #if
             
        }#foreach
    }#if       
    return $etat
         
} #presence
 
 
 
 
$action = presence_registre -logiciel $Logiciel -version $Version
 
# Si le programme n'est pas présent sur la machine, $action = 0, on installe le logiciel avec écriture dans le fichier de logs
if ($action -eq 0) {
    Add-Content -Path $LogFile -Value "$(Get-Date) : CCleaner absent, début de l'installation"
    # Installation de l'application à jour avec les paramètres définis au début du script
    Start-Process $FichierInstallation $ParametreInstallation
    Start-Sleep -Seconds 60
    # Vérification de l'installation de CCleaner
    $ActionRealisee = presence_registre -logiciel $Logiciel -version $version
    # Ecriture dans le fichier de log de l'échec ou du succès de l'installation
    if ($ActionRealisee -eq 2) {
        Add-Content -Path $LogFile -Value "$(Get-Date) : Installation de la version à jour de CCleaner réussie"
    } else {
        Add-Content -Path $LogFile -Value "$(Get-Date) : Echec de l'installation de CCleaner"
    }
}
 
# Si le programme est présent dans la mauvaise version, $action = 0,
# on désinstalle la version obsolète et on installe la bonne avec écriture dans le fichier de logs
if ($action -eq 1) {
    Add-Content -Path $LogFile -Value "$(Get-Date) : Version obsolète de CCLeaner, désinstallation"
    # Désinstallation silencieuse (/S)
    Start-Process $FichierDesinstallation "/S"
    Start-Sleep -Seconds 40
    #Test de la désinstallation
    $DesinstallationOK = presence_registre -logiciel $Logiciel -Version $Version
    # Ecriture dans le fichier de log de l'échec ou du succès de la désinstallation
    if($DesinstallationOK -eq 0)
    {
        Add-Content -Path $LogFile -Value "$(Get-Date) : Désinstallation de la version obsolète de CCleaner réussie"
    } else {
        Add-Content -Path $LogFile -Value "$(Get-Date) : Echec de la désinstallation de la version obsolète de CCleaner"
    }
     
    Add-Content -Path $LogFile -Value "$(Get-Date) : Début de l'installation de la version à jour de CCleaner"
    # Installation de l'application à jour avec les paramètres définis au début du script
    Start-Process $FichierInstallation $ParametreInstallation
    Start-Sleep -Seconds 60
    # Vérification de l'installation de CCleaner
    $actionRealisee = presence_registre -logiciel $Logiciel -Version $Version
    # Ecriture dans le fichier de log de l'échec ou du succès de l'installation
    if ($actionRealisee -eq 2) {
        Add-Content -Path $LogFile -Value "$(Get-Date) : Installation de la version à jour de CCleaner réussie"
    } else {
        Add-Content -Path $LogFile -Value "$(Get-Date) : Echec de l'installation de la version à jour de CCleaner"
    }
}
 
# Si le programme est présent sur la machine, $action = 2, on écrit dans le fichier de log
if ($action -eq 2) {
    Add-Content -Path $LogFile -Value "$(Get-Date) : La version installée de CCleaner est à jour"
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