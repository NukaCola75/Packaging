Function DETECT_INSTALLATION($Key_ToCheck, $File_ToCheck) 
{
        # Verification présence ou non + Installation si besoin

    If ($Arch -eq 32)                           #Definition path registre 32/64
    {
        $CurrentV = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\"
    }
    Else
    {
        $CurrentV = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\"
    }

    $regkey = $CurrentV + $Key_ToCheck         #Concatenation clé registre + path

    If ([string]::IsNullOrEmpty($Key_ToCheck)) #Verification si la cle registre est renseignee
    {            
        Write-Host "No registry key to check"
        $Global:RegCheck = "False"
		$Global:KeyDetect = "False"
    } 
    Else
    {            
        $Global:RegCheck = "True"
        Write-Host $regkey
        $KeyExist = Test-Path $regkey           #Verification existance cle
        Write-Host "Key Exist: " $KeyExist

        If ($KeyExist -eq "true") 
        {
            Write-Host "Registry key is detected"
            $Global:KeyDetect = "True"
        }
        Else 
        {
            Write-Host "Registry key is not detected"
            $Global:KeyDetect = "False"
        }
    }

    If ([string]::IsNullOrEmpty($File_ToCheck))   #Verification si fichier a verifier est fournit
    {            
        $Global:FileCheck = "False"
        Write-Host "No file to check"
    } 
    Else
    {            
        $Global:FileCheck = "True"
        $PosLastAntiSlash = $File_ToCheck.LastIndexOf("\")        #Detecte derniere occurence "\" dans le path
        $file = $File_ToCheck.Substring($PosLastAntiSlash+1)      #Coupe a partir de la dernière "\" pour obtenir le nom fichier
        $filepath = $File_ToCheck.Substring(0, $PosLastAntiSlash) #Obtient le path sans non de fichier
        Write-Host $filepath
        Write-Host $file

        If (($file).Contains("=") -eq "true")                   #Verifie si présence "=2.255.22" check versioning
        {
            $Fsplit = $file.Split("=")                          #Coupe a partir du "=" et supprime le "="
            $FileName = $Fsplit[0]                              #Avant "=" : nom fichier + extension
            $FileVersion = $Fsplit[1]                           #Après "=" : version fichier
            Write-Host $FileVersion
        }
        Else 
        {
            $FileName = $file                                   #Si versioning non présent: nom fichier sans découpe
        }

        If ([string]::IsNullOrEmpty($FileVersion))              #Verifie si versionning present
        {
            Write-Host "No file's version to check"
            $TestFile = Test-Path $File_ToCheck
            If ($TestFile -eq $True)              #Verifie existence du fichier sur le pc
            {
                #Write-Host "Check file: Installation success"   #Si oui, success
                $Global:FileDetect = "True"
            }
            Else
            {
                Write-Host "Check file: Installation fail"      #Si non, erreur
                $Global:FileDetect = "False"
            }
        }
        Else                                                    #Si versionning non present
        {
            $Filename_AndPath = $filepath + "\" + $filename               #Concatenation path + nom fichier
            Write-Host $File_ToCheck
            If ((Test-Path $Filename_AndPath) -eq $True)            #Si fichier existant sur le pc
            {
                $InstalledFileVersion = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($Filename_AndPath).FileVersion)       #Récupération version du fichier sur pc
                Write-Host $InstalledFileVersion
                If ($InstalledFileVersion -eq $FileVersion)     #Comparaison version theorique et version effective
                {
                    Write-Host "Installation success"           #Si success
                    $Global:FileDetect = "True"
                }
                Else 
                {
                    Write-Host "Check file version: Installation fail"      #Si fail
                    $Global:FileDetect = "False"
                }
            }
            Else 
            {
                Write-Host "File not present"     #Si fichier non detecte
                $Global:FileDetect = "False"
            }
        }
    }
}

DETECT_INSTALLATION "{DC2F8A88-4D91-4896-8C39-2A3BF0A4BAC6}" "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe=62.0.3202.94"