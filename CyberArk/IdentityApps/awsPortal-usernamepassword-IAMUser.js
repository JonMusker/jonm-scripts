//     Refer to https://community.cyberark.com/s/article/CyberArk-Identity-How-to-use-the-Order-box-for-custom-Browser-Extension-apps
//     When trying to find field references, use chrome Dev Tools and in the console test your reference with the document.querySelectorAll() function, eg
//                    document.querySelectorAll("[data-testid='yes-button']")
//                    document.querySelectorAll("input#password-input")

var AWSAccountId='345594583017'; 

//Currently (30/6/2025) here does not appear to be any method for retrieving additional properties from a Vaulted account, or to retrieve Additional Attributes from the application
//Also the TOTP code cannot be retrieved from a vaulted account, must be entered manually at the time the Account Mapping is configured

//var AWSAccountId = LoginUser.Get("AWSAccountID");    //this doesn't work
//var AWSAccountId = Application.Get("AWSAccountId");  //this doesn't work

loginData.applicationUrl = "https://"+AWSAccountId+".signin.aws.amazon.com/console";
loginData.addField("username", "input#username", LoginUsername);
loginData.addField("password", "input#password", LoginPassword);
//loginData.addField("corpId","input#account",AWSAccountId);   
	//not needed if we specifiy the account ID in the URL
	//for some reason only corpId, username, or password are valid fields. Don't know what happens if you have another field that needs data. See https://community.cyberark.com/s/article/CyberArk-Identity-How-to-use-the-Order-box-for-custom-Browser-Extension-apps
loginData.submitPattern = "#signin_button";
loginData.formPattern = "form#signin_form";

loginData.order=[["fill", "username"],["fill", "password"],["click","#signin_button"],["sleep"],["click","[type='radio'][value='SWHW']"],["click","[data-testid='mfa-continue-button']"],["sleep"],["submit"]];
