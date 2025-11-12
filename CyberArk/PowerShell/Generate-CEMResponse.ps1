[CmdletBinding()]
Param( 
    [Parameter(Mandatory=$false)] [string]$CEM_ApplicationID, 
    [Parameter(Mandatory=$false)] [string]$DirectoryID
) 

##############################################################################################################
#
# Name: Generate-CEMResponse.ps1
# Author: Jon Musker 
# Purpose: Creates the correct "FinalVa1ue" required to onboard a new Azure directory to CEM/SCA 
#          Intended for use where the CEM/SCA onboarding script is not used, and instead the Azure configuration 
#          has been performed out-of-band 
#
##############################################################################################################

Write-Verbose "Retrieving the values required for CEM ..." 

$outstring   = '{"directory_id":"[dir_id]","application_id":"[app_id]","secret":"[secret]"}' 
$dirid       = ""
$appid       = ""

if($DirectoryID.Length -gt 1) { 
    $dirid = $DirectoryID 
} else { 
    $dirid = Read-Host -Prompt "Directory/Tenant ID (guid)" 
}

if($CEM_ApplicationID.Length -gt 1) { 
    $appid = $CEM_ApplicationID
} else { 
    $appid = Read-Host -Prompt "CEM Application ID (guid)" 
}
$testguid = [guid]::new($dirid)   ##throw error if not a valid GUID
$testguid = [guid]::new($appid)   ##throw error if not a valid GUID


Write-Verbose "Requesting secret for application $appid ..."
$cred = Get-credential -Username $appid.ToString() -message "Application Secret" 

$outstring = $outstring.Replace( "[dir_id]", $dirid.ToString() )
$outstring = $outstring.Replace( "[app_id]", $appid.ToString() )
$outstring = $outstring.Replace( "[secret]", $cred.GetNetworkCredential().Password )  

$bytes = [System.Text.Encoding]::UTF8.GetBytes( $outstring ) 
Return [Convert]::ToBase64String($bytes) 