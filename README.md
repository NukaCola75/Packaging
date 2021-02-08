# Fonctionnalités

- Gestion de la migration d'une application.
- Gestion de la désinstallation d'une application.
- Gestion de l'installation d'une application.
- Détection d'une application.
- Plusieurs types d'executables possibles: MSI, MSP, MSU, EXE, APPX, APPXBUNDLE, CAB.
- Fermeture des processus Windows requis.
- Journalisation des actions réalisées.
- Signature de l'application dans le registre Windows pour inventaire.
- Customisation de l'installation.
- Gestion des redémarrages machine via SCCM.

<br>

# Quelques éléments à respecter
- **Toujours prévoir la désinstallation de l'application.**
- Garder à l'esprit que le script sera exécuté depuis le cache SCCM: impossible donc de connaitre à l'avance son chemin d'execution !
- Prévoir la sauvegarde des données de l'application en cas de migration.
- Toujours prévoir au moins une méthode de détection pour confirmer la présence de l'application.
- **Toujours effectuer des tests !**

# Install.ps1
Utilisation du script "Install.ps1".
Ce script permet d'installer une application tout en gérant la migration des versions précédentes.
Un seul executable par script de préférence.

## Informations de l'application
Renseigner les informations de l'application (l668):

```powershell
$Installtype = ""               # USER for user installation or SYSTEM for a system installation
$Application_Name = ""          # Application name
$Application_Version = ""       # Application version
$Editor = ""                    # Editor
$Install_Path = ""              # Install folder of the application
$Technologie = ""               # MSI, EXE, APPX, CAB, MSU or SCRIPT
$Arch =                         # 32 or 64
$Kill_Process = @()             # Process to kil. If neccessary. Ex: $Kill_Process = @("chrome","iexplore","firefox")
$Reboot_Code = 0                # 3010 for reboot - 0 by default
```

## Migration des versions précédentes
La partie "Migration" permet de gérer la migration des anciennes versions de l'application ainsi que la désinstallation des applications qu'elle remplace.
Elle est systèmatiquement appelée lors de l'execution du script.
Elle peut être laissée vide si aucune action de migration n'est nécessaire.

```powershell
######################################## BEGIN Migration ########################################

# Bloc for Uninstall/Migration
#EXECUTE_MIGRATION_EXE "C:\Program Files\Mozilla Firefox\uninstall\helper.exe" "/S" "REG KEY" "C:\Program Files\Mozilla Firefox\firefox.exe=57.0.2" 0 32
#EXECUTE_MIGRATION_MSI "PRODUCT CODE or MSI FILE" "/qn /l* `"C:\temp\sccm_logs\Remove_7ZIP V18.01.log`"" "PRODUCT CODE" "REG KEY" "FILE" 0 64


If ($Global:Err_Return -eq 0)
{
	### Execute other actions: Suppress file, shortcuts...
	#INVENTORY_REMOVEREGSIGN "APP NAME" "APP VERSION" $Arch
}

######################################## END Migration ########################################
```

### Exemple pour la migration d'un fichier MSI:
`EXECUTE_MIGRATION_MSI "{7F544E85-3FC4-3F6B-BE1C-679880E73AD3}" "/qn /l* ``"C:\temp\sccm_logs\Remove_GOOGLE CHROME V75.0.log``"" "{7F544E85-3FC4-3F6B-BE1C-679880E73AD3}" "" "" 0 64`

**La fonction "EXECUTE_MIGRATION_MSI" attend plusieurs paramètres:**
1. Le code produit du MSI à désinstaller. *(Obligatoire)*
2. Les paramètres à passer lors de l'execution du MSI. *(Optionnel)*
3. Le code produit MSI à detecter pour confirmer ou non la présence de l'application. Généralement identique au premier paramètre, peux différerer dans certains cas. *(Optionnel)*
4. Une clé de registre à détecter coté CurrentV/Uninstall. Le chemin de la clé est automatiquement résolu en fonction de l'architecture renseignée en 7éme paramètre. *(Optionnel)*
5. Chemin vers un fichier permettant de confirmer ou non la présence de l'application. *(Optionnel)*
6. Délais (en secondes) de temporisation requis après la fin de l'execution en cours. *(Optionnel)*
7. Architecture cible de l'application. 32 (pour 32bits) ou 64 (pour 64bits). *(Obligatoire)*

### Exemple pour la migration d'un fichier EXE:
`EXECUTE_MIGRATION_EXE "C:\Program Files\FileZilla FTP Client\uninstall.exe" "/S" "" "C:\Program Files\FileZilla FTP Client\filezilla.exe" 0 64`

**La fonction "EXECUTE_MIGRATION_EXE" attend plusieurs paramètres:**

1. Chemin vers l'executable ou nom de l'executable (si située dans le même repertoire que le script). *(Obligatoire)*
2. Paramètres à passer a l'executable. *(Optionnel)*
3. Clé de registre à rechercher pour confirmer ou non la présence de l'application. *(Optionnel)*
4. Chemin vers un fichier pour confirmer ou non la présence de l'application. *(Optionnel)*
5. Temporisation requise après l'installation en cours. *(Optionnel)*
6. Architecture de l'installation. 32 ou 64. *(Obligatoire)*

### Execution des autres actions:
Afin de réaliser des actions de customisation et/ou de paramètrage de l'application, une portion de code est présente dans chaque bloc d'actions.
Attention, ce bloc de code n'est exécuté que si la migration à réussie !

```powershell
If ($Global:Err_Return -eq 0)
{
	### Execute other actions: Suppress file, shortcuts...
	Remove-Item "C:\Users\public\Desktop\Google Chrome.lnk" -force -ErrorAction 'SilentlyContinue'
	INVENTORY_REMOVEREGSIGN "GOOGLE CHROME" "V75.0" $Arch
}
```

### Suppression de la signature d'une application
**Dans tous les cas, décommenter et/ou ajouter autant d'appel à la fonction "INVENTORY_REMOVEREGSIGN" que nécessaire !**

Exemple:
`INVENTORY_REMOVEREGSIGN "GOOGLE CHROME" "V64.0" 64`

**Trois paramètres obligatoires:**
1. Le nom de l'application migrée.
2. La version de l'application migrée.
3. L'architecture de l'application migrée.


## Installation d'une application
La partie "Installation" (l730) du script est automatiquement exécutée par le script.
Elle permet d'installer un ou plusieurs exécutable(s) de plusieurs types différents.
Il est cependant **recommandé** d'appliquer la régle suivante:
**Une application = Un package = Un script d'installation**

### Exemple pour un fichier MSI:
`EXECUTE_INSTALLATION_MSI "GoogleChromeStandaloneEnterprise64.msi" "" "/qn /l* ``"C:\temp\sccm_logs\Install_GOOGLE CHROME V76.0.log``"" "{86B1D736-F1F4-3367-9B39-C2E176B68239}" "" "" 0 64`

**La fonction "EXECUTE_INSTALLATION_MSI" accepte huit paramètres:**
1. Nom complet du fichier MSI. *(Obligatoire)*
2. Fichier transform (.MST) si besoin. *(Optionnel)*
3. Paramètres à passer lors de l'execution du fichier MSI. *(Optionnel)*
4. Code produit à rechercher pour confirmer ou non la présence de l'application. *(Optionnel)*
5. Clé de registre à rechercher pour confirmer ou non la présence de l'application. *(Optionnel)*
6. Chemin vers un fichier afin de confirmer ou non la présence de l'application. *(Optionnel)*
7. Temporisation requise après l'installation de l'application. *(Optionnel)*
8. Architecture de l'application.* (Obligatoire)*

### Exemple pour un fichier EXE:
`EXECUTE_INSTALLATION_EXE "FileZilla_3.44.1_win64_sponsored-setup.exe" "/S /user=all" "" "C:\Program Files\FileZilla FTP Client\filezilla.exe=3, 44, 1, 0" 0 64`

**La fonction "EXECUTE_INSTALLATION_EXE" accepte six paramètres:**
1. Le nom du fichier exécutable.* (Obligatoire)*
2. Paramètres à passer au fichier exécutable.* (Optionnel)*
3. Clé de registre à rechercher pour confirmer la présence de l'application. *(Optionnel)*
4. Chemin vers un fichier afin de confirmer la présence de l'application. *(Optionnel)*
5. Temporisation requise après le fin de l'installation en cours. *(Optionnel)*
6. Architecture de l'application. *(Obligatoire)*

### Exemple pour un fichier MSP:
`EXECUTE_PATCH_MSI "AcroRdrDCUpd1901220034.msp" "/qn /l* ``"C:\temp\sccm_logs\Patch_ADOBE ACROBAT READER DC V2019.012.20034.log``"" "" "" "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRD32.exe=19.12.20034.328841" 0 32`

**La fonction "EXECUTE_PATCH_MSI" accepte sept paramètres:**
1. Le nom complet du fichier MSP. *(Obligatoire)*
2. Paramètres à passer au fichier MSP.* (Optionnel)*
3. Code produit à rechercher pour confirmer la présence du patch. *(Optionnel)*
4. Clé de registre à rechercher pour confirmer la présence du patch. *(Optionnel)*
5. Chemin vers un fichier afin de confirmer la présence de l'application. *(Optionnel)*
6. Temporisation requise après l'installation en cours.* (Optionnel)*
7. Architecture de l'application. *(Obligatoire)*

### Exemple pour un fichier APPX ou APPXBUNDLE:
`EXECUTE_INSTALLATION_APPX "CheckPointVPN_1.0.14.0_x64.Appx" "B4D42709.CheckPointVPN" 1.0.14.0`

**La fonction "EXECUTE_INSTALLATION_APPX" accepte trois paramètres:**
1. Le nom du fichier APPX ou APPXBUNDLE. *(Obligatoire)*
2. Le nom de l'application tel qu'il apparait une fois installé. Peut être obtenu avec la commande powershell `Get-AppPackage`. *(Obligatoire)*
3. La version de l'application. *(Obligatoire)*

### Exemple pour un fichier CAB:
`EXECUTE_INSTALLATION_CAB "erp_activeX.CAB"`

Ici, un seul paramètre: Le nom du fichier CAB.

### Exemple pour un fichier MSU:
`EXECUTE_INSTALLATION_MSU "KB30849.MSU"`

Un seul paramètre requis: Le nom du fichier MSU.

### Customisation de l'installation:
La partie "installation" du script dispose également d'un bloc de customisation. Celui-ci n'est **exécuté que si l'installation est réussie** !

```powershell
If ($Global:Err_Return -eq 0)
{
	### Execute other actions: Copy file, shortcuts...
	INVENTORY_SETREGSIGN $Application_Name $Application_Version $Editor $Install_Path $Technologie $Arch
}
```
Vous pouvez ajouter ici toutes les autres actions qui dépendent de la réussite de l'installation de l'application.

### Signature de l'application
La signature de l'application est appelée automatiquement si l'installation est réussie par l'appel suivant:
`INVENTORY_SETREGSIGN $Application_Name $Application_Version $Editor $Install_Path $Technologie $Arch`

# Remove.ps1
Utilisation du script "Remove.ps1".
Ce script permet de désinstaller une ou plusieur(s) application(s) tout en gérant le nettoyage du système.

## Informations de l'application
Reseigner les informations de l'application (l420):
```powershell
$Installtype = ""               # USER for user installation or SYSTEM for a system installation
$Application_Name = ""          # Application name
$Application_Version = ""       # Application version
$Arch =                         # 32 or 64
$Kill_Process = @()             # Process to kil. If neccessary. Ex: $Kill_Process = @("chrome","iexplore","firefox")
$Reboot_Code = 0                # 3010 for reboot
```

## Exemple pour un fichier EXE:
`EXECUTE_UNINSTALL_EXE "C:\Program Files\Mozilla Firefox\uninstall\helper.exe" "/S" "" "C:\Program Files\Mozilla Firefox\firefox.exe=57.0.2" 0 64`

**La fonction "EXECUTE_UNINSTALL_EXE" accepte six paramètres:**
1. Chemin vers l'executable ou nom de l'executable (si située dans le même repertoire que le script). *(Obligatoire)*
2. Paramètres à passer a l'executable. *(Optionnel)*
3. Clé de registre à rechercher pour confirmer ou non la présence de l'application. *(Optionnel)*
4. Chemin vers un fichier pour confirmer ou non la présence de l'application. *(Optionnel)*
5. Temporisation requise après l'installation en cours. *(Optionnel)*
6. Architecture de l'installation. 32 ou 64. *(Obligatoire)*

## Exemple pour un fichier MSI:
`EXECUTE_UNINSTALL_MSI "{23170F69-40C1-2702-1801-000001000000}" "/qn /l* ``"C:\temp\sccm_logs\Remove_7ZIP V18.01.log``"" "{23170F69-40C1-2702-1801-000001000000}" "REG KEY" "FILE" 0 64`

**La fonction "EXECUTE_UNINSTALL_MSI" attend plusieurs paramètres:**
1. Le code produit du MSI à désinstaller. *(Obligatoire)*
2. Les paramètres à passer lors de l'execution du MSI. *(Optionnel)*
3. Le code produit MSI à detecter pour confirmer ou non la présence de l'application. Généralement identique au premier paramètre, peux différerer dans certains cas. *(Optionnel)*
4. Une clé de registre à détecter coté CurrentV/Uninstall. Le chemin de la clé est automatiquement résolu en fonction de l'architecture renseignée en 7éme paramètre. *(Optionnel)*
5. Chemin vers un fichier permettant de confirmer ou non la présence de l'application. *(Optionnel)*
6. Délais (en secondes) de temporisation requis après la fin de l'execution en cours. *(Optionnel)*
7. Architecture cible de l'application. 32 (pour 32bits) ou 64 (pour 64bits). *(Obligatoire)*

### Exemple pour un fichier APPX:
`EXECUTE_UNINSTALL_APPX "B4D42709.CheckPointVPN"`
Un seul paramètre: le nom de l'application tel qu'il apparait une fois installé.
Peut être obtenu via la commande powershell `Get-AppPackage`.

### Execution des autres actions:
Afin de réaliser des actions de customisation et/ou de paramètrage de l'application, une portion de code est présente dans chaque bloc d'actions.
Attention, ce bloc de code n'est exécuté que si la désinstallation à réussie !

```powershell
If ($Global:Err_Return -eq 0)
{
	### Execute other actions: Suppress file, shortcuts...
	Remove-Item "C:\Users\public\Desktop\Google Chrome.lnk" -force -ErrorAction 'SilentlyContinue'
	INVENTORY_REMOVEREGSIGN $Application_Name $Application_Version $Arch
}
```

### Suppression de la signature d'une application
L'appel à la fonction "INVENTORY_REMOVEREGSIGN" est automatique:
`INVENTORY_REMOVEREGSIGN $Application_Name $Application_Version $Arch`

# Journalisation
Un fichier .log est crée dans "C:\temp\sccm_logs".

# Exemples
Plusieurs exemples seront mis à disposition.
