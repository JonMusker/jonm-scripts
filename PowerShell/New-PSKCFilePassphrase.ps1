`[CmdletBinding()]
param([string]$Manufacturer, [string]$SerialNo, [string]$User="", [int]$OTPLength=6, [string]$OTPType="HOTP", $TestMode = $false)

function ConvertTo-HexString { param ([byte[]] $data) 
    $outHexString = ""
    for($i=0; $i -lt $data.length; $i++) {$outHexString += [string]::format("{0:X2}", $data[$i]) }
    return $outHexString
}

function Concatenate-ByteArrays { param ([byte[]]$array1, [byte[]]$array2)
    $bufferCombo = New-Object byte[] ( $array1.Length + $array2.Length )
    for($i=0;$i -lt $array1.Length; $i++) {$bufferCombo[$i]                  = $array1[$i]}
    for($i=0;$i -lt $array2.Length; $i++) {$bufferCombo[$i + $array1.Length] = $array2[$i]}
    return $bufferCombo
}

function New-XmlEmptyElement { param ([System.Xml.XmlElement]$GrandParent, [string]$Parent, [string]$Name)
    [System.Xml.XmlElement]$ParentNode = $GrandParent["$Parent"]
    [System.Xml.XmlDocument]$MyDoc = [System.Xml.XmlNode]$GrandParent.SelectSingleNode('/')
    if( $Name.Contains(":")) {
        $NamespacePartCount = $Name.Split(':').Count - 1
        $nsUri = $Name.Split(':')[0..$NamespacePartCount]
        $nodeNew = $MyDoc.CreateElement("$Name", $nsUri)
    } else {
        $nodeNew = $MyDoc.CreateElement("$Name", $ParentNode.NamespaceURI)
    }
    $null = $ParentNode.AppendChild( $nodeNew)}

function New-XmlElementWIthValue { param ([System.Xml.XmlElement]$GrandParent, [string]$Parent, [string]$Name, [string]$Value)
    [System.Xml.XmlElement]$ParentNode = $GrandParent["$Parent"]
    [System.Xml.XmlDocument]$MyDoc = [System.Xml.XmlNode]$GrandParent.SelectSingleNode('/')
    if( $Name.Contains(":")) {
        $NamespacePartCount = $Name.Split(':').Count - 1
        $nsUri = $Name.Split(':')[0..$NamespacePartCount]
        $nodeNew = $MyDoc.CreateElement("$Name", $nsUri)
        $null = $nodeNew.AppendChild( $MyDoc.CreateTextNode( $Value ))
    } else {
        $nodeNew = $MyDoc.CreateElement("$Name", $ParentNode.NamespaceURI)
        $null = $nodeNew.AppendChild( $MyDoc.CreateTextNode( $Value ))
    }
    $null = $ParentNode.AppendChild( $nodeNew)
}

function New-XmlPSKCDoc {
$xinit = [xml]@"
<?xml version="1.0" encoding="UTF-8"?>
<KeyContainer
    xmlns="urn:ietf:params:xml:ns:keyprov:pskc"
    xmlns:xenc11="http://www.w3.org/2009/xmlenc11#"
    xmlns:pkcs5="http://www.rsasecurity.com/rsalabs/pkcs/schemas/pkcs-5v2-0#"
    xmlns:xenc="http://www.w3.org/2001/04/xmlenc#"
    Version="1.0">
    <EncryptionKey>
        <xenc11:DerivedKey>
            <xenc11:KeyDerivationMethod Algorithm="http://www.rsasecurity.com/rsalabs/pkcs/schemas/pkcs-5v2-0#pbkdf2">
                <pkcs5:PBKDF2-params>
                    <Salt>
                        <Specified>?</Specified>
                    </Salt>
                    <IterationCount>1000</IterationCount>
                    <KeyLength>16</KeyLength>
                    <PRF/>
                </pkcs5:PBKDF2-params>
            </xenc11:KeyDerivationMethod>
            <xenc:ReferenceList>
                <xenc:DataReference URI="#EncDat"/>
            </xenc:ReferenceList>
            <xenc11:MasterKeyName>My Password 1</xenc11:MasterKeyName>
        </xenc11:DerivedKey>
    </EncryptionKey>
    <MACMethod Algorithm="http://www.w3.org/2000/09/xmldsig#hmac-sha1">
        <MACKey>
            <xenc:EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes128-cbc"/>
            <xenc:CipherData>
                <xenc:CipherValue>?</xenc:CipherValue>
            </xenc:CipherData>
        </MACKey>
    </MACMethod>
    <KeyPackage>
        <DeviceInfo/>
        <CryptoModuleInfo>
            <Id>CM_ID_001</Id>
        </CryptoModuleInfo>
        <Key/>
    </KeyPackage>
</KeyContainer>
"@
    $xinit.KeyContainer.KeyPackage["Key"].SetAttribute("Algorithm", "urn:ietf:params:xml:ns:keyprov:pskc:hotp")
    $xinit.KeyContainer.KeyPackage["Key"].SetAttribute("Id", $SerialNo)
    New-XmlElementWIthValue $xinit.KeyContainer.KeyPackage "Key" "Issuer" "GResearch"
    New-XmlEmptyElement $xinit.KeyContainer.KeyPackage "Key" "AlgorithmParameters"
    New-XmlEmptyElement $xinit.KeyContainer.KeyPackage.Key "AlgorithmParameters" "ResponseFormat"
    $xinit.KeyContainer.KeyPackage.Key.AlgorithmParameters["ResponseFormat"].SetAttribute("Encoding", "DECIMAL")
    New-XmlEmptyElement $xinit.KeyContainer.KeyPackage "Key" "Data"
    New-XmlEmptyElement $xinit.KeyContainer.KeyPackage.Key "Data" "Secret"
    New-XmlEmptyElement $xinit.KeyContainer.KeyPackage.Key.Data "Secret" "EncryptedValue"
    $xinit.KeyContainer.KeyPackage.Key.Data.Secret["EncryptedValue"].SetAttribute("Id", "EncDat")
    New-XmlEmptyElement $xinit.KeyContainer.KeyPackage.Key.Data.Secret "EncryptedValue" "xenc:EncryptionMethod"
    $xinit.KeyContainer.KeyPackage.Key.Data.Secret.EncryptedValue["xenc:EncryptionMethod"].SetAttribute("Algorithm", "http://www.w3.org/2001/04/xmlenc#aes128-cbc")
    New-XmlEmptyElement $xinit.KeyContainer.KeyPackage.Key.Data.Secret "EncryptedValue" "xenc:CipherData"
    return $xinit
}

function New-Salt { param([string]$Initialisation = "Random")
    $bufferSalt = New-Object byte[] 8
    if ($Initialisation -eq "Test") {
        Write-Verbose "Using fixed Salt - this mode is only used for validating the code against the samples in https://www.rfc-editor.org/rfc/rfc6030.txt"
        $bufferSalt =  [byte] 0x12, 0x3e, 0xff, 0x3c, 0x4a, 0x72, 0x12, 0x9c
    } else {
        Write-Verbose "Generating random Salt"
        $randy = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
        $randy.GetBytes($bufferSalt);
    }
    return $bufferSalt
}

function New-InitialisationVector { param([string]$Initialisation = "Random")
    $bufferIV = New-Object byte[] 16
    if ($Initialisation -eq "Test Key") {
        Write-Verbose "Using fixed IV - this mode is only used for validating the code against the samples in https://www.rfc-editor.org/rfc/rfc6030.txt"
        $bufferIV =  [byte] 0xa1, 0x3b, 0xe8, 0xf9, 0x2d, 0xb6, 0x9e, 0xc9, 0x92, 0xd9, 0x9f, 0xd1, 0xb5, 0xca, 0x05, 0xf0
    } elseif ($Initialisation -eq "Test MACKey") {
        Write-Verbose "Using fixed IV for MAC - this mode is only used for validating the code against the samples in https://www.rfc-editor.org/rfc/rfc6030.txt"
        $bufferIV =  [byte] 0xd8, 0x64, 0xd3, 0x9c, 0xbc, 0x0c, 0xdc, 0x8e, 0x1e, 0xe4, 0x83, 0xb9, 0x16, 0x4b, 0x9f, 0xa0
    } else {
        Write-Verbose "Generating random InitialisationVector"
        $randy = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
        $randy.GetBytes($bufferIV);
    }
    return $bufferIV
}

function New-MACKey { param([string]$Initialisation = "Random")
    $bufferMACKey = New-Object byte[] 20
    if ($Initialisation -eq "Test") {
        Write-Verbose "Using fixed MAC Key - this mode is only used for validating the code against the samples in https://www.rfc-editor.org/rfc/rfc6030.txt"
        $bufferMACKey =  [byte] 0xbd, 0xaa, 0xb8, 0xd6, 0x48, 0xe8, 0x50, 0xd2, 0x5a, 0x32, 0x89, 0x36, 0x4f, 0x7d, 0x7e, 0xaa, 0xf5, 0x3c, 0xe5, 0x81
    } else {
        Write-Verbose "Generating random MAC Key"
        $randy = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
        $randy.GetBytes($bufferMACKey);
    }
    return $bufferMACKey
}

function Invoke-Crypto { param([byte[]]$key, [byte[]]$IV, [string]$plaintext, [byte[]]$plainbytes)
    $aes = new-object System.Security.Cryptography.RijndaelManaged
    $aes.Padding="PKCS7" ##should be PKCS5 - identical
    $aes.KeySize = $key.Length * 8
    $aes.mode="CBC"
    $aes.key = $key
    $aes.iv = $IV
    $aes.BlockSize = 128
    $encryptor = $aes.CreateEncryptor($Key, $IV)
    $ms = New-Object System.IO.MemoryStream
    $cs = New-Object System.Security.Cryptography.CryptoStream($ms, $encryptor, "Write")
    if($plaintext.Length -gt 0) { $plainbytes = [Text.Encoding]::UTF8.GetBytes($plaintext) }
    $cs.Write($plainbytes, 0, $plainbytes.Length)
    $cs.FlushFinalBlock()
    return $ms.ToArray()
}

function New-HMACSHA1 { param([byte[]]$key, [byte[]]$message)
    $macgen = New-Object System.Security.Cryptography.HMACSHA1
    $macgen.Key = $key
    $macgen.Initialize()
    return $macgen.ComputeHash($message)
}

function New-PSKCPassword { param([string]$Initialisation = "Random", [int]$Length=12, [bool]$LettersOnly=$false)
    $OutString = New-Object System.Text.StringBuilder
    $bufferPWd = New-Object byte[] ($Length * 40)
    if ($Initialisation -eq "Test Pwd") {
        Write-Verbose "Using fixed password - this mode is only used for validating the code against the samples in https://www.rfc-editor.org/rfc/rfc6030.txt"
        $null = $OutString.Append("qwerty")
    } elseif ($Initialisation -eq "Test Seed") {
        Write-Verbose "Using fixed Seed - this mode is only used for validating the code against the samples in https://www.rfc-editor.org/rfc/rfc6030.txt"
        $null = $OutString.Append("12345678901234567890")
    } else {
        Write-Verbose "Generating random MAC Key"
        $randy = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
        $randy.GetBytes($bufferPWd);
        for ($i=1; $i -lt $bufferPwd.Length; $i++){
            try{
                if($bufferPwd[$i] -le 0x7d -and $bufferPwd[$i] -ge 0x21) {
                    $ch = [char]::ConvertFromUtf32( $bufferPwd[$i] )
                    if ( -not $LettersOnly -and $ch -match "[A-Za-z0-9_\*\[\]\(\)-]") { $null= $OutString.Append($ch) }
                    elseif ( $ch -match "[A-Za-z]"){ $null= $OutString.Append($ch) }
                }
            } catch {}
            if($OutString.Length -ge $Length) { break }
        }
    }
    return $OutString.ToString()
}

Write-Verbose "Creating PSKC file encrypted with PBKDF2 for device $($Manufacturer):$($SerialNo). Type=$OTPType, $OTPLength digits"
$Mode = ""
if ($TestMode){ $Mode = "Test"; Write-Verbose "Initialising (TestMode) ..."} else { Write-Verbose "Initialising (Live Mode) ..."}
$iterations  = 1000

if ($Manufacturer.Length -lt 3){ Write-Error "Manufacturer key is required, min length 3"; Return }
if ($User.Length -gt 10)       { Write-Error "User is optional, max length 10 (username not email)"; Return }
if ($OTPType -eq "HOTP") {
    if($OTPLength -lt 6 -or $OTPLength -gt 8) { Write-Error "OTPLength is required, between 6 and 8"; Return }
} elseif ($OTPType -eq "TOTP") {
} else {
    Write-Error "OTPType is required, either HOTP or TOTP"; Return 
}

Write-Verbose "Setting up XML output..."
$XmlDoc = New-XmlPSKCDoc 
$OutputFileName = Join-Path $PSScriptRoot ("$Manufacturer_xxx_$($User).xml")

Write-Verbose "Starting crypto..."
[string]$Password =  New-PSKCPassword -Initialisation "$Mode Pwd"  -Length 12 -LettersOnly $false
[string]$Seed     =  New-PSKCPassword -Initialisation "$Mode Seed" -Length 20 -LettersOnly $true

$saltbytes = New-Salt $Mode
Write-Verbose ("Salt = " + (ConvertTo-HexString $saltbytes))
$Keygen = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Password, $saltbytes, $iterations)
$DerivedKey = $Keygen.GetBytes(16)
Write-verbose -Message ("Derived Key: " + (ConvertTo-HexString $DerivedKey))
$IV_Key = New-InitialisationVector "$Mode Key"
Write-Verbose ("IV:" + ( ConvertTo-HexString $IV_Key))
$secret_seed = Invoke-Crypto $DerivedKey $IV_Key $Seed
Write-Verbose ("EncryptedSeed:" + ( ConvertTo-HexString $secret_seed))

$iv_and_seed = Concatenate-ByteArrays $IV_Key $secret_seed

Write-Verbose "Generating MAC..."
$MACKey = New-MACKey $Mode
Write-verbose -Message ("MAC Key: " + (ConvertTo-HexString $MACKey))
$IV_MAC = New-InitialisationVector "$Mode MACKey"
Write-Verbose ("MAC IV:" + ( ConvertTo-HexString $IV_MAC))
$secret_mac_key = Invoke-Crypto $DerivedKey $IV_MAC "" $MACKey
$iv_and_mackey = Concatenate-ByteArrays $IV_MAC $secret_mac_key
Write-Verbose ("Encrypted MAC Key:" + ( ConvertTo-HexString $secret_mac_key) + " : " + ([Convert]::ToBase64String( $iv_and_mackey )) )
Write-Verbose ("Encrypted Seed   :" + ( ConvertTo-HexString $secret_seed) + " : " + ([Convert]::ToBase64String( $iv_and_seed )) )

$mac = New-HMACSHA1 $MACKey $iv_and_seed
Write-Verbose ("HMAC:" + ( ConvertTo-HexString $mac) + " : " + ([Convert]::ToBase64String( $mac )) )

Write-Verbose ("Updating XML with variable data")
New-XmlElementWIthValue $xmldoc.KeyContainer.KeyPackage "DeviceInfo" "Manufacturer" $Manufacturer
if($SerialNo.Length -gt 0) {
    New-XmlElementWIthValue $xmldoc.KeyContainer.KeyPackage "DeviceInfo" "SerialNo" $SerialNo
    $OutputFileName = Join-Path $PSScriptRoot ("$Manufacturer_$($SerialNo)_$($User).xml")
}

$xmldoc.KeyContainer.EncryptionKey.DerivedKey.KeyDerivationMethod.'PBKDF2-params'.Salt.Specified = [convert]::ToBase64String($saltbytes)
$xmldoc.KeyContainer.KeyPackage.Key.AlgorithmParameters["ResponseFormat"].SetAttribute("Length", [string]$OTPLength)
New-XmlElementWIthValue $xmldoc.KeyContainer.KeyPackage.Key.Data.Secret.EncryptedValue "xenc:CipherData" "xenc:CipherValue" ([Convert]::ToBase64String($iv_and_seed))
$xmldoc.KeyContainer.MACMethod.MACKey.CipherData.CipherValue = [Convert]::ToBase64String($iv_and_mackey)
New-XmlElementWIthValue $xmldoc.KeyContainer.KeyPackage.Key.Data "Secret" "ValueMAC" ( [Convert]::ToBase64String($mac) )

If ($TestMode) {
    Write-Host "Test mode results:"
    Write-Host "-----------------"
    Write-Host "Salt value match RFC6030 sample:              "  ( ([convert]::ToBase64String($saltbytes)) -eq "Ej7/PEpyEpw="  )
    Write-Host "Derived Key match RFC6030 sample:             "  ( (ConvertTo-HexString $DerivedKey ) -eq "651e63cd57008476af1ff6422cd02e41")
    Write-Host "Encrypted MAC Key value match RFC6030 sample: "  ( ([Convert]::ToBase64String($iv_and_mackey)) -eq "2GTTnLwM3I4e5IO5FkufoOEiOhNj91fhKRQBtBJYluUDsPOLTfUvoU2dStyOwYZx"  )
    Write-Host "Encrypted Seed value match RFC6030 sample:    "  ( ([Convert]::ToBase64String($iv_and_seed)) -eq "oTvo+S22nsmS2Z/RtcoF8Hfh+jzMe0RkiafpoDpnoZTjPYZu6V+A4aEn032yCr4f"  )
    Write-Host "Computed MAC value match RFC6030 sample:      "  ( ([Convert]::ToBase64String($mac)) -eq "LP6xMvjtypbfT9PdkJhBZ+D6O4w="  )
    Write-Host "-----------------"
}

Write-Host "Writing PSKC XML file to $OutputFileName"
Write-Host "$OutputFileName Password:  $Password"
Write-Host "URI:   otpauth://hotp/GRHOTP:$($User)?secret=$($Seed)&counter=0&digits=$($OTPLength)&issuer=GResearch"
if(Test-Path $OutputFileName){del $OutputFileName}
if(Test-Path $OutputFileName){Write-Error "Cannot delete $OutputFileName. Cannot continue"; return }
$XmlDoc.Save( $OutputFileName )
