[CmdletBinding()]
Param([Parameter(Mandatory)][string]$TenantSubdomain )
$PLATFORMDISCOVERY_URI = "https://platform-discovery.cyberark.cloud/api/v2/services/subdomain"
$split = $TenantSubdomain.Split(".")

$target = $split[0].replace("https://","")

try{
	$TenantInfo = Invoke-RestMethod -Method GET -Uri "$PLATFORMDISCOVERY_URI/$TenantSubdomain" -Headers @{"accept"="application/json"}
}
catch {
	return
}

$results = "" | Select PCloud,Identity,RDP,SSH,Vault,VaultIP,ConnectorBackend

$pcloudbase = $TenantInfo.pcloud.api.replace("/api","").replace(".privilegecloud","").replace("https://","").replace("/","")

$results.PCloud           = "https://" + $pcloudbase
$results.Identity         = $TenantInfo.identity_administration.ui
$results.RDP              = $pcloudbase.replace($target,"$target.rdp")
$results.SSH              = $pcloudbase.replace($target,"$target.ssh")
$results.Vault            = "vault-" + $TenantInfo.pcloud.api.replace("/api","").replace("https://","").replace("/","")
$results.ConnectorBackend = "vault-" + $TenantInfo.pcloud.api.replace("/api","").replace("https://","").replace("/","")

try{
	$res  = [System.Net.Dns]::gethostentry($results.Vault)
	$results.VaultIP = $res.AddressList | ?{$_.IPAddressToString -match "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"} | select -First 1 -ExpandProperty IPAddressToString
} catch{}

return $results
