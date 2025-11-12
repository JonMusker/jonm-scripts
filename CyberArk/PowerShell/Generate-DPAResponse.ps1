[CmdletBinding()]
Param( 
    [Parameter(Mandatory=$false)] [string]$DPA_ApplicationID
) 

##############################################################################################################
#
# Name: Generate-SCAResponse.ps1
# Author: Jon Musker 
# Purpose: Creates the correct "FinalVa1ue" required to onboard a new Azure directory to DPA 
#          Intended for use where the DPA onboarding script is not used, and instead the Azure configuration 
#          has been performed out-of-band 
#
##############################################################################################################

Write-Verbose "Retrieving the values required for DPA ..." 
$outstring   = '{"application_id":"[app_id]","secret":"[secret]"}' 
$appid       = ""

if($DPA_ApplicationID.Length -gt 1) { 
    $appid = $DPA_ApplicationID
} else { 
    $appid = Read-Host -Prompt "DPA Application ID (guid)" 
}

$testguid = [guid]::new($appid)   ##throw error if not a valid GUID


Write-Verbose "Requesting secret for application $appid ..."
$cred = Get-credential -Username $appid.ToString() -message "Application Secret" 

$outstring = $outstring.Replace( "[app_id]", $appid.ToString() )
$outstring = $outstring.Replace( "[secret]", $cred.GetNetworkCredential().Password )  

$bytes = [System.Text.Encoding]::UTF8.GetBytes( $outstring ) 
Return [Convert]::ToBase64String($bytes) 