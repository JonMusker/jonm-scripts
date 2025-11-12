[CmdletBinding()]
Param( 
    [Parameter(Mandatory=$false)] [string]$DirectoryID,
    [Parameter(Mandatory=$false)] [string]$SCA_EntraID_ApplicationID, 
    [Parameter(Mandatory=$false)] [string]$SCA_EntraID_ObjectID, 
    [Parameter(Mandatory=$false)] [string]$SCA_EntraID_SecretID, 
    [Parameter(Mandatory=$false)] [string]$SCA_Resources_ApplicationID, 
    [Parameter(Mandatory=$false)] [string]$SCA_Resources_ObjectID, 
    [Parameter(Mandatory=$false)] [string]$SCA_Resources_SecretID
) 

##############################################################################################################
#
# Name: Generate-SCAResponse.ps1
# Author: Jon Musker 
# Purpose: Creates the correct "FinalVa1ue" required to onboard a new Azure directory to CEM/SCA 
#          Intended for use where the CEM/SCA onboarding script is not used, and instead the Azure configuration 
#          has been performed out-of-band 
#
##############################################################################################################

Write-Verbose "Retrieving the values required for CEM ..."
 
$outstring   = '{"azure_aad":{"directory_id":"[dir_id]","application_id":"[aad_app_id]","secret":"[aad_secret]","key_id":"[aad_key_id]","object_id":"[aad_obj_id]"},"azure_resources":{"directory_id":"[dir_id]","application_id":"[res_app_id]","secret":"[res_secret]","key_id":"[res_key_id]","object_id":"[res_obj_id]"}}' 
$dirid       = ""
$aad_appid   = ""
$aad_objid   = ""
$aad_keyid   = ""
$res_appid   = ""
$res_objid   = ""
$res_keyid   = ""

if($DirectoryID.Length -gt 1) { 
    $dirid = $DirectoryID 
} else { 
    $dirid = Read-Host -Prompt "Directory/Tenant ID (guid)" 
}

if($SCA_EntraID_ApplicationID.Length -gt 1) { 
    $aad_appid = $SCA_EntraID_ApplicationID
} else { 
    $aad_appid = Read-Host -Prompt "EntraID/AAD SPN Application ID (guid)" 
}

if($SCA_EntraID_ObjectID.Length -gt 1) { 
    $aad_objid = $SCA_EntraID_ObjectID
} else { 
    $aad_objid = Read-Host -Prompt "EntraID/AAD SPN Object ID (guid)" 
}

if($SCA_EntraID_SecretID.Length -gt 1) { 
    $aad_keyid = $SCA_EntraID_SecretID
} else { 
    $aad_keyid = Read-Host -Prompt "EntraID/AAD SPN Secret ID (guid)" 
}

$testguid = [guid]::new($dirid)       ##throw error if not a valid GUID
$testguid = [guid]::new($aad_appid)   ##throw error if not a valid GUID
$testguid = [guid]::new($aad_objid)   ##throw error if not a valid GUID
$testguid = [guid]::new($aad_keyid)   ##throw error if not a valid GUID

Write-Verbose "Requesting secret for application $aad_appid ..."
$aad_cred = Get-credential -Username $aad_appid.ToString() -message "EntraID/AAD SPN Secret" 

if($SCA_Resources_ApplicationID.Length -gt 1) { 
    $res_appid = $SCA_Resources_ApplicationID
} else { 
    $res_appid = Read-Host -Prompt "Subscriptions/Resources SPN Application ID (guid)" 
}

if($SCA_Resources_ObjectID.Length -gt 1) { 
    $res_objid = $SCA_Resources_ObjectID
} else { 
    $res_objid = Read-Host -Prompt "Subscriptions/Resources SPN Object ID (guid)" 
}

if($SCA_Resources_SecretID.Length -gt 1) { 
    $res_keyid = $SCA_Resources_SecretID
} else { 
    $res_keyid = Read-Host -Prompt "Subscriptions/Resources SPN Secret ID (guid)" 
}

$testguid = [guid]::new($res_appid)   ##throw error if not a valid GUID
$testguid = [guid]::new($res_objid)   ##throw error if not a valid GUID
$testguid = [guid]::new($res_keyid)   ##throw error if not a valid GUID

Write-Verbose "Requesting secret for application $res_appid ..."
$res_cred = Get-credential -Username $res_appid.ToString() -message "Subscriptions/Resources SPN Secret" 

$outstring = $outstring.Replace( "[dir_id]",     $dirid.ToString() )
$outstring = $outstring.Replace( "[aad_app_id]", $aad_appid.ToString() )
$outstring = $outstring.Replace( "[aad_obj_id]", $aad_objid.ToString() )
$outstring = $outstring.Replace( "[aad_key_id]", $aad_keyid.ToString() )
$outstring = $outstring.Replace( "[aad_secret]", $aad_cred.GetNetworkCredential().Password )  
$outstring = $outstring.Replace( "[res_app_id]", $res_appid.ToString() )
$outstring = $outstring.Replace( "[res_obj_id]", $res_objid.ToString() )
$outstring = $outstring.Replace( "[res_key_id]", $res_keyid.ToString() )
$outstring = $outstring.Replace( "[res_secret]", $res_cred.GetNetworkCredential().Password )  

$bytes = [System.Text.Encoding]::UTF8.GetBytes( $outstring ) 
Return [Convert]::ToBase64String($bytes) 