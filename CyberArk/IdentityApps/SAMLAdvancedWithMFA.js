/* 
 * This script configure the attributes for generating the SAML sign in response.
 *
 * Parameters passed into this script are:
 *   Application - 
 *      The application object from the cloud storage.
 *      Use the Get method to get a property from the storage. 
 *      For example, var url = Application.Get('Url');
 *   LoginUser
 *      The user object.
 *
 *   Availabe methods:     
 *     
 *      Get(string Attribute) 
 *         Gets the user's attribute from the directory service.
 *         For example, LoginUser.Get('mail');
 *
 *  Functions available to this script:
 *   setAttribute('Name', 'Value');
 *      Set available attributes with name 'Name' and value 'Value'.
 *      For example, setAttribute('TargetAudience', Application.Get("TargetAudience"));
 *
 *   Availabe attributes:
 * 
 *      CreatedTime
 *         The start time in UTC format of the token. Default set as current time.
 *         For example:
 *           var now = new Date();
 *           setAttribute('CreatedTime', now);
 *            
 *      ExpiryTime
 *         The expiry time in UTC format of the token. Default set as current time add 200 minutes.
 *         For example:
 *           var expiryTime = new Date();
 *           expiryTime.setUTCMinutes(expiryTime.getUTCMinutes() + 200);
 *           setAttribute('ExpiryTime', expiryTime);
 * 
 *      ObjectGuid
 *         Determine the immutableID and bearerid. Default set as base64 encoded ObjectId or customized SourceAnchor.
 *         For example, setAttribute('ObjectGuid', LoginUser.Base64EncodedGuid);          
 *
 *      TargetAudience
 *         Set the SAML target audience. 
 *         For example, setAttribute('TargetAudience', Application.Get('TargetAudience'));
 *
 *      TokenAudience
 *         Set the SAML token audience. 
 * 
 *      IssuerName
 *         String value of the Issuer name. By default, this is the domain match from among the issuers.
 *
 *      RawToken
 *         String value of unsigned SAML xml token, use for generating the signed xml assertion.
 *         if user set the raw token, CreatedTime, ExpiryTime, ObjectGuid, TargetAudience, TokenAudience and IssuerName will be ignored.   
 * 
 *      AssertionId
 *         The assertion id of the response. Default set as the token reference GUID.
 * 
 *      TargetRedirectionUrl
 *         The URL redirection of the response.
 *         For example, setAttribute('TargetRedirectionUrl', Application.Get("TargetRedirectionUrl"));
 *
 *      ResponseContext
 *         Determine the context of SAML sign in response 
 *
 */

var now = new Date();
setAttribute('CreatedTime', now);

var expiryTime = now;
expiryTime.setUTCMinutes(now.getUTCMinutes() + 200);
setAttribute('ExpiryTime', expiryTime);

setAttribute('TargetAudience', Application.Get("TargetAudience"));
setAttribute('TargetRedirectionUrl', Application.Get("TargetRedirectionUrl"));
setCustomAttribute('authnmethodsreferences','http://schemas.microsoft.com/claims','http://schemas.microsoft.com/claims/multipleauthn'); //tells Azure that MFA has been done for this user

//ObjectGuid is decided by ObjectId or customized SourceAnchor by default.
//If user set ObjectGuid by token script, default value will be replaced.
//setAttribute('ObjectGuid', LoginUser.Base64EncodedGuid);