$Filename_AndPath = "C:\Program Files\VideoLAN\VLC\vlc.exe"

$InstalledFileVersion = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($Filename_AndPath).FileVersion)       #R�cup�ration version du fichier sur pc

Write-Host "Version du fichier: " $InstalledFileVersion
Pause