#!/bin/bash
#################################################################
#
# createLDAPUsers.sh
# created by Tyler Harris
#
#################################################################
#
# Description:
# - Connects to an LDAP server via :389 with specified credentials
# - Creates #ofUsers in a base container: (user1, user2, etc.)
# - Prompts if users should be added to a group
# - Generates two ldifs: add, modify (if group is requested)
# - Uses ldapadd command for creating users
# - Uses ldapmodify command for modifying users (group)
# - For group: adds user to group member with equivalentToMe, 
# 	adds to user's groupMembership attribute.
#
##################################################################

function askYesOrNo {
	REPLY=""
	while [ -z "$REPLY" ] ; do
		read -ep "$1 $YES_NO_PROMPT" REPLY
		REPLY=$(echo ${REPLY}|tr [:lower:] [:upper:])
		case $REPLY in
			$YES_CAPS ) return 0 ;;
			$NO_CAPS ) return 1 ;;
			$CANCEL_CAPS) exit;;
			* ) REPLY=""
		esac
	done
}
YES_STRING=$"y"
NO_STRING=$"n"
CANCEL_STRING=$"c"
YES_NO_PROMPT=$"[y/n/c]: "
YES_CAPS=$(echo ${YES_STRING}|tr [:lower:] [:upper:])
NO_CAPS=$(echo ${NO_STRING}|tr [:lower:] [:upper:])
CANCEL_CAPS=$(echo ${CANCEL_STRING}|tr [:lower:] [:upper:])

clear;

echo -e "###################################################################
#
# createLDAPUsers.sh
# created by Tyler Harris
#
###################################################################
#
# Description:
# - Connects to an LDAP server via :389 with specified credentials
# - Creates #ofUsers in a base container: (user1, user2, etc.)
# - Prompts if users should be added to a group
# - Generates two ldifs: add, modify (if group is requested)
# - Uses ldapadd command for creating users
# - Uses ldapmodify command for modifying users (group)
# - For group: adds user to group member with equivalentToMe, 
# 	adds to user's groupMembership attribute.
#
###################################################################\n"

read -p "Address of LDAP server: " serverAddress
netcat -z -w 5 $serverAddress 389;
if [ $? -ne 1 ]; then
	read -p "FDN of admin user (i.e. cn=admin,o=novell): " admin
	read -sp "Password: " pass
	echo -ne "\nVerifying credentials... "
	ldapsearch -x -h $serverAddress -D $admin -w $pass $admin 1>/dev/null
	rc=$?; if [[ $rc != 0 ]]; then exit $rc; else echo -ne "success\n\n"; fi

	# LDIF files
	addldif="add.ldif"
	modifyldif="modify.ldif"
	echo > "$addldif"
	echo > "$modifyldif"

	# Prompt for variables
	read -p "Where to add new users (fdn of base container)? " base
	read -p "How many users? " numberOfUsers
	
	# Create Group
	addToGroup=false
	if askYesOrNo $"Do you want to add these users to a new group?"; then
		addToGroup=true
		read -p "FDN context of new group: " groupFDN
		echo -e "dn: $groupFDN\nchangetype: add\nobjectClass: group\n" >> "$addldif"
	fi

	# Create Users
	echo -e "\nGenerating $addldif and $modifyldif..."
	for (( i=1; i<=$numberOfUsers; i++ )); do

		# Create user
		username="user$i"
		userFDN="cn=$username,$base"
		echo -e "dn: $userFDN\nchangetype: add\nobjectClass: user\nuniqueID: $username\nsn: Users\n" >> "$addldif"

		if($addToGroup); then
			# Modify for group membership:
			# add to group
			echo -e "dn: $groupFDN\nchangetype: modify\nadd: equivalentToMe\nequivalentToMe: $userFDN\n-\nadd: member\nmember: $userFDN\n" >> "$modifyldif" 
			# add to user
			echo -e "dn: $userFDN\nchangetype: modify\nadd: groupMembership\ngroupMembership: $groupFDN\n" >> "$modifyldif"
			# eDirectory automatically adds securityEquals in this case
		fi

	done
	
	if askYesOrNo $"Would you like to view $addldif? "; then
		less "$addldif"
	fi
	if askYesOrNo $"Do you want to add these $numberOfUsers users to $base using $addldif? "; then
		ldapadd -x -h $serverAddress -D $admin -w $pass -f "$addldif"
		rc=$?; if [[ $rc != 0 ]]; then exit $rc; else echo -e "Successfully created $numberOfUsers at $base using $addldif.\n"; fi
	fi

	if($addToGroup); then
		if askYesOrNo $"Would you like to view $modifyldif? "; then
			less "$modifyldif"
		fi
		if askYesOrNo $"Do you want to add these $numberOfUsers users to $groupFDN using $modifyldif? "; then
			ldapmodify -x -h $serverAddress -D $admin -w $pass -f "$modifyldif"
			rc=$?; if [[ $rc != 0 ]]; then exit $rc; else echo -e "Successfully added $numberOfUsers to $groupFDN using $modifyldif.\n"; fi
		fi
	fi

fi

exit 0