nts-directoryMigration.sh
=========================

NTS Directory Services Migration Utility 
Created to help facilitate migrations from AD to eDirectory, eDirectory to AD.
Queries LDAP server, updates necessary attributes for ALL Filr MySQL users.

-This is based on CN, the user's name. Finds all users at specified base search and below.
If LDAP returns a user that is found in MySQL based on their CN/username, it will be updated.

by Tyler Harris and Shane Nielson
