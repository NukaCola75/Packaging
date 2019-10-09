@echo off 
rem execute le script %1 contenu dans le m�me dossier que le .bat %~dp0

echo trace
echo %date% %time% - trace debut execution script : %1 dans %~dp0>> C:\Temp\sccm_logs\traces_scripts.log
powershell.exe -ExecutionPolicy Bypass -file %~dp0%1
echo %date% %time% - trace fin execution script : %1 dans %~dp0>> C:\Temp\sccm_logs\traces_scripts.log
echo -------------------------------------- >> C:\Temp\sccm_logs\traces_scripts.log
exit /b %errorlevel%


