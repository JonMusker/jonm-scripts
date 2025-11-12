param($raw="")

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

Function Get-NonUrlEncodedString([string]$b64) {
    Return $b64.Replace("-","+").Replace("_","/")
}

$Clean = Get-NonUrlEncodedString $raw

$head=$Clean.Split(".")[0]
$body=$Clean.Split(".")[1]
$sig =$Clean.Split(".")[2]

$jwt = "" | Select Header,Payload,Signature
$jwt.Header    = Decode-Base64 $head
$jwt.Payload   = Decode-Base64 $body

try {$jwt.Signature = Decode-Base64 $sig} catch {}

return $jwt
