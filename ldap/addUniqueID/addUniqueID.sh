#!/bin/bash
rm -f userList fixed.ldf
function askYesOrNo {
	REPLY=""
	while [ -z "$REPLY" ] ; do
		read -ep "$1 $YES_NO_PROMPT" REPLY
		REPLY=$(echo ${REPLY}|tr [:lower:] [:upper:])
		case $REPLY in
			$YES_CAPS ) printf '\n'; return 0 ;;
			$NO_CAPS ) printf '\n'; return 1 ;;
			* ) REPLY=""
		esac
	done
}
YES_STRING=$"y"
NO_STRING=$"n"
YES_NO_PROMPT=$"[y/n]: "
YES_CAPS=$(echo ${YES_STRING}|tr [:lower:] [:upper:])
NO_CAPS=$(echo ${NO_STRING}|tr [:lower:] [:upper:])

read -p "IP address of LDAP server: " ip
netcat -z -w 5 $ip 389;
if [ $? -ne 1 ]; then
	read -p "FDN of admin user (ex: cn=admin,o=novell): " admin
	read -sp "Password: " pass
	ldapsearch -x -h $ip -D $admin -w $pass '(&(objectclass=user)(!(uniqueID=*)))' cn > userList
	if [ $? -eq 0 ]; then
			touch fixed.ldf
			cat userList | while read myline
			do
			if [ -z "$myline" ]
				then
					if [ -n "$dn" ] && [ -n "$cn" ]
						then
							echo "dn:" $dn >> fixed.ldf
							echo "changetype: modify" >> fixed.ldf
							echo "add: uniqueID" >> fixed.ldf
							echo "uniqueID:" $cn >> fixed.ldf
							echo "" >> fixed.ldf
							dn=''
							cn=''
					fi
				else
					attr=$(echo $myline | cut -d ':' -f 1)
					var=$(echo $myline | cut -d ':' -f 2)
					if [ "$attr" = "dn" ]; then dn=$var
						elif [ "$attr" = "cn" ]; then cn=$var
					fi
			fi
			done
			echo -e "\nModified LDIF file: " ${PWD}"/fixed.ldf\n"
			if askYesOrNo $"Do you want to import the LDIF file? "; then
				ldapmodify -x -h $ip -D $admin -w $pass -f fixed.ldf
			fi
		else echo "Problem with login."
		fi
	else echo "Connection to LDAP server failed."
fi
	# fi
exit 0