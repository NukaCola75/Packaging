$Arch = 64
$Global:Err_Return = 0



Function EXECUTE_PATCH_MSI($InstallFile, $InstallParameters, $Registry_Key, $File_Check, $Tempo) 
{
    # Verification présence ou non + Installation si besoin
    DETECT_INSTALLATION $Registry_Key $File_Check

    if ($Global:Err_Return -eq 0) 
    {
        if ($Global:FileDetect -eq "False" -AND $Global:KeyDetect -eq "False") 
        {
            $Arguments = "/p `"$InstallFile`" $InstallParameters"

            LOG_WRITE "Installation du patch:" $InstallFile
            EventLog 1 Information "Installation:" $InstallFile "Installation du patch."
            
			
	        Start-Process -FilePath 'msiexec.exe' -ArgumentList "$Arguments" -Wait -Passthru            #Lancement de l'executable
            Start-Sleep -s 60                                                                           #Attente dernieres actions

            LOG_WRITE "Delais requis:" $Tempo " secondes"

            Start-Sleep -s $Tempo                                                                       #Attente supplementaire requis

            DETECT_INSTALLATION $Registry_Key $File_Check

            if ($Global:FileDetect -eq "True" -OR $Global:KeyDetect -eq "True") 
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
        if ($Global:FileDetect -eq "False" -AND $Global:KeyDetect -eq "False") 
        {
			Start-Process -FilePath `"$InstallFile`" -ArgumentList "$InstallParameters" -Wait -Passthru
			Start-Sleep -s 60
            Start-Sleep -s $Tempo

            DETECT_INSTALLATION $Registry_Key $File_Check

            if ($Global:FileDetect -eq "True" -OR $Global:KeyDetect -eq "True") 
            {
				Write-Host "Installation reussie"
            }
            else 
            {
                $Global:Err_Return = 1
				Write-Host "Application non detectee - Fail"
            }
        }
		else 
        {
            Write-Host "Application déjà présente"  
        }
    }	
}

#EXECUTE_INSTALLATION_MSI "GOOGLE CHROME V62.0.msi" "GOOGLE CHROME V62.0 CLS.Mst" "/qn /l* `"C:\temp\sccm_logs\Install_GOOGLE CHROME V62.0.log`"" "{E093BF8F-9D6D-342E-ADAC-7BD6F40C3BDE}" "" 0
#EXECUTE_INSTALLATION_EXE "Firefox V57.0.02.exe" " /S" "" "C:\Program Files\Mozilla Firefox\firefox.exe=57.0.2" 0
#Write-Host "Key to check" + $RegCheck
#Write-Host "Key present" + $KeyDetect
#Write-Host "File to check" + $FileCheck
#Write-Host "File present" + $FileDetect