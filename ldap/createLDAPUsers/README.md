# Create LDAP Users
https://www.netiq.com/communities/cool-solutions/cool_tools/create-ldap-users/

This is a bash script to bulk create LDAP users and add them to a new group. It has been verified via LDAP with eDirectory, but is only intended for testing and troubleshooting purposes. Sometimes you just need a ton of users and would rather not go through the trouble of adding them all manually.

Description:

- Connects to an LDAP server via :389 with specified credentials
- Creates #ofUsers in a base container: (user1, user2, etc.)
- Prompts if users should be added to a group
- Generates two ldifs: add, modify (if group is requested)
- Uses ldapadd command for creating users
- Uses ldapmodify command for modifying users (group)
- For group: adds user to group member with equivalentToMe, adds to user’s groupMembership attribute.
