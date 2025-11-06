[CmdletBinding()]param([string]$TenantSubdomain="cctest1", [System.Management.Automation.PSCredential]$Credential, [switch]$Force)
#Login for a service account - not suitable for interactive login

if (!($Force.IsPresent) -and (Get-Date) -gt $Global:CASession.AccessFrom -and  (Get-Date) -lt $Global:CASession.AccessTo){
    Write-Verbose "Already logged in"
    return $True
}

if(!$tenantUri.EndsWith("/")){$tenantUri = $tenantUri + "/"}
if($tenantUri -notmatch "/oauth2/platformtoken"){ $tenantUri = $tenantUri + "oauth2/platformtoken"}

Function Parse-JWT{
    param($Raw="")

    $head=$raw.Split(".")[0]
    $body=$raw.Split(".")[1]
    $sig =$raw.Split(".")[2]

    Function Decode-Base64([string]$b64)
    {
        $bytes=@()
        try{
            $bytes = [System.Convert]::FromBase64String($b64)
        } catch {
            try {
                $bytes = [System.Convert]::FromBase64String($b64 + "=")
            } catch {
                $bytes = [System.Convert]::FromBase64String($b64 + "==")
            }
        }
        $json = [System.Text.Encoding]::UTF8.GetString($bytes)
        Return ConvertFrom-Json $json
    }

    $jwt = "" | Select Header,Payload,Signature
    $jwt.Header    = Decode-Base64 $head
    $jwt.Payload   = Decode-Base64 $body
    try {$jwt.Signature = Decode-Base64 $sig} catch {}

    return $jwt
}

Function Get-AuthToken{
    [CmdletBinding()]param(
        [string]$TenantSubdomain, 
        [System.Management.Automation.PSCredential]$Credential
    )

    $tenantUri = Get-AuthUri -TenantSubdomain $TenantSubdomain
    if($TenantSubdomain.length -eq 0 ) {throw "TenantSubdomain not valid"}
    if($tenantUri.length -eq 0 -or $tenantUri -notmatch "^https?://.+") {throw "tenantUri not valid"}
    if($Credential.UserName.length  -eq 0) {throw "Username not supplied"}
    if($Credential.Password.length  -eq 0) {throw "Password not supplied"}

    $body = @{grant_type="client_credentials";client_id=$Credential.Username;client_secret="***"}
    $headers = @{ accept="application/json" }
    Write-Verbose ($body | ConvertTo-Json )

    $body.client_secret = (New-Object PSCredential 0, $Credential.Password).GetNetworkCredential().Password
    write-verbose "connecting to $tenanturi"
    $login=Invoke-RestMethod -Method Post -Uri $tenantUri -ContentType "application/x-www-form-urlencoded" -Headers $headers -body $body
    write-verbose $login
    $session=""|select LoginUri,APIUri,APIUriv1,Username,AccessFrom,AccessTo,Headers,AccessToken

    if($login.access_token.length -gt 0 -and $login.token_type -eq "Bearer") {
        $session.LoginUri   = $tenantUri
        $session.APIUri     = "https://" + $TenantSubdomain + ".privilegecloud.cyberark.cloud/passwordvault/api/"
        $session.APIUriv1   = "https://" + $TenantSubdomain + ".privilegecloud.cyberark.cloud/passwordvault/WebServices/PIMServices.svc/"
        $session.Username   = $Credential.Username
        $session.AccessFrom = Get-Date
        $session.AccessTo   = $session.AccessFrom.AddSeconds([int]$login.expires_in)
        $session.Headers    = @{accept="application/json";authorization="Bearer " + $login.access_token}
        $session.AccessToken= $login.access_token
        $global:CASession = $session
    } else {
        throw "no access token returned"
    }
}

Function Get-AuthTokenDetails{
    $token = $Global:CASession.AccessToken
    $decoded= Parse-JWT -Raw $token
    Write-Verbose $decoded
    return $decoded.Payload
}

Function Get-AuthUri{
    [CmdletBinding()]param(
    [string]$TenantSubdomain)
    $PLATFORMDISCOVERY_URI = "https://platform-discovery.cyberark.cloud/api/v2/services/subdomain"
    $TenantInfo = Invoke-RestMethod -Method GET -Uri "$PLATFORMDISCOVERY_URI/$TenantSubdomain" -Headers @{"accept"="application/json"}
    Return $TenantInfo.identity_administration.ui
}

Get-AuthToken -TenantSubdomain $TenantSubdomain -tenantUri $tenantUri -Credential $Credential
return Get-AuthTokenDetails