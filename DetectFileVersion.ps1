$Filename_AndPath = "C:\Program Files\Microsoft VS Code\Code.exe"

$InstalledFileVersion = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($Filename_AndPath).FileVersion)       #Récupération version du fichier sur pc

Write-Host "Version du fichier: " $InstalledFileVersion
Pause