var isOnePageLogin = true;
var targetURL = "https://accounts.google.com/v3/signin/identifier?hl=en&continue=https%3A%2F%2Fconsole.cloud.google.com&flowName=GlifWebSignIn&flowEntry=Identifier";

if (WebBrowserType == "IE") {
  var version = /MSIE (\d+)\.\d+/.exec(RequesterUserAgent);
    
  if (version && version[1] <= 9) {
      isOnePageLogin = false;
  }
}

//Original target URL
//loginData.applicationUrl = "https://accounts.google.com/signin/v2/identifier?hl=en&continue=https%3A%2F%2Fwww.google.com&flowName=GlifWebSignIn&flowEntry=Identifier";

//Modified (JM 17/6/25). from /signin/v2/identifier to /v3/signin/identifier. Also changed ?continue=https%3A%2F%2Fwww.google.com to continue=https%3A%2F%2Fconsole.cloud.google.com

//Modified logic to support MFA using TOTP.
//Note that if Passcode + Passwordless is enabled on the account, then MFA and password prompts will not be shown, so this script will fail.

if (isOnePageLogin) {
  loginData.applicationUrl = targetURL;
  loginData.addField("username", "input#identifierId,div#profileIdentifier", LoginUsername);
  loginData.addField("password", "input[name='Passwd']", LoginPassword);
    //can't quite get this next item exact; "click", "div#totpNext" doesn't seem to be reliable
  loginData.order = [["fill", "username"], ["click", "div#identifierNext,div#profileIdentifier"], ["fill", "password"], ["waitForNewPage"], ["click", "div#passwordNext"], ["waitForNewPage"], ["click", "input[type=checkbox]"],["click","div#totpNext"], ["sleep", "100"], ["click", "div#totpNext"], ["submit"]];
} else {
  targetURL = "https://accounts.google.com/ServiceLogin?sacu=1&hl=en&continue=http://console.cloud.google.com/";
  loginData.applicationUrl = targetURL;
  loginData.addField("username", "input#Email", LoginUsername);
  loginData.addField("password", "input#Passwd", LoginPassword);
  loginData.submitPattern = "input#signIn";
  loginData.formPattern = "form#gaia_loginform";
  loginData.order = [["fill", "username"], ["click", "input#Passwd,input#next"], ["waitForNewPage"], ["fill", "password"], ["submit"]];
}
