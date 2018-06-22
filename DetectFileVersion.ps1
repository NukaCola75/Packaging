$Filename_AndPath = "C:\Program Files (x86)\JetBrains\PyCharm Community Edition 2018.1.2\bin\pycharm.exe"

$InstalledFileVersion = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($Filename_AndPath).FileVersion)       #Récupération version du fichier sur pc

Write-Host "Version du fichier: " $InstalledFileVersion
Pause