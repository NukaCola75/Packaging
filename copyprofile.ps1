Function LOG_WRITE()
{
    # Ecriture dans le fichier log
    $machine = (Get-WmiObject Win32_ComputerSystem).name
    $Date = (Get-Date -format 'dd-MM-yy')
    $Time = (Get-Date -format 'HH:mm:ss')
    $LogPath = "\\srv-sccm\SCCM_LOGS\Firefox_certificat\" + $Date + "_DetectBitdefenderCertificateFirefox.LOG"                    #Creation du chemin + nom du log
    $Line_ToWrite = $Time + " - " + $machine + "   -   "  + $user + "   -    " + $firefoxProfile    #Concatenation du texte
    ADD-content -path $LogPath -value "$Line_ToWrite"                               #Ecriture
    ADD-content -path $LogPath -value "`n"                                          #Ecriture
}

$TestFirefox64 = Test-Path "C:\Program Files\Mozilla Firefox\firefox.exe"
$TestFirefox32 = Test-Path "C:\Program Files (x86)\Mozilla Firefox\firefox.exe"

If ($TestFirefox64 -eq $True -OR $TestFirefox32 -eq $True)      #Detection de firefox.exe
{
    #Si oui
    $users = (Get-ChildItem -Path "C:\Users" | Where-Object { $_.PSIsContainer } | foreach-object{$_.Name})  #Detection profiles utilisateurs
    foreach ($user in $users)   #Pour chaque user
    {    
        $profilesPath = "C:\Users\" + "$user" + "\AppData\Roaming\Mozilla\Firefox\Profiles"
        $TestAppDataPath = Test-Path $profilesPath
        If ($TestAppDataPath -eq $true)     #Si le chemin existe
        {
            $firefoxProfiles = (Get-ChildItem -Path $profilesPath | Where-Object { $_.PSIsContainer } | foreach-object{$_.Name})
            foreach ($firefoxProfile in $firefoxProfiles)   #Pour chaques profils firefox
            {
                $Cert8 = $profilesPath + "\" + $firefoxProfile + "\cert8.db"
                $Cert9 = $profilesPath + "\" + $firefoxProfile + "\cert9.db"

                $TestCert8 = Test-Path $Cert8
                $TestCert9 = Test-Path $Cert9

                If ($TestCert8 -eq $True)   #Si fichier cert8.db existe
                {
                    $detect = [boolean](Get-Content $Cert8 | Select-String -Pattern "Bitdefender")
                    If ($detect -eq $false)     #Detecte la chaine 'Bitdefender' dans le fichier
                    {
                        #Si chaine absente
                        LOG_WRITE
                        #Inscription LOG + heure - Nom machine - nom utilisateur - nom profile firefox
                    }
                }
                elseif ($TestCert9 -eq $True)   #Si fichier cert9.db existe
                {
                    $detect = [boolean](Get-Content $Cert9 | Select-String -Pattern "Bitdefender")
                    If ($detect -eq $false)     #Detecte la chaine 'Bitdefender' dans le fichier
                    {
                        #Si chaine absente
                        LOG_WRITE
                        #Inscription LOG + Date&heure - Nom machine - nom utilisateur - nom profile firefox
                    }
                }
            }
        }
    }
}