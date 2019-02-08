# Add Missing UniqueID Attribute
https://www.netiq.com/communities/cool-solutions/cool_tools/add-missing-uniqueid-attribute/

This tool finds users that do not have a uniqueID attribute and adds it. User objects created with older versions of eDirectory have this issue. 
Updating eDirectory does not add this attribute for old user objects.

This tool finds all users throughout the entire tree, creates an LDIF file that can be imported to resolve this issue.
However, it also prompts for automatic import, creating the new attribute for the affected users.

