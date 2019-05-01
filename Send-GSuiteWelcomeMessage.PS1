<# 
.SYNOPSIS
	This script sends a Welcome message to new user's GSuite inbox.
.DESCRIPTION
.EXAMPLE
.INPUTS
.OUTPUTS
.NOTES
#>

[CMDLETBINDING()]
param (
 [Parameter(Mandatory=$True)]
 [Alias('DC','Server')]
 [ValidateScript({Test-Connection -ComputerName $_ -Quiet -Count 1})]
 [string]$DomainController,
 # PSSession to Domain Controller and Use Active Directory CMDLETS  
 [Parameter(Mandatory=$True)]
 [Alias('ADCred')]
 [System.Management.Automation.PSCredential]$ADCredential,
 [Parameter(Mandatory=$True)]
 [Alias('MailCred')]
 [System.Management.Automation.PSCredential]$EmailCredential,
	[SWITCH]$WhatIf
)

# Clear-Host ; $error.clear() # Clear screen and error log.
Get-PSSession | Remove-PSSession -WhatIf:$false

# AD Domain Controller Session
$adCmdLets = 'Get-ADUser','Set-ADUser'
$adSession = New-PSSession -ComputerName $DomainController -Credential $ADCredential
Import-PSSession -Session $adSession -Module ActiveDirectory -CommandName $adCmdLets -AllowClobber

# Imported Functions
. .\lib\Add-Log.ps1
. .\lib\Format-GSuiteMessage.ps1

# LDAPFilter looks for employeeID,gsuite address, and extensionAttribute9 != GSuiteMessageSent
$employeeParams = @{
 LDAPFilter = "(employeeID=*)(wWWHomePage=*@chicousd.net)(!extensionAttribute9=GSuiteMessageSent)"
 properties = 'employeeid','homepage','mail','extensionAttribute9','whenCreated'
 searchBase = 'OU=Employees,OU=Users,OU=Domain_Root,DC=chico,DC=usd'
}
# Get qualifying employee user objects
$newEmployees = Get-ADUser @employeeParams | Where-Object {$_.whencreated -gt (get-date).adddays(-5)}

foreach  (	$user in $newEmployees ){
 Write-Debug ("Process {0} ?" -f $user.name)
 
	$mailParams = @{
  To =  ( $To = "<{0}>" -f $user.homepage )
  Bcc = '<jcooper@chicousd.org>'
		From =  "Welcome to CUSD! <{0}>" -f $EmailCredential.Username
		Subject = 'Your New CUSD Google Account'
		BodyAsHTML = $True
		Body = ( $html = Format-GSuiteMessage $user.givenName $user.samAccountName )
		SMTPServer = 'smtp.gmail.com'
		Cred = $EmailCredential
		UseSSL = $True
		Port = 587
 }
	
 Add-Log email ("{0},GSuite Welcome message sent" -f $user.homepage)
	if ($WhatIf) { $to,$html }
 else { Send-MailMessage @mailParams }
 
 Set-ADUser -Identity $user.ObjectGuid -replace @{extensionAttribute9="GSuiteMessageSent"} -WhatIf:$WhatIf
}

Add-Log script "Tearing down PS Sessions..."
Get-PSSession | Remove-PSSession -WhatIf:$false