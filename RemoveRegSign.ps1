Function CLS_REMOVEREGSIGN($App_Name, $App_Version, $Archi)
{
        # Suppression des anciennes signatures
        $Reg_Name = $App_Name + " " + $App_Version
        If ($Archi -eq 32) 
        {
                $path = "HKLM:\Software\WOW6432Node"
        }
        Else
        {
                $path = "HKLM:\Software"
        }

        Remove-Item $path\CLS\INVENTORY\Packages\$Reg_Name -force -ErrorAction 'SilentlyContinue'
}

CLS_REMOVEREGSIGN "TEST" "V01.00.00" 32