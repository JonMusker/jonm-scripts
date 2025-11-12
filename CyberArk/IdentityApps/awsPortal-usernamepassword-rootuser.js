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
loginData.submitPattern = "#signin_button";
loginData.formPattern = "form#signin_form";

loginData.order=[["click","button#root_account_signin"],["sleep","100"],["fill", "username"],["click","#next_button"],["fill", "password"],["click","#signin_button"],["sleep","100"],["click","[type='radio'][value='SWHW']"],["click","[data-testid='mfa-continue-button']"],["submit"]];
