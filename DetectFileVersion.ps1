$Filename_AndPath = "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"

$InstalledFileVersion = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($Filename_AndPath).FileVersion)       #Récupération version du fichier sur pc

Write-Host "Version du fichier: " $InstalledFileVersion
Pause