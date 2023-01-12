###     Version: 1.5 - Release Candidate


#Administrative Shell starten
function Check-Admin 
{
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
if ((Check-Admin) -eq $false)  
{
    Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
    Stop-Process -Id $PID               #Beenden erste PS-Session
}
$scriptDirectory = Split-Path $MyInvocation.MyCommand.Path
Set-Location $scriptDirectory 
#Aufruf administrative Shell abgeschlossen (Adminrechte abfragen[optional: Eingabe Admin-Credentials], öffnen neuer administrativer Shell mit Skript )


#Definition Variable $InstallationName

$InstallationName = read-host -Prompt "Bitte Installationkuerzel im internen Format eingeben, INKLUSIVE Ziffer"           #Definition Variable $InstallationName


#Logging

start-transcript c:\LOG\transcript_$InstallationName.txt


#Prüfung und Reperatur sicherer Kanal zum DC

function TestSecureChannel
{
    Test-ComputerSecureChannel -server DomainController -Verbose             #Hier DomainController angeben
}
    if ((TestSecureChannel) -eq $false) 
{
    Test-ComputerSecureChannel -server DomainController -Verbose -repair     #Hier DomainController angeben
}


#Start des Skriptes
Read-Host -Prompt "Dieses Skript dient zur Erstellung neuer AD-Projektgruppen sowie der dazugehörigen Ordner. Zum Starten bitte 'Enter' drücken."   #Startformel


#Variablendefinition Installationen - YourPath durch spezifischen Pfad auf dem FS ersetzen

$InstallationPfad = "\\Fileserver\YourPath\$($InstallationName)"              
$ProduktionOrdner = "\\Fileserver\YourPath"                                  


#AD-Gruppen erstellen - AD-Path durch eigenen spezifischen Pfad im AD ersetzen

Import-Module ActiveDirectory
New-ADGroup -Name "$($InstallationName)_Mgr" -Path AD-Path -GroupScope DomainLocal -Description "Manager der Installation $($InstallationName)"
New-ADGroup -Name "$($InstallationName)_Usr" -Path AD-Path -GroupScope DomainLocal -Description "User der Installation $($InstallationName)"
New-ADGroup -Name "$($InstallationName)_Obsrv" -Path AD-Path -GroupScope DomainLocal -Description "Observer der Installation $($InstallationName)"


#Zuweisung von Nutzern (fest)

$($InstallationName) +"_Mgr" | Add-ADGroupMember -Members #Eingabe fester Mitglieder Manager-Gruppe
$($InstallationName) +"_Usr" | Add-ADGroupMember -Members 


#Zuweisung von einzelnen Nutzern in Gruppen (OP, derzeit keine Mehrfacheingabe von Nutzern möglich)

$($InstallationName) +"_Mgr" | Add-ADGroupMember -Members (Read-Host -Prompt "$($InstallationName)_Mgr: Eingabe EINES beteiligten Nutzer, sofern bereits bekannt")
$($InstallationName) +"_Usr" | Add-ADGroupMember -Members (Read-Host -Prompt "$($InstallationName)_Usr: Eingabe EINES beteiligten Nutzer, sofern bereits bekannt")
$($InstallationName) +"_Obsrv" | Add-ADGroupMember -Members (Read-Host -Prompt "$($InstallationName)_Obsrv: Eingabe EINES beteiligten Nutzer, sofern bereits bekannt")


#Variablendefinition AD-Gruppen

$InstallationMgr = "Domain\$($InstallationName)_Mgr"
$InstallationUsr = "Domain\$($InstallationName)_Usr"
$InstallationObsrv = "Domain\$($InstallationName)_Obsrv"


#Unterbrechung zur Synchronisation - Optional bei nur einem DC

Read-Host -Prompt "Bitte Enter drücken für eine 60-sekündige Synchronisationspause"

Write-Host "60 Sekunden verbleibend"
Start-Sleep -Seconds 10

Write-Host "50 Sekunden verbleibend"
Start-Sleep -Seconds 10

Write-Host "40 Sekunden verbleibend"
Start-Sleep -Seconds 10

Write-Host "30 Sekunden verbleibend"
Start-Sleep -Seconds 10

Write-Host "20 Sekunden verbleibend"
Start-Sleep -Seconds 10

Write-Host "10 Sekunden verbleibend"
Start-Sleep -Seconds 10

Write-Host "Pause abgeschlossen, SKriptausführung wird fortgesetzt."


#Überprüfung ob Installationsordner bereits vorhanden (Erstellung durch PMO)

function FolderCheck
{
    Test-Path -Path $InstallationPfad -Verbose      
}
    if ((FolderCheck) -eq $false) 
{
    New-Item -Name $($InstallationName) -ItemType Directory -Path $ProduktionOrdner -Verbose #Projektordner erstellen   
}


#Setzen der Zugriffsbeschränkungen

Import-Module NTFSSecurity  #Aktivierung NTFSSecurity-PS-Cmdlt

Add-NTFSAccess -Path $InstallationPfad -Account "Domain\Domänen-Admins" -AccessRights Full -AppliesTo ThisFolderSubfoldersAndFiles #Vollzugriff iFD-Domänenadmins 
Add-NTFSAccess -Path $InstallationPfad -Account $($InstallationMgr)  -AccessRights Full -AppliesTo ThisFolderSubfoldersAndFiles    #Vollzugriff Projekt-Manager-Gruppe
Add-NTFSAccess -Path $InstallationPfad -Account $($InstallationUsr) -AccessRights Modify -AppliesTo ThisFolderSubfoldersAndFiles   #Ändern-Rechte für Projekt-User-Gruppe
Add-NTFSAccess -Path $InstallationPfad -Account $($InstallationObsrv) -AccessRights Read -AppliesTo ThisFolderSubfoldersAndFiles   #Lese-Rechte für Projekt-Observer-Gruppe  

Disable-NTFSAccessInheritance -Path $InstallationPfad -RemoveInheritedAccessRules  #Vererbung brechen, Vererbte Rechte entfernen

#Abschiedsformel

Read-Host -Prompt "Task erfolgreich abgeschlossen. Zum Schließen bitte 'Enter' drücken." 


#Powershell beenden

Stop-Process -Id $PID