$userprofiles = (Get-ChildItem -Path "C:\Users" -Attributes directory,directory+hidden | Where-Object { $_.PSIsContainer } | foreach-object{$_.Name})  #Detection profiles utilisateurs
    foreach ($userprofile in $userprofiles)   #Pour chaque user
    {    
        Write-Host "Profils utilisateur: " $userprofile
        If ($userprofile -ne "Public")
        {
            $profilePath = "C:\Users\" + "$userprofile"
            $TestRoamingPath = Test-Path $profilePath"\AppData\Roaming"
            If ($TestRoamingPath -eq $true)     #Si le chemin existe
            {
                Write-Host "Dossier roaming existe"
                $TestVLCPath = Test-Path $profilePath"\AppData\Roaming\vlc"
                If ($TestVLCPath -eq $false)
                {
                    New-Item -name 'vlc' -path $profilePath"\AppData\Roaming\" -type 'directory' -ErrorAction 'SilentlyContinue'
                }
                Write-Host "Copie du fichier: " $PathExecute"\vlcrc" " vers: " $profilePath"\AppData\Roaming\vlc"
                Copy-Item $PathExecute"\vlcrc" -destination $profilePath"\AppData\Roaming\vlc" -Force
            }
        }
    }