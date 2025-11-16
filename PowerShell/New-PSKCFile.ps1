[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern("^[0-9A-Za-z_-]{3,15}$")][string]$Manufacturer, 
    [Parameter(Mandatory=$true)][ValidatePattern("^[0-9A-Za-z_]{3,15}$")] [string]$Username,
    [ValidateRange(1,30)][int]$TokenNumber=1, 
    [ValidateRange(6,8)][int]$OTPLength=6, 
    [ValidatePattern("^[HT]OTP$")][string]$OTPType="HOTP", 
    [ValidatePattern("^(PreSharedKey)|(Passphrase)|(PBKDF2)$")][string]$KeyType = "PreSharedKey", 
    [switch]$TestMode,
    [switch]$ShowInitialisationUri,
    [switch]$ShowSeedAsHex,
    [switch]$ShowSeedAsPlainText,
    [switch]$ShowSeedAsBase32,
    [switch]$DoNotGenerateQRCode
)

######################################################################
########   New-PSKCFile.ps1
########   Scripts to generate random Seed key, then create encrypted PSKC file for transport
########   and also create encoded URI ( and optional QR Code ) for token initialisation.
########   Based on RFC6030.
########   
########   Version:           1.1
########   Author:            Jon Musker
########   Written:           18/08/2021
########   Last Updated By:   
########   Last Updated Date: 
######################################################################

######################################################################
########   Helper functions

function ConvertTo-HexString { param ([byte[]] $data) 
######## Utility to create a displayable hex string from byte array
    $outHexString = ""
    for($i=0; $i -lt $data.length; $i++) {$outHexString += [string]::format("{0:X2}", $data[$i]) }
    return $outHexString
}

function ConvertTo-Base32 { param ([byte[]] $data)
######## Utility to encode into Base32 from byte array
## thanks to https://humanequivalentunit.github.io for this little gem
    $byteArrayAsBinaryString = -join $data.ForEach{ [Convert]::ToString($_, 2).PadLeft(8, '0') }

    $Base32Secret = [regex]::Replace($byteArrayAsBinaryString, '.{5}', { param($Match) 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'[[Convert]::ToInt32($Match.Value, 2)] })

    return $Base32Secret
}

function Concatenate-ByteArrays { param ([byte[]]$array1, [byte[]]$array2)
######## Utility to squish two byte arrays together
    $bufferCombo = New-Object byte[] ( $array1.Length + $array2.Length )
    for($i=0;$i -lt $array1.Length; $i++) {$bufferCombo[$i]                  = $array1[$i]}
    for($i=0;$i -lt $array2.Length; $i++) {$bufferCombo[$i + $array1.Length] = $array2[$i]}
    return $bufferCombo
}

function New-XmlEmptyElement { param ([System.Xml.XmlElement]$GrandParent, [string]$Parent, [string]$Name)
######## Utility to add a new XmlElement at a specific location in the XmlDoc
    [System.Xml.XmlElement]$ParentNode = $GrandParent["$Parent"]
    [System.Xml.XmlDocument]$MyDoc = [System.Xml.XmlNode]$GrandParent.SelectSingleNode('/')
    $nsUri = $ParentNode.NamespaceURI
    if( $Name.Contains(":")) { $nsUri = $GrandParent.GetNamespaceOfPrefix( $Name.Split(':')[0] ) }
    $nodeNew = $MyDoc.CreateElement("$Name", $nsUri)
    $null = $ParentNode.AppendChild( $nodeNew)}

function New-XmlElementWIthValue { param ([System.Xml.XmlElement]$GrandParent, [string]$Parent, [string]$Name, [string]$Value)
######## Utility to add a new XmlElement and set a (text) value to it, at a specific location in the XmlDoc
    [System.Xml.XmlElement]$ParentNode = $GrandParent["$Parent"]
    [System.Xml.XmlDocument]$MyDoc = [System.Xml.XmlNode]$GrandParent.SelectSingleNode('/')
    $nsUri = $ParentNode.NamespaceURI
    if( $Name.Contains(":")) { $nsUri = $GrandParent.GetNamespaceOfPrefix( $Name.Split(':')[0] ) }
    $nodeNew = $MyDoc.CreateElement("$Name", $nsUri)
    $null = $nodeNew.AppendChild( $MyDoc.CreateTextNode( $Value ))
    $null = $ParentNode.AppendChild( $nodeNew)
}

function New-XmlPSKCDoc {
######### Creates the base XmlDocument for the PSKC
$xinit=""
if($KeyType -match "PreSharedKey") {
$xinit = [xml]@"
<?xml version="1.0" encoding="UTF-8"?>
<KeyContainer
    xmlns="urn:ietf:params:xml:ns:keyprov:pskc"
    xmlns:ds="http://www.w3.org/2000/09/xmldsig#"
    xmlns:xenc="http://www.w3.org/2001/04/xmlenc#"
    xmlns:xenc11="http://www.w3.org/2009/xmlenc11#"
    xmlns:pkcs5="http://www.rsasecurity.com/rsalabs/pkcs/schemas/pkcs-5v2-0#"
    Version="1.0">
    <EncryptionKey/>
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
        <Key/>
    </KeyPackage>
</KeyContainer>
"@
} else {
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
}
    $xinit.KeyContainer.KeyPackage["Key"].SetAttribute("Algorithm", "urn:ietf:params:xml:ns:keyprov:pskc:hotp")
    $xinit.KeyContainer.KeyPackage["Key"].SetAttribute("Id", $Username)
    New-XmlElementWIthValue $xinit.KeyContainer.KeyPackage "Key" "Issuer" "GResearch"
    New-XmlEmptyElement $xinit.KeyContainer.KeyPackage "Key" "AlgorithmParameters"
    New-XmlEmptyElement $xinit.KeyContainer.KeyPackage.Key "AlgorithmParameters" "ResponseFormat"
    $xinit.KeyContainer.KeyPackage.Key.AlgorithmParameters["ResponseFormat"].SetAttribute("Encoding", "DECIMAL")
    New-XmlEmptyElement $xinit.KeyContainer.KeyPackage "Key" "Data"
    New-XmlEmptyElement $xinit.KeyContainer.KeyPackage.Key "Data" "Secret"
    New-XmlEmptyElement $xinit.KeyContainer.KeyPackage.Key.Data "Secret" "EncryptedValue"
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
######  Creates a new random IV 
    $bufferIV = New-Object byte[] 16
    if ($Initialisation -eq "Test Key") {
        Write-Verbose "Using fixed IV - this mode is only used for validating the code against the samples in https://www.rfc-editor.org/rfc/rfc6030.txt"
        if( $KeyType -match "PreSharedKey") {
            $bufferIV =  [byte] 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
        } else {
            $bufferIV =  [byte] 0xa1, 0x3b, 0xe8, 0xf9, 0x2d, 0xb6, 0x9e, 0xc9, 0x92, 0xd9, 0x9f, 0xd1, 0xb5, 0xca, 0x05, 0xf0
        }
    } elseif ($Initialisation -eq "Test MACKey") {
        Write-Verbose "Using fixed IV for MAC - this mode is only used for validating the code against the samples in https://www.rfc-editor.org/rfc/rfc6030.txt"
        if( $KeyType -match "PreSharedKey") {
            $bufferIV =  [byte] 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66
        } else {
            $bufferIV =  [byte] 0xd8, 0x64, 0xd3, 0x9c, 0xbc, 0x0c, 0xdc, 0x8e, 0x1e, 0xe4, 0x83, 0xb9, 0x16, 0x4b, 0x9f, 0xa0
        }
    } else {
        Write-Verbose "Generating random InitialisationVector"
        $randy = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
        $randy.GetBytes($bufferIV);
    }
    return $bufferIV
}

function New-Key { param([string]$Initialisation = "Random")
####### Creates a new random Key to use in the crypto
    $bufferKey = New-Object byte[] 16
    if ($Initialisation -match "MACKey") { $bufferKey = New-Object byte[] 20 }
    if ($Initialisation -match "Test") {
        Write-Verbose "Using fixed Key - this mode is only used for validating the code against the samples in https://www.rfc-editor.org/rfc/rfc6030.txt"
        if     ($Initialisation -match " Key")    { $bufferKey =  [byte] 0x12, 0x34, 0x56, 0x78, 0x90, 0x12, 0x34, 0x56, 0x78, 0x90, 0x12, 0x34, 0x56, 0x78, 0x90, 0x12 }
        elseif ($Initialisation -match "MACKey"){
            if($KeyType -match "PreSharedKey") { $bufferKey =  [byte] 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0x00 }
            else                               { $bufferKey =  [byte] 0xbd, 0xaa, 0xb8, 0xd6, 0x48, 0xe8, 0x50, 0xd2, 0x5a, 0x32, 0x89, 0x36, 0x4f, 0x7d, 0x7e, 0xaa, 0xf5, 0x3c, 0xe5, 0x81 }
        }
    } else {
        Write-Verbose "Generating random Key"
        $randy = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
        $randy.GetBytes($bufferKey);
    }
    return $bufferKey
}

function Invoke-Crypto { param([byte[]]$key, [byte[]]$IV, [string]$plaintext, [byte[]]$plainbytes)
####### Invokes aes128 to actually encrypt something (can supply either plaintext or plainbytes; if plaintext is empty then we use the bytes)
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
####### Generates HMACSHA1 against a message
    $macgen = New-Object System.Security.Cryptography.HMACSHA1
    $macgen.Key = $key
    $macgen.Initialize()
    return $macgen.ComputeHash($message)
}

function New-PSKCPassword { param([string]$Initialisation = "Random", [int]$Length=12, [bool]$LettersOnly=$false)
####### Generates a random password; either a byte array or text depending on the value of "Initialisation"
    $OutString = New-Object System.Text.StringBuilder
    $bufferPWd = New-Object byte[] ($Length * 40)
    if ($Initialisation -eq "Test Pwd") {
        Write-Verbose "Using fixed password - this mode is only used for validating the code against the samples in https://www.rfc-editor.org/rfc/rfc6030.txt"
        $null = $OutString.Append("qwerty")
    } elseif ($Initialisation -eq "Test Seed") {
        Write-Verbose "Using fixed Seed - this mode is only used for validating the code against the samples in https://www.rfc-editor.org/rfc/rfc6030.txt"
        $null = $OutString.Append("12345678901234567890")
    } else {
        Write-Verbose "Generating $Initialisation"
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
    if($Initialisation -match "Seed") {
        return [Text.Encoding]::UTF8.GetBytes($OutString.ToString())
    } else {
        return [string]$OutString.ToString()
    }
}

################################################################################
## Start of the actual code
$QRGeneratorExe = "C:\Users\JonMuskernet\source\ConsoleApp1\ConsoleApp1\bin\Debug\net5.0\QRGenerator.exe"
$iterations  = 1000
$Mode = ""
$key = New-Object byte[] 1
$Username = [string]::format("{0}_{1:d2}", $Username, $TokenNumber)

if($KeyType -match "PreSharedKey"){
    Write-Verbose "Creating PSKC file encrypted with Pre-Shared Key for device $($Manufacturer):$($Username). Type=$OTPType, $OTPLength digits"
} else {
    Write-Verbose "Creating PSKC file encrypted with PBKDF2 (passphrase-derived key) for device $($Manufacturer):$($Username). Type=$OTPType, $OTPLength digits"
}
if ($TestMode){ $Mode = "Test"; Write-Verbose "Initialising (TestMode) ..."} else { Write-Verbose "Initialising (Live Mode) ..."}

####### Initialisation of XML document for output
Write-Verbose "Setting up XML output..."
$XmlDoc = New-XmlPSKCDoc 
$OutputFileName = Join-Path $PSScriptRoot ("$($Manufacturer)_$($Username).pskc")

####### Crypto functions begin
Write-Verbose "Starting crypto..."
[string]$Password =  New-PSKCPassword -Initialisation "$Mode Pwd"  -Length 12 -LettersOnly $false
[byte[]]$Seed     =  New-PSKCPassword -Initialisation "$Mode Seed" -Length 20 -LettersOnly $true

if($KeyType -match "PreSharedKey") {
    $Key = New-Key "$Mode Key"
    Write-verbose -Message ("Pre-Shared Key: " + (ConvertTo-HexString $Key))
} else {
    $saltbytes = New-Salt $Mode
    Write-Verbose ("Salt = " + (ConvertTo-HexString $saltbytes))
    $Keygen = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Password, $saltbytes, $iterations)
    $DerivedKey = $Keygen.GetBytes(16)
    Write-verbose -Message ("Derived Key: " + (ConvertTo-HexString $DerivedKey))
    $Key=$DerivedKey
}
$IV_Key = New-InitialisationVector "$Mode Key"
Write-Verbose ("IV:" + ( ConvertTo-HexString $IV_Key))
$secret_seed = Invoke-Crypto $Key $IV_Key "" $Seed
Write-Verbose ("EncryptedSeed:" + ( ConvertTo-HexString $secret_seed))

$iv_and_seed = Concatenate-ByteArrays $IV_Key $secret_seed

Write-Verbose "Generating MAC key..."
$MACKey = New-Key "$Mode MACKey"
Write-verbose -Message ("MAC Key: " + (ConvertTo-HexString $MACKey))
$IV_MAC = New-InitialisationVector "$Mode MACKey"
Write-Verbose ("MAC IV:" + ( ConvertTo-HexString $IV_MAC))
$secret_mac_key = Invoke-Crypto $Key $IV_MAC "" $MACKey
$iv_and_mackey = Concatenate-ByteArrays $IV_MAC $secret_mac_key
Write-Verbose ("Encrypted MAC Key:" + ( ConvertTo-HexString $secret_mac_key) + " : " + ([Convert]::ToBase64String( $iv_and_mackey )) )
Write-Verbose ("Encrypted Seed   :" + ( ConvertTo-HexString $secret_seed) + " : " + ([Convert]::ToBase64String( $iv_and_seed )) )

$mac = New-HMACSHA1 $MACKey $iv_and_seed
Write-Verbose ("HMAC:" + ( ConvertTo-HexString $mac) + " : " + ([Convert]::ToBase64String( $mac )) )

####### XML Output to PSKC File
Write-Verbose ("Updating XML with variable data")
New-XmlElementWIthValue $xmldoc.KeyContainer.KeyPackage "DeviceInfo" "Manufacturer" $Manufacturer
if($Username.Length -gt 0) {
    New-XmlElementWIthValue $xmldoc.KeyContainer.KeyPackage "DeviceInfo" "SerialNo" $Username
    $OutputFileName = Join-Path $PSScriptRoot ("$($Manufacturer)_$($Username).pskc")
}
if($KeyType -match "PreSharedKey"){
    New-XmlElementWIthValue $xmldoc.KeyContainer "EncryptionKey" "ds:KeyName" "Pre-shared-key"
} else {
    $xmldoc.KeyContainer.EncryptionKey.DerivedKey.KeyDerivationMethod.'PBKDF2-params'.Salt.Specified = [convert]::ToBase64String($saltbytes)
}

$xmldoc.KeyContainer.KeyPackage.Key.AlgorithmParameters["ResponseFormat"].SetAttribute("Length", [string]$OTPLength)
New-XmlElementWIthValue $xmldoc.KeyContainer.KeyPackage.Key.Data.Secret.EncryptedValue "xenc:CipherData" "xenc:CipherValue" ([Convert]::ToBase64String($iv_and_seed))
$xmldoc.KeyContainer.MACMethod.MACKey.CipherData.CipherValue = [Convert]::ToBase64String($iv_and_mackey)
New-XmlElementWIthValue $xmldoc.KeyContainer.KeyPackage.Key.Data "Secret" "ValueMAC" ( [Convert]::ToBase64String($mac) )
New-XmlEmptyElement $xmldoc.KeyContainer.KeyPackage.Key "Data" "Counter"
New-XmlElementWIthValue $xmldoc.KeyContainer.KeyPackage.Key.Data "Counter" "PlainValue" 0

if(Test-Path $OutputFileName){del $OutputFileName}
if(Test-Path $OutputFileName){Write-Error "Cannot delete $OutputFileName. Cannot continue"; return }
$XmlDoc.Save( $OutputFileName )
Write-Host " PSKC Transport File:" "$OutputFileName"
if($KeyType -match "PreSharedKey"){ 
    Write-Host " Pre-Shared Transport Key:" (ConvertTo-HexString $Key) 
} else {
    Write-Host " Passphrase:" $Password 
}

Write-Host ""

####### Test mode - validate against samples in the RFC
If ($TestMode) {
    Write-Host "Test mode results:"
    Write-Host "-----------------"
    if($KeyType -eq "PreSharedKey") {
        Write-Host "Key match RFC6030 sample:                     "  ( (ConvertTo-HexString $Key ) -eq "12345678901234567890123456789012")
        Write-Host "Encrypted MAC Key value match RFC6030 sample: "  ( ([Convert]::ToBase64String($iv_and_mackey)) -eq "ESIzRFVmd4iZABEiM0RVZgKn6WjLaTC1sbeBMSvIhRejN9vJa2BOlSaMrR7I5wSX"  )
        Write-Host "Encrypted Seed value match RFC6030 sample:    "  ( ([Convert]::ToBase64String($iv_and_seed)) -eq "AAECAwQFBgcICQoLDA0OD+cIHItlB3Wra1DUpxVvOx2lef1VmNPCMl8jwZqIUqGv"  )
        Write-Host "Computed MAC value match RFC6030 sample:      "  ( ([Convert]::ToBase64String($mac)) -eq "Su+NvtQfmvfJzF6bmQiJqoLRExc="  )
    } else {
        Write-Host "Passphrase match RFC6030 sample:                     "  ( $Password  -eq "qwerty")
        Write-Host "Encrypted MAC Key value match RFC6030 sample: "  ( ([Convert]::ToBase64String($iv_and_mackey)) -eq "2GTTnLwM3I4e5IO5FkufoOEiOhNj91fhKRQBtBJYluUDsPOLTfUvoU2dStyOwYZx"  )
        Write-Host "Encrypted Seed value match RFC6030 sample:    "  ( ([Convert]::ToBase64String($iv_and_seed)) -eq "oTvo+S22nsmS2Z/RtcoF8Hfh+jzMe0RkiafpoDpnoZTjPYZu6V+A4aEn032yCr4f"  )
        Write-Host "Computed MAC value match RFC6030 sample:      "  ( ([Convert]::ToBase64String($mac)) -eq "LP6xMvjtypbfT9PdkJhBZ+D6O4w="  )
    }
    Write-Host "-----------------"
}

####### Output for Token Initialisation
$SeedB32 = ConvertTo-Base32    $Seed
$SeedUri = "otpauth://hotp/GRHOTP:$($Username)?secret=$($SeedB32)&counter=0&digits=$($OTPLength)&issuer=GResearch"

####### QRCode generation
if($ShowInitialisationUri) { 
    Write-Host " Seed URI:" $SeedUri
}

if($ShowSeedAsHex) {
    Write-Host " Seed Hex:" (ConvertTo-HexString $Seed)
}

if($ShowSeedAsBase32) {
    Write-Host " Seed Base32:" $SeedB32
}

if($ShowSeedAsPlainText) {
    Write-Host " Seed PlainText:" ([Text.Encoding]::UTF8.GetString($Seed) )
}

if( -not $DoNotGenerateQRCode ) {
    ####### QRCode generation

    $OutputPNGFileName = $OutputFileName.Replace('.pskc','.png')
    write-host ""
    Write-Host " Writing URI to QRCode file $OutputPNGFileName"
    if (Test-Path $QRGeneratorExe) {
        Start-Process -NoNewWindow -FilePath $QRGeneratorExe -ArgumentList " $OutputPNGFileName $OTPURI "
    }

}
