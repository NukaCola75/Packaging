Param(
    [string] $Name,
    [string] $user
)

Function DETECT_APPX($Name, $user)
{
    $Global:scanAppx = (Get-AppxPackage -Name $Name -User $user)
    $Global:AppxName = ($Global:scanAppx).Name
    $Global:AppxVersion = ($Global:scanAppx).Version
    $Global:AppxLocation = ($Global:scanAppx).InstallLocation
    $Global:AppxFullName = ($Global:scanAppx).PackageFullName
    $Global:Deps = @(($Global:scanAppx).Dependencies)
}

If (([String]::IsNullOrEmpty($Name)) -OR ([String]::IsNullOrEmpty($user)))
{
    Write-Host "Un ou plusieurs param�tres requis a ce script est manquant."
}
else 
{
    DETECT_APPX $Name $user

    If ([String]::IsNullOrEmpty($Global:scanAppx))
    {
        Write-Host "L'application " + $Name + " est introuvale pour le profil " + $user + "."
    }
    else 
    {
        Clear-Host
        Write-Host "`n"
        Write-Host "---------- Informations de l'APPX ----------"
        Write-Host "Nom:        " $Global:AppxName
        Write-Host "Version:    " $Global:AppxVersion
        Write-Host "Dossier:    " $Global:AppxLocation
        Write-Host "Nom PKG:    " $Global:AppxFullName
        Write-Host "D�pendances:"
        foreach ($Dep in $Global:Deps)
        {
            Write-Host "-> $Dep"
        }
        Write-Host "--------------------------------------------"
        Write-Host "`n"
    } 
}