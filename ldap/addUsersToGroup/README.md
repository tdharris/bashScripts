# Add Users to Group
https://www.netiq.com/communities/cool-solutions/cool_tools/adduserstogroup-sh/

Description:
Reads in a file containg a list of users (FDN on each line) and adds them to the membership of the defined group and adds that group to the user by generating an LDIF that can then be applied by using the ldapmodify command.

To import the generated LDIF into the directory, see below:
```ldapmodify -h host -p port -D "cn=admin,o=novell" -W -f LDIFfile```

Requirements:
- userlist must be a filename containing an FDN to a user on each newline. For example: `cn=user1,o=users,o=novell`
- a valid group FDN
