#!/bin/bash
#########################################################################################################
#																								
#	NTS Directory Services Migration Utility 
#	Created to help facilitate migrations from AD to eDirectory, eDirectory to AD.
#	Queries LDAP server, updates necessary attributes for ALL Filr MySQL users.
#   	-This is based on CN, the user's name. Finds all users at specified base search and below.
# 		If LDAP returns a user that is found in MySQL based on their CN/username, it will be updated.
#
#	by Tyler Harris and Shane Nielson
#
#########################################################################################################
currentTime=`date -d "\`date\`" +%s`

function defineVariables {
	# Variable definitions / Log & tmp files
	workingDirectory="/var/log/novell/nts-$PRODUCT"								# All logs/tmp files will be created here.
	log="$workingDirectory/nts-$PRODUCT.log"									# MASTER log - Troubleshooting starts here.
	bak_Principals="$workingDirectory/bak/bak-SS_Principals-$currentTime.sql"

	ldapOutput="$workingDirectory/getUsers/ldap-response" 						# Response from LDAP server
	delineatedOutput="$workingDirectory/getUsers/ldap-delineated" 				# LDAP response parsed/delineated for script usage
	db_qUsers="$workingDirectory/getUsers/db-qUsers.sql";						# Query to retrieve users from Filr MySQL
	db_getFilrUsers="$workingDirectory/getUsers/db-FilrUsers";					# Output from db_qUsers retrieval. Lists all users.
	filterldapusers="$workingDirectory/getUsers/ldap-filtered";					# Filters dileaneatedOutput, only valid Filr users in MySQL db
	buildQuery="$workingDirectory/updateUsers/db-updateUsers.sql";				# Query to update users (must have all required attributes, else not updated)
	nts_filr_mysql="$workingDirectory/updateUsers/nts-$PRODUCT-mysql.log";		# Output from Update Users MySQL query

	# Create tmp directory/files
	mkdir -p $workingDirectory 2>/dev/null
	mkdir -p $workingDirectory/bak 2>/dev/null

	# Log directories based on the two major functions/tasks
	mkdir -p $workingDirectory/getUsers 2>/dev/null
	mkdir -p $workingDirectory/updateUsers 2>/dev/null

	# Verify cleanup:
	rm $log

	touch $log
}

PRODUCT=''
DATABASE=''

#Make sure user is root
if [ "$(id -u)" != "0" ];then
	read -p "Please login as root to run this script."; 
	exit 1;
fi

# Functions for directory change or migration
	function info {
		# echo -e "The following is in development. This is NOT SUPPORTED.\nScript for Directory change migration (AD/eDir) - $PRODUCT\n"
		echo -e "NTS Directory Services Migration Utility (beta) - $PRODUCT\nCreated to help facilitate migrations from AD to eDirectory, eDirectory to AD.\n"
	}

	function backupInfo {
		echo -e "backup: $bak_Principals\n"
	}

	function checkError {
		if [ $? -ne 0 ]
			then {
				echo -e "\n\nAn error has occurred. See $log for details.\nAborting Script.\n"; 
				less $log
				exit 1
			}
		fi
	}

	# Returns a list of valid users
	function getAllUsers {
		# Get users from ldapsearch, and organize results in output file delineated by '|'
		# For example: cn|fdn|objectGUID/GUID, etc, etc. (getldapusers-list)

		# Ask user for ldap information
		function getldapinfo {
			####Defaults for testing...
				# Mukesh's AD
					# ldapAddress='ldaps://151.155.134.61'
					# ldapAdmin='cn=administrator,cn=users,dc=lab,dc=novell,dc=com'
					# baseSearch='cn=users,dc=lab,dc=novell,dc=com'
					# ldapAdminPW="novell"
				# Shan'e eDir
					# ldapAddress='ldaps://snielson2.lab.novell.com'
					# ldapAdmin='cn=admin,o=novell'
					# baseSearch='o=novell'
					# ldapAdminPW="novell"

			read -p "LDAP server address (ie. ldap://151.155.134.61): " ldapAddress
			echo $ldapAddress | grep -ie 'ldap://' -ie 'ldaps://' &>/dev/null
			if [ $? -ne 0 ]; then
				echo -e "\nLDAP URL invalid. Must contain ldap:// or ldaps://\n"; exit 1
			fi
				server=`echo $ldapAddress | cut -d '/' -f3- | awk -F ':' '{print $1}'`
				port=`echo $ldapAddress | cut -d '/' -f3- | awk -F ':' '{print $2}'`
				if [ -z "$port" ]; then
					port='389';
				fi
				echo $ldapAddress | grep -ie 'ldaps://' &>/dev/null
				if [ $? -eq 0 ]; then
					port='636'
				fi
				echo | telnet $server $port 2>/dev/null | grep -i "connected" 2>/dev/null
				if [ $? -ne 0 ]; then
					echo -e "\nFailed to verify LDAP URL: " $server $port "("$ldapAddress")\n"
					exit 1
				fi

			read -p "Admin FDN (ie. cn=admin,o=novell): " ldapAdmin
			read -p "Admin password: " -s ldapAdminPW 
			echo
			read -p "Base search (ie. ou=users,o=novell): " baseSearch

			#Default baseFilter
			defaultBaseFilter="(|(objectClass=Person)(objectClass=orgPerson)(objectClass=inetOrgPerson))"
			if askYesOrNo $"Use default 'Users' filter for ldapsearch? "; then
				baseFilter="$defaultBaseFilter"
				else
					read -p "Filter for Base search [Press Enter for default 'Users']: " baseFilter
					baseFilter="${baseFilter:-$defaultBaseFilter}"
				
			fi
			
			if [[ -z "$ldapAddress" || -z "$ldapAdmin" || -z "$ldapAdminPW" || -z "$baseSearch" ]]; then
				echo -e "\nOne or more of the required attributes are missing from user input."; exit 1
			fi

			echo -e "\nLDAP server information received [$DIRECTORY]: \n\tldapAddress: "$ldapAddress"\n\tldapAdmin: "$ldapAdmin"\n\tldapBaseSearch: "$baseSearch"\n\tldapFilter: "$baseFilter  >>$log
		}

		function getldapusers {

			# Start clean no-matter-what!
			echo >$delineatedOutput

			if [ $DIRECTORY = "AD" ] 
				then ldapAttributes="sAMAccountName objectGUID"; echo -e "\nMigrate Directory from Active Directory (AD) to eDirectory." >>$log;
			elif [ $DIRECTORY = "EDIR" ] 
				then ldapAttributes="uid GUID";  echo -e "\nMigrate Directory from eDirectory to Active Directory (AD)." >>$log;
			fi

			# Add TLS_REQCERT allow to /etc/openldap/ldap.conf for SSL/636 ldapsearch
			echo "TLS_REQCERT allow" > /etc/openldap/ldap.conf 2>/dev/null

			#LDAP search using variables from getldapinfo - Outputs to $ldapOutput
			ldapsearch -x -H $ldapAddress -D $ldapAdmin -w $ldapAdminPW -b $baseSearch $baseFilter $ldapAttributes > $ldapOutput  2>>$log
			checkError
			
			# Remove TLS_REQCERT allow from openldap (replace with default)
			cp /etc/openldap/ldap.conf.default /etc/openldap/ldap.conf 2>/dev/null

			echo -e "\nReceived ldap response: "$ldapOutput >>$log
			echo -e "\nCreating delineated output..." >>$log
			# From the above file-output thing, filter through line by line and get variables to make formatted file
			# filterldapusers_cn=`cat $somefilenameyouwant`

			 grep -v '^#' $ldapOutput | while IFS= read -r line
				do
					if [[ "$line" != "" ]]
						then
							attribute=`echo $line | cut -d ':' -f1`
					 		if [ "$attribute" == "dn" ]
					 			then foreignName=`echo $line | cut -d ':' -f2- | sed -e 's/^[[:space:]]*//'`
					 		fi

								if [ $DIRECTORY = "AD" ]; then
							 		if [ "$attribute" == "objectGUID" ]
							 			then ldapGUID=`echo $line | cut -d ':' -f3- | sed -e 's/^[[:space:]]*//'`
							 		fi

							 		if [ "$attribute" == "sAMAccountName" ]
							 			then userID=`echo $line | cut -d ':' -f2- | sed -e 's/^[[:space:]]*//'`
							 		fi
							 	fi

							 	if [ $DIRECTORY = "EDIR" ]; then
									if [ "$attribute" == "GUID" ]
										then ldapGUID=`echo $line | cut -d ':' -f3- | sed -e 's/^[[:space:]]*//'`
									fi

									if [ "$attribute" == "uid" ]
										then userID=`echo $line | cut -d ':' -f2- | sed -e 's/^[[:space:]]*//'`
									fi
							 	fi


					 	else
							if [[ -n $foreignName && -n $ldapGUID && -n $userID ]]; then {
								printf $foreignName >> $delineatedOutput; printf '|' >> $delineatedOutput;
								printf $ldapGUID >> $delineatedOutput; printf '|' >> $delineatedOutput;
								printf $userID >> $delineatedOutput;
								echo >> $delineatedOutput
							}
							else echo -e "\tFailure: Insufficient attributes - foreignName: "$foreignName" | ldapGuid: "$ldapGuid" | userID: "$userID >>$log
							fi
					 fi

			 	done
			showDelineatedOutput
		}

		function showDelineatedOutput {
			echo -e "--------------------------------------------- START OF LDAP DELINEATED OUTPUT ---------------------------------------------" >>$log
			cat $delineatedOutput >>$log
			echo -e "--------------------------------------------- END  OF LDAP DELINEATED OUTPUT ---------------------------------------------" >>$log
			echo -e "Done." >>$log
		}

		# Get all users from db (cn)
		function getUsers_buildQuery {
			echo "use $DATABASE; 
			SELECT 
				SS_Principals.name
			FROM SS_Principals
			WHERE SS_Principals.type = 'user'
				AND SS_Principals.creation_principal != 1 
				AND SS_Principals.deleted=0;" >$db_qUsers
			checkError
		}

		function getFilrUsers {
			rcmysql status *>>$log
				if [ $? -ne 0 ]
					then echo "MySQL is not running. Aborting script." >>$log
					echo -e "\n\nMySQL is not running. Aborting script."; exit 1
				fi
			mysql -h 127.0.0.1 -uroot -p$dbpass < $db_qUsers >$db_getFilrUsers
				if [ $? -ne 0 ]
					then echo "Error when connecting to MySQL or when executing SQL Query." >>$log
					echo -e "\n\nError when connecting to MySQL or when executing SQL Query."; exit 1
				fi 
		}

		# Filter users for valid Filr db users only
		function filterldapusers {
			users=`cat $db_getFilrUsers`
			# $db_getFilr Users is our 'pattern' file. Filter out anything else...
			grep -i -F -f $db_getFilrUsers $delineatedOutput 2>/dev/null >$filterldapusers;
		}

		# Execute the following when getAllUsers is called.
		# Expectation: a file containing a list of valid users and pertinent information queried from ldap.
		echo -e "################################\nGet Users from LDAP/Filr\n################################" >>$log
		getldapinfo
		clear;
		echo -e "\nRetrieving LDAP users:"
		echo -ne '  Retrieving LDAP users\t  [ =====                      ] (33%)'
			getldapusers
		echo -ne '\r  Retrieving MySQL users  [ =============              ] (66%)'
			echo -e "\nRetrieving MySQL users..." >>$log
			getUsers_buildQuery
			getFilrUsers
			echo "MySQL users: " $db_getFilrUsers >>$log
			echo -e "done." >>$log
		echo -ne '\r  Filtering valid users   [ =======================    ] (87%)'
			echo -e "\nFiltering for valid Filr users..." >>$log
			filterldapusers
			cat $filterldapusers | cut -d '|' -f3- | column -x >>$log
			echo -e "done." >>$log
		echo -ne '\r  Retrieved users      \t  [ ========================== ]   (100%)'
		echo

	}

	# Update the database entries (migrating from AD to eDir)
	function updateUsers_AE {

		# Build the sql query to update the list of users attributes
		function buildQuery_AE {
			echo -e "\n################################\nBuilding MySQL Query\n################################" >>$log
			echo -e "use $DATABASE;\n" >$buildQuery
			# Each line is a user, build update sql statement per line of $filterldapusers
			echo -e "\nBeginning loop through users..." >>$log
			cat $filterldapusers | while IFS= read -r line
				do
					# Get the following variables from each line:
					#      * foreignName [fdn]
					#      * ldapGuid (db), encoded/parsed (GUID for eDir)
					#      * samAccountName needs to be set to NULL
					#      * objectSid needs to be set to NULL
					# cut -d '|' -f1`

					foreignName=`echo $line | cut -d '|' -f1`
					guid=`echo $line | cut -d '|' -f2`
					ldapGuid=`echo $guid | base64 -d -i | hexdump -ve '1/1 "%02X"' | awk '{print tolower($0)}'`
					name=`echo $line | cut -d '|' -f3`

# Only build the SQL Update statement if the variables are not empty.
if [[ -n $foreignName && -n $guid && -n $ldapGuid && -n $name ]]; then {
# Compose the SQL query
echo -e "UPDATE SS_Principals
SET foreignName = '$foreignName'
, ldapGuid = '$ldapGuid'
, samAccountName = NULL
, objectSid = NULL
WHERE name = '$name';\n" >>$buildQuery
echo -e "Success: User added to SQL query - foreignName: "$foreignName" | GUID(ldap): " $guid " | ldapGuid(db): "$ldapGuid >>$log
}

else {
	echo -e "\tFailure: User not added to SQL query - foreignName: "$foreignName" | GUID(ldap): " $guid " | ldapGuid(db): "$ldapGuid >>$log
}
fi

				done

			echo -e "User loop completed.\nSQL Query constructed: "$buildQuery"\n">>$log
			# echo -e "\n--------------------------------------------- START OF SQL Query ---------------------------------------------" >>$log
			# cat $buildQuery >>$log
			# echo -e "--------------------------------------------- END OF SQL QUERY ---------------------------------------------" >>$log
			# echo -e "\nDone.\n" >>$log
		}

		# Execute the following when updateUsers-AE is called.
		# Expectation: Database is updated.
		echo -e "\nUpdating MySQL:"
		echo -ne '  Building MySQL Query\t  [ ===                        ] (10%)'
			buildQuery_AE
		echo -ne '\r  Updating MySQL          [ ========                   ] (25%)'
			executeQuery
		echo -ne '\r  MySQL updated        \t  [ ========================== ]   (100%)'
		echo
	}

	# Update the database entries (migrating from eDir to AD)
	function updateUsers_EA {

		# Build the sql query to update the list of users attributes
		function buildQuery_EA {
			
			echo -e "\n################################\nBuilding MySQL Query\n################################" >>$log
			echo -e "use $DATABASE;\n" >$buildQuery
			# Each line is a user, build update sql statement per line of $filterldapusers
			echo -e "\nBeginning loop through users..." >>$log
			cat $filterldapusers | while IFS= read -r line
				do
					# Get the following variables from each line:
					#      * foreignName [fdn]
					#      * ldapGuid (db), encoded/parsed (GUID for eDir)
					#      * samAccountName needs to be set to NULL
					#      * objectSid needs to be set to NULL
					# cut -d '|' -f1`

					foreignName=`echo $line | cut -d '|' -f1`
					samAccountName=`echo $line | cut -d '|' -f2`
					guid=`echo $line | cut -d '|' -f2`
					ldapGuid=`echo $guid | base64 -d -i | hexdump -ve '1/1 "%02X"' | awk '{print tolower($0)}'`
					name=`echo $line | cut -d '|' -f3`

# Only build the SQL Update statement if the variables are not empty.
if [[ -n $foreignName && -n $guid && -n $ldapGuid && -n $name ]]; then {
# Compose the SQL query
echo -e "UPDATE SS_Principals
SET foreignName = '$foreignName'
, ldapGuid = '$ldapGuid'
, samAccountName = $samAccountName
, objectSid = NULL
WHERE name = '$name';\n" >>$buildQuery
echo -e "Success: User added to SQL query - foreignName: "$foreignName" | GUID(ldap): "$guid" | ldapGuid(db): "$ldapGuid >>$log
}

else {
	echo -e "\tFailure: User not added to SQL query - foreignName: "$foreignName" | GUID(ldap): "$guid" | ldapGuid(db): "$ldapGuid >>$log
}
fi

				done

			echo -e "User loop completed.\nSQL Query constructed: "$buildQuery"\n">>$log
			# echo -e "\n--------------------------------------------- START OF SQL Query ---------------------------------------------" >>$log
			# cat $buildQuery >>$log
			# echo -e "--------------------------------------------- END OF SQL QUERY ---------------------------------------------" >>$log
			# echo -e "\nDone.\n" >>$log
		}

		# Execute the following when updateUsers-AE is called.
		# Expectation: Database is updated.
		echo -e "\nUpdating MySQL:"
		echo -ne '  Building MySQL Query\t  [ ===                        ] (10%)'
			buildQuery_EA
		echo -ne '\r  Updating MySQL          [ ========                   ] (25%)'
			executeQuery
		echo -ne '\r  MySQL updated        \t  [ ========================== ]   (100%)'
		echo
	}

	# Execute the update query
	function executeQuery {
		echo -e "################################\nExecuting SQL Query\n################################\n" >>$log
		rcmysql status *>>$log
			if [ $? -ne 0 ]
				then echo "MySQL is not running. Aborting script." >>$log
				?=3; checkError
			fi
		mysql -vvv -h 127.0.0.1 -uroot -p$dbpass < $buildQuery >$nts_filr_mysql
			if [ $? -ne 0 ]
				then echo "Error when connecting to MySQL or when executing SQL Query." >>$log
				?=3; checkError
				else {
					echo -e "SQL Update Query finished: "$nts_filr_mysql >>$log; 
					echo -e "\n--------------------------------------------- START OF SQL RESPONSE ---------------------------------------------" >>$log
					cat $nts_filr_mysql >>$log
					echo -e "--------------------------------------------- END OF SQL RESPONSE ---------------------------------------------" >>$log

				}
			fi  

			# if [[ -s "$nts_filr_mysql" ]]
			# 	echo -e "Attempted to run SQL Query. Nothing came back from MySQL: $nts_filr_mysql" >>$log 
			# 	checkError
			# fi
	
	}

	function backupSQL {
		echo -e "use $DATABASE;\n" >$bak_Principals
		mysqldump -uroot -p$dbpass filr SS_Principals >> $bak_Principals
	}

	function restoreBackup {
		echo "Provide backup SQL file. A backup is created upon load."
		cd $workingDirectory/bak >/dev/null
		ls -l . | grep -i bak
		echo
		read -ep "[Press Enter for most recent]: " backupSQLFile
		backupSQLFile="${backupSQLFile:-$bak_Principals}"

		mysql -h 127.0.0.1 -uroot -p$dbpass < $backupSQLFile
			if [ $? -ne 0 ]
				then { 
					echo -e "\nAn error has occurred while attempting to restore: $backupSQLFile"  >>$log
					echo -e "\nAn error has occurred while attempting to restore: $backupSQLFile\n" 
					exit 1
				}
				else {
					echo -e "\nSuccessfully restored from backup: $backupSQLFile" >>$log
					echo -e "\nSuccessfully restored from backup: $backupSQLFile" 
				} 
			fi

	}

	function theGate {
		clear; info
		read -p "nts password: " -s -r req
		req=`echo $req | base64 | hexdump -e '1/1 "%02X"'`
		if [[ "$req" == "626D39325A57787343673D*
0A" ]];
			then break;
			else echo; exit 1;
		fi
	}

	function getProduct {
		while :
		do
		clear; info

		echo -e "       Select a Product:"
		echo -e "\t1) Filr"
		echo -e "\t2) Vibe"
		echo -e "\n\tq) Quit"
		echo -n -e "\nSelection: "

		read n
		case $n in
			1) PRODUCT='Filr'
				DATABASE='filr'	
				break;
				;;

			2) PRODUCT='Vibe'
				DATABASE='sitescape'
				break;
				;;

			/q | q | 0) clear; echo "Bye $USER"; exit 0;; 
		  		 *) clear;;
		esac
		done
	}

	function mySQL_getCredentials {
	  clear; info
	  rcmysql status *>>$log
	  if [ $? -ne 0 ]
	    then echo "MySQL is not running. Aborting script."
	    exit 1
	  fi
	  while :
	  do
	    read -p "MySQL root password: " -s dbpass
	    echo "use $DATABASE; \q" | mysql -h 127.0.0.1 -uroot -p$dbpass
	    if [ $? -eq 0 ]
	      then break;
	    fi 
	    echo ""
	  done
	}


	function askYesOrNo {
		echo 
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

	function viewLog {
		if askYesOrNo "Do you want to view the log? "; 
			then less $log
		fi
		echo "For details, see log: "$log
	}

	function cleanup {
		# Cleanup logs, tmp files, etc
		# Cleaning up tmp files upon script exit
		echo "In development..."
	}

# User Interface and calls below:
# May want to begin merge with filr-nssRights, or ignore checking of mysql stuff... or copy the function in here for now..

theGate
getProduct
defineVariables
mySQL_getCredentials
backupSQL

while :
do
clear
info
backupInfo
echo -e "       Migrate Directory Services"
echo -e "\t1) Active Directory to eDirectory"
echo -e "\t2) eDirectory to Active Directory"
echo -e "\n\t3) Restore from backup"
echo -e "\n\tq) Quit"
echo -n -e "\nSelection: "

read n
case $n in

  1) clear; info;
	DIRECTORY=EDIR;
	getAllUsers
	updateUsers_AE
	viewLog
	# less $log
	read -p "Press [Enter] to return to Main Menu."
	;;

  2) clear; info;
	DIRECTORY=AD;
	getAllUsers
	updateUsers_EA
	viewLog
	# less $log
	read -p "Press [Enter] to return to Main Menu."
	;;

  3) clear; info;
	restoreBackup	
	read -p "Press [Enter] to return to Main Menu."
	;;

/q | q | 0) clear; echo "Bye $USER"; exit 0;; 
  		 *) clear;;
esac
done
exit 0
