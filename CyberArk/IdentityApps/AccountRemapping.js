//configure this value according to the unique DNS name that will be use for federation with this Azure instance
var targetDomain='cctest1.muskernet.com';

var targetUsername = '****not valid user****';
var originalUsername='' +  LoginUser.Get('UserPrincipalName').toLowerCase();

trace('UserPrincipalName:'+originalUsername);
if( originalUsername.indexOf('@') > 3) {
    var originalDomain = originalUsername.split('@')[1];
    var userNoDomain = originalUsername.split('@')[0];
    
    trace ('Changing user domain from @'+originalDomain+' to @'+targetDomain );
    trace ('User: '+originalUsername );
    
    if(targetDomain.toLowerCase() == originalDomain.toLowerCase()) {
        targetUsername = originalUsername;
        trace( 'Domain is already correct - no change required');
    } else {
        targetUsername  = userNoDomain + '@' + targetDomain;
    }
}

//Overrides for special cases
switch( originalUsername.toLowerCase() ){
    case 'jon.musker@cyberark.cloud.10061':
        targetUsername = 'JMCyberArkCloud@cctest1.muskernet.com';
        trace ('Override!');
        break;
    case 'jon@muskernet.onmicrosoft.com' :
        targetUsername = 'jonmusker@cctest1.muskernet.com';
        trace ('Override!');
        break;
}

trace( 'Final username: '+targetUsername);
LoginUser.Username = targetUsername;