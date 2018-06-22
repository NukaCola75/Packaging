
$Global:Err_Return = 0

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


Function EXECUTE_MIGRATION_MSI($Product_Code, $Parameters, $Registry_Key, $File_Check, $Tempo)
{
        # Verification présence V N-1, N-2 etc... ou non + désinstallation si besoin
        Write-Host $Registry_Key
    DETECT_INSTALLATION $Registry_Key $File_Check
    
    if ($Global:Err_Return -eq 0) 
    {
        if ($Global:FileDetect -eq "True" -OR $Global:KeyDetect -eq "True") 
        {
			$Arguments = "/X $Product_Code $Parameters"
			
			Start-Process -FilePath 'msiexec.exe' -ArgumentList "$Arguments" -Wait -Passthru
			Start-Sleep -s 60
            Start-Sleep -s $Tempo

            DETECT_INSTALLATION $Registry_Key $File_Check

            if ($Global:FileDetect -eq "False" -AND $Global:KeyDetect -eq "False") 
            {
				Write-Host "Desinstallation reussie"
            }
            else 
            {
                $Global:Err_Return = 1
				Write-Host "Echec de la desinstallation"
            }
        }
		else 
        {
            Write-Host "Application non presente"
        }
    }
}


Function EXECUTE_MIGRATION_EXE($RemoveExe, $Parameters, $Registry_Key, $File_Check, $Tempo)
{
    # Verification présence V N-1, N-2 etc... ou non + désinstallation si besoin

    

    DETECT_INSTALLATION $Registry_Key $File_Check
    
    if ($Global:Err_Return -eq 0) 
    {
        if ($Global:FileDetect -eq "True" -OR $Global:KeyDetect -eq "True") 
        {
			Start-Process -FilePath `"$RemoveExe`" -ArgumentList "$Parameters" -Wait -Passthru
			Start-Sleep -s 60
            Start-Sleep -s $Tempo

            DETECT_INSTALLATION $Registry_Key $File_Check

            if ($Global:FileDetect -eq "False" -AND $Global:KeyDetect -eq "False") 
            {
				Write-Host "Desinstallation reussie"
            }
            else 
            {
                $Global:Err_Return = 1
				Write-Host "Echec de la desinstallation"
            }
        }
		else 
        {
            Write-Host "Application non presente"  
        }
    }	
}

#EXECUTE_MIGRATION_EXE "C:\Program Files\Mozilla Firefox\uninstall\helper.exe" "/S" "" "C:\Program Files\Mozilla Firefox\firefox.exe=57.0.2" 0
#EXECUTE_MIGRATION_MSI "{E093BF8F-9D6D-342E-ADAC-7BD6F40C3BDE}" "/qn /l* `"C:\temp\sccm_logs\Remove_GOOGLE CHROME V62.0.log`"" "{E093BF8F-9D6D-342E-ADAC-7BD6F40C3BDE}" "" 0
