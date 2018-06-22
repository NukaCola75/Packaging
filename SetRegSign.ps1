
$InstallDate = Get-Date

Function CLS_SETREGSIGN($App_Name, $App_Version, $App_Editor, $Install_Dir, $Techno, $Archi)
{
        # Signature du package par clé de registre

        $Reg_Name = $App_Name + " " + $App_Version
        If ($Archi -eq 32) 
        {
                $path = "HKLM:\Software\WOW6432Node"
        }
        Else
        {
                $path = "HKLM:\Software"
        }

        Try 
        {
                new-item -path $path\CLS -ErrorAction 'SilentlyContinue'
                new-item -path $path\CLS\INVENTORY -ErrorAction 'SilentlyContinue'
                new-item -path $path\CLS\INVENTORY\Packages -ErrorAction 'SilentlyContinue'
                new-item -path $path\CLS\INVENTORY\Packages\$Reg_Name -ErrorAction 'SilentlyContinue'
        
                new-itemproperty -path $path\CLS\INVENTORY\Packages\$Reg_Name -name "InstallDate" -value $InstallDate -ErrorAction 'SilentlyContinue'
                new-itemproperty -path $path\CLS\INVENTORY\Packages\$Reg_Name -name "InstallLocation" -value $Install_Dir -ErrorAction 'SilentlyContinue'
                new-itemproperty -path $path\CLS\INVENTORY\Packages\$Reg_Name -name "Name" -value $App_Name -ErrorAction 'SilentlyContinue'
                new-itemproperty -path $path\CLS\INVENTORY\Packages\$Reg_Name -name "Publisher" -value $App_Editor -ErrorAction 'SilentlyContinue'
                new-itemproperty -path $path\CLS\INVENTORY\Packages\$Reg_Name -name "Version" -value $App_Version -ErrorAction 'SilentlyContinue'
        }
        Catch
        {

        }
}


CLS_SETREGSIGN "TEST" "V01.00.00" "SHebbir" "C:\temp" "SCRIPT" 32