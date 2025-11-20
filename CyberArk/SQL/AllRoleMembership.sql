/*
QUERY: To expand the Role Membership table to show all members of all roles.
	This includes role members that are Users, or Groups (external), or other Roles
    
    It does NOT include AD Groups
    It does not do nested membership, but the information is present in the table to allow for further analysis
    It does not do Dynamic role membership

	Author: Jon Musker, November 2025
*/

SELECT 
	Role,
	RoleID,
	MemberType,
	MemberName,
	MemberID,
    Status,
    Category
FROM
(
    SELECT 
	    Role.Name Role,
	    UsersInRoles.HostRoleID RoleID,
	    'User' MemberType,
	    UsersInRoles.Username MemberName,
	    UsersInRoles.userID MemberID,
    	UsersInRoles.UserStatus Status,
    	UsersInRoles.UsrType Category
    FROM
    ( 
        SELECT 
            u.UserName Username,
            u.Email UserEmail,
            u.Status UserStatus,
        	u.UserType UsrType,
            u.ID userID,
            REPLACE(rm.ID, (u.ID || '_'), '') HostRoleID
	    FROM 
    	    User u
	    INNER JOIN 
    	    RoleMember rm ON rm.ID like (u.ID || '_%') 
    ) UsersInRoles  
	    inner join Role on UsersInRoles.HostRoleID = Role.ID
    UNION
    SELECT
	    Role.Name Role,
	    RolesInRoles.HostRoleID RoleID,
	    'Role' MemberType,
	    RolesInRoles.MemberRoleName MemberName,
	    RolesInRoles.MemberRoleID MemberID,
    	'' Status,
    	'' Category
    FROM
    (
        SELECT 
            r.Name MemberRoleName,
            r.ID MemberRoleID,
            REPLACE(rm.ID, (r.ID || '_'), '') HostRoleID
	    FROM 
    	    Role r
	    INNER JOIN 
    	    RoleMember rm ON rm.ID like (r.ID || '_%') 
    ) RolesInRoles 
	    inner join Role on RolesInRoles.HostRoleID = Role.ID
    UNION
    SELECT
	    Role.Name Role,
	    GroupsInRoles.HostRoleID RoleID,
	    'ExternalGroup' MemberType,
	    GroupsInRoles.MemberRoleName MemberName,
	    GroupsInRoles.MemberRoleID MemberID,
    	'' Status,
    	'' Category
    FROM
    (
        SELECT 
	        dsg.DisplayName MemberRoleName,
    	    dsg.InternalName MemberRoleID,
            rm.ID rmID,
    	    REPLACE(rm.ID, (dsg.InternalName || '_'), '') HostRoleID
	    FROM 
    	    DSGroups dsg
	    INNER JOIN 
    	    RoleMember rm ON rm.ID like (dsg.InternalName || '_%') 
    ) GroupsInRoles 
	    inner join Role on GroupsInRoles.HostRoleID = Role.ID
)
ORDER BY Role,MemberName