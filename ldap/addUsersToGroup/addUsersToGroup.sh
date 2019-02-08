#!/bin/bash
#################################################################
#
# addGroupMembership.sh
# created by Tyler Harris and Mukesh Jethwani
#
#################################################################
# 
# Description:
# Reads in a file containg a list of users (FDN on each line)
# and adds them to the membership of the defined group and 
# adds that group to the user by generating an LDIF that can
# then be applied by using the ldapmodify command.
#
# To import the generated LDIF into the directory, see below: 
# ldapmodify -h host -p port -D "cn=admin,o=novell" -W -f LDIFfile
#
# Requirements:
# * userlist must be a filename containing an FDN to a user on
# each newline. For example: cn=user1,o=users,o=novell
# * a valid group FDN
#
##################################################################

userlist="exampleUserList.txt"
group="cn=group1,ou=groups,o=novell"
ldif="addGroupMembership.ldif"

# Please do not change below #
rm "$ldif" 2>/dev/null
touch "$ldif"

while read line
do

[ -z "$line" ] && continue
    
echo "dn: $line" >> "$ldif"
echo "changetype: modify" >> "$ldif"
echo "add: securityEquals" >> "$ldif"
echo "securityEquals: $line" >> "$ldif"
echo "-" >> "$ldif"

echo "add: groupMembership" >> "$ldif"
echo -e "groupMembership: $group\n" >> "$ldif"
echo "dn: $group" >> "$ldif"
echo "changetype: modify" >> "$ldif"
echo "add: member" >> "$ldif"
echo "member: $line" >> "$ldif"
echo "-" >> "$ldif"
echo "add: equivalentToMe" >> "$ldif"
echo -e "equivalentToMe: $line\n" >> "$ldif"

done < "$userlist"
