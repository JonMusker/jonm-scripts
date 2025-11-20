[CmdletBinding()]
Param(
	[parameter(Mandatory=$true)][xml]$xml1,
	[parameter(Mandatory=$true)][xml]$xml2
)

function CreateRequestObject(){
	$RequestObject = ""|select LifetimeCreated,LifetimeExpires,CalculatedLifetimeSeconds,TokenType,RequestType,KeyType,RequestSchema,AppliesToSchema,EndpointReferenceSchema,EndpointReferenceAddress,AssertionSchema,AssertionIssueInstant,AssertionIssuer,AssertionID,AssertionMajorVersion,AssertionMinorVersion,ConditionsNotBefore,ConditionsNotOnOrAfter,Audience,Attributes,AuthenticationMethod,AuthenticationInstant,AuthnSubjectName,AuthnSubjectNameFormat,AuthnSubjectConfirmationMethod,SignatureSchema,CanonicalizationMethodAlgorithm,SignatureMethodAlgorithm,DigestMethodAlgorithm,Transforms
	$RequestObject.Attributes=@()
	$RequestObject.Transforms=@()
	return $RequestObject
}

function CreateAttribute([string]$Name,[string]$Namespace,[string]$Value){
	$item=""|select Name,Namespace,Value
	$Item.Name=$Name
	$Item.Namespace=$Namespace
	$Item.Value=$Value
	return $Item
}

function PopulateRequestObjectFromXml( [xml]$xml){
	$req = CreateRequestObject
	$req.LifetimeCreated = $xml.xml.RequestSecurityTokenResponse.Lifetime.Created."#text"
	$req.LifetimeExpires = $xml.xml.RequestSecurityTokenResponse.Lifetime.Expires."#text"
	$req.CalculatedLifetimeSeconds = ([datetime]::Parse($req.LifetimeExpires) - [datetime]::Parse($req.LifetimeCreated)).TotalSeconds
	$req.TokenType = $xml.xml.RequestSecurityTokenResponse.TokenType
	$req.RequestType = $xml.xml.RequestSecurityTokenResponse.RequestType
	$req.KeyType = $xml.xml.RequestSecurityTokenResponse.KeyType
	$req.RequestSchema = $xml.xml.RequestSecurityTokenResponse.t
	$req.AppliesToSchema = $xml.xml.RequestSecurityTokenResponse.AppliesTo.wsp
	$req.EndpointReferenceSchema = $xml.xml.RequestSecurityTokenResponse.AppliesTo.EndpointReference.wsa
	$req.EndpointReferenceAddress = $xml.xml.RequestSecurityTokenResponse.AppliesTo.EndpointReference.Address
	$req.AssertionSchema = $xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.saml
	$req.AssertionIssueInstant = $xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.IssueInstant
	$req.AssertionIssuer = $xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.Issuer
	$req.AssertionID = $xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.AssertionID
	$req.AssertionMajorVersion = $xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.MajorVersion
	$req.AssertionMinorVersion = $xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.MinorVersion
	$req.ConditionsNotBefore = $xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.Conditions.NotBefore
	$req.ConditionsNotOnOrAfter = $xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.Conditions.NotOnOrAfter
	$req.Audience = $xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.Conditions.AudienceRestrictionCondition.Audience
	$xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.AttributeStatement.Attribute | foreach {
		$req.Attributes += CreateAttribute -Name $_.AttributeName -Namespace $_.AttributeNamespace -Value $_.AttributeValue
	}
	$req.AuthenticationMethod = $xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.AuthenticationStatement.AuthenticationMethod
	$req.AuthenticationInstant = $xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.AuthenticationStatement.AuthenticationInstant
	$req.AuthnSubjectName = $xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.AuthenticationStatement.Subject.NameIdentifier."#text"
	$req.AuthnSubjectNameFormat = $xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.AuthenticationStatement.Subject.NameIdentifier.Format
	$req.AuthnSubjectConfirmationMethod = $xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.AuthenticationStatement.Subject.SubjectConfirmation.ConfirmationMethod
	$req.SignatureSchema = $xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.Signature.xmlns
	$req.CanonicalizationMethodAlgorithm = $xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.Signature.SignedInfo.CanonicalizationMethod.Algorithm
	$req.SignatureMethodAlgorithm = $xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.Signature.SignedInfo.SignatureMethod.Algorithm
	$req.DigestMethodAlgorithm = $xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.Signature.SignedInfo.Reference.DigestMethod.Algorithm
	$xml.xml.RequestSecurityTokenResponse.RequestedSecurityToken.Assertion.Signature.SignedInfo.Reference.Transforms.Transform | foreach {
		$req.Transforms += $_.Algorithm
	}
	$req.Attributes = $req.Attributes | Sort -Property Name
	$req.Transforms = $req.Transforms | Sort
	return $req
}

function CompareRequestObjects($req1, $req2){
	$res = @()
	
	$req1 | Get-Member -MemberType NoteProperty | foreach {
		Write-Verbose "AttributeName: $($_.Name)"
		if($_.Name -eq "Attributes"){
			$x=1
		} elseif ($_.Name -eq "Transforms"){
			$x=2
		} else {
			$val1 = $req1."$($_.Name)"
			$val2 = $req2."$($_.Name)"
			if(!($val1 -eq $val2))  {
				$res += "$($_.Name): $val1 notmatch $val2"
			}
		}
	}
	
	return $res
}

$Results = "" | select SAMLRequest1,SAMLRequest2,Differences

$Results.SAMLRequest1 = PopulateRequestObjectFromXml $xml1

$Results.SAMLRequest2 = PopulateRequestObjectFromXml $xml2

$Results.Differences = CompareRequestObjects $Results.SAMLRequest1 $Results.SAMLRequest2

return $Results
