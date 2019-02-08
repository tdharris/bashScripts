#!/bin/bash
##################################################################################################
#																								
#	gwBackup.sh
#	by Tyler Harris and Shane Nielson
#
##################################################################################################

##################################################################################################
#
#	First Initialize / tools
#
##################################################################################################

# Initialize the yes/no prompt
		YES_STRING=$"y"
		NO_STRING=$"n"
		YES_NO_PROMPT=$"[y/n]: "
		YES_CAPS=$(echo ${YES_STRING}|tr [:lower:] [:upper:])
		NO_CAPS=$(echo ${NO_STRING}|tr [:lower:] [:upper:])

		function askYesOrNo-NoLog {
			REPLY=""
			while [ -z "$REPLY" ] ; do
				read -ep "$1 $YES_NO_PROMPT" REPLY
				REPLY=$(echo ${REPLY}|tr [:lower:] [:upper:])
				case $REPLY in
					$YES_CAPS ) return 0 ;;
					$NO_CAPS ) return 1 ;;
					* ) REPLY=""
				esac
			done
		}

##################################################################################################
#
#	gwBackup Configuration
#
##################################################################################################

	if [ -z "$1" ];then
		echo "No gwBackup configuration path passed in."
		if askYesOrNo-NoLog "Would you like to configure gwBackup now?";then
			conf=/tmp/gwBackup.conf
		else 
			echo -e "\nRun \"gwBackup.sh /etc/gwBackup/<SOURCE>\" if already configured."
			exit 0;
		fi
	elif [ -n "$1" ] && [ -d "$1" ];then
		if [ -f "$1/gwBackup.conf" ];then
			conf="$1/gwBackup.conf"
			conf=`echo $conf | sed 's,//,/,g'`
			confDir="$1"

		elif [ ! -f "$1/gwBackup.conf" ];then
			echo "Cannot find gwBackup configuration directory at '$1'"
			exit 1;	
		fi
	fi
	

	# Create gwBackup.conf at current script location.
	if [ ! -f "$conf" ];then
		echo -e '#Configuration Settings\nlog="/tmp/gwBackup.log"\ndebug=false\nsource=""\ndest=""\nstartHour=22\nnumOfWeeks=3\nstartDay=\ndbCopyUtil="/opt/novell/groupwise/agents/bin/dbcopy"\ngwBackupRun=true\n\nisSourceMounted=false\nisDestMounted=false\nconfigured=false\n\n#Backup script tracking\nbackupRoutine=false\nbackupRan=false\ncurrentWeek=0\ncurrentDay=1\ndayOfWeek=\n' > "$conf"
	fi

##################################################################################################
#
#	Declare Variables
#
##################################################################################################

	nextWeek=false;
	sourceSize=0
	destSize=0
	cronFile="/etc/cron.d/gwBackup"
	source "$conf"

##################################################################################################
#
#	Logger
#
##################################################################################################
	INTERACTIVE_MODE="off"
	if [[ "${INTERACTIVE_MODE}" == "off" ]]
	then
	    # Then we don't care about log colors
	    declare -r LOG_DEFAULT_COLOR=""
	    declare -r LOG_ERROR_COLOR=""
	    declare -r LOG_INFO_COLOR=""
	    declare -r LOG_SUCCESS_COLOR=""
	    declare -r LOG_WARN_COLOR=""
	    declare -r LOG_DEBUG_COLOR=""
	else
	    declare -r LOG_DEFAULT_COLOR="\e[0m"
	    declare -r LOG_ERROR_COLOR="\e[31m"
	    declare -r LOG_INFO_COLOR="\e[0m"
	    declare -r LOG_SUCCESS_COLOR="\e[32m"
	    declare -r LOG_WARN_COLOR="\e[33m"
	    declare -r LOG_DEBUG_COLOR="\e[34m"
	fi

	# If log_error or log_warning are called, then log_problem gets flipped to 1.
	# This will be used for email settings later in script.
	log_problem=0

	# This function scrubs the output of any control characters used in colorized output
	# It's designed to be piped through with text that needs scrubbing.  The scrubbed
	# text will come out the other side!
	prepare_log_for_nonterminal() {
	    # Essentially this strips all the control characters for log colors
	    sed "s/[[:cntrl:]]\[[0-9;]*m//g"
	}

	log() {
	    local log_text="$1"
	    local log_level="$2"
	    local log_color="$3"

	    # Default level to "info"
	    [[ -z ${log_level} ]] && log_level="INFO";
	    [[ -z ${log_color} ]] && log_color="${LOG_INFO_COLOR}";

	    echo -e "${log_color}[$(date +"%Y-%m-%d %H:%M:%S %Z")] [${log_level}] ${log_text} ${LOG_DEFAULT_COLOR}" >> "$log";
	    return 0;
	}

	log_info()      { log "$@"; }
	log_success()   { log "$1" "SUCCESS" "${LOG_SUCCESS_COLOR}"; }
	log_error()     { log_problem=1; log "$1" "ERROR" "${LOG_ERROR_COLOR}"; }
	log_warning()   { log_problem=1; log "$1" "WARNING" "${LOG_WARN_COLOR}"; }
	log_debug()     { if ($debug); then log "$1" "DEBUG" "${LOG_DEBUG_COLOR}"; fi }

##################################################################################################
#
#	Functions
#
##################################################################################################
	# Utility

		function askYesOrNo {
			REPLY=""
			while [ -z "$REPLY" ] ; do
				read -ep "$1 $YES_NO_PROMPT" REPLY
				REPLY=$(echo ${REPLY}|tr [:lower:] [:upper:])
				log_debug "[askYesOrNo] : $1 $REPLY"
				case $REPLY in
					$YES_CAPS ) return 0 ;;
					$NO_CAPS ) return 1 ;;
					* ) REPLY=""
				esac
			done
		}

		function isPathMounted {
			# If directory is different than /root, then we presume the path 
			# is mounted and we should verify the mount in the future
			if [ `stat -fc%t:%T "$1"` != `stat -fc%t:%T "/"` ]; then
			    return 0
			else
			    return 1
			fi
		}

		function promptVerifyPath {
			while [ true ];do
	    		read -ep "$1" path;
		        if [ ! -d "$path" ]; then
		            if askYesOrNo $"Path does not exist, would you like to create it now?"; then
		                mkdir -p $path;
		                break;
		            fi
		        else break;
		        fi
		    done
		    eval "$2='$path'"
		}

		function promptVerifyFile {
			while [ true ];do
	    		read -ep "$1" file;
		        if [ -f "$file" ]; then
		            break
		        else echo -e "File not found!\n"
		        fi
		    done
		    eval "$2='$file'"
		}

		function pushConf {
			local header="[pushConf] [$conf] :"
			# $1 = variableName | $2 = value
			sed -i "s|$1=.*|$1=$2|g" "$conf";
			if [ $? -eq 0 ];then
				log_debug "$header $1 has been reconfigured to $2"
			else
				log_error "$header Failed to reconfigure $1 to $2"
			fi
		}

		function pushArrayConf {
			# $1 = array value | $2 = new array value
			local lineNumber=`grep weekArray= -n $conf | cut -d ':' -f1`
			sed -i ""$lineNumber"s|'$1'|'$2'|g" "$conf";
		}

		function checkDBCopy {
			if [ ! -f "$dbCopyUtil" ]; then
				# Couldn't find dbcopy in default install location
				promptVerifyFile "Path to DBCopy: " dbCopyUtil
				pushConf "dbCopyUtil" "\"$dbCopyUtil\""
			fi
		}

		function configLogRotate { # $1 is path to logs.
			local header="[configLogRotate] [Init] :"
			logRotate="$(cat <<EOF                                                        
$1 {
    compress
    compresscmd /usr/bin/gzip
    dateext
    maxage 14
    rotate 99
    missingok
    notifempty
    size +4096k
    create 640 root root
}
EOF
			)"
			if [ ! -f "/etc/logrotate.d/gwBackup" ];then
				log_info "$header Creating /etc/logrotate.d/gwBackup"
				echo -e "$logRotate\n" > /etc/logrotate.d/gwBackup
			else
				local grepVar=`grep "$1" /etc/logrotate.d/gwBackup`
				if [ -z "$grepVar" ];then
					echo -e "$logRotate\n" >> /etc/logrotate.d/gwBackup
				fi
			fi

		}

		function cleanLogRotate {
			local header="[cleanLogRotate] :"
			if [ -f "/etc/logrotate.d/gwBackup" ];then
				local grepVar=`grep -n "$1" /etc/logrotate.d/gwBackup | cut -f1 -d ":"`
				if [ -n "$grepVar" ];then
					sed -i "${grepVar},+11d"  /etc/logrotate.d/gwBackup
					log_info "$header Removing $1 from logRotate"

					# Remove file if empty
					local fileVar=`cat /etc/logrotate.d/gwBackup`
					if [ -z "$fileVar" ];then rm /etc/logrotate.d/gwBackup;fi
					return 0;
				fi
			fi
		}

		function calcSourceSize { # $1 = Output back to variable
			local size=0;
			local size2=0;

			isPathGW "$source"
			if [ $? -eq 0 ];then
				size=`du -s $source | awk '{print $1}'`
			elif [ $? -eq 1 ];then
				local offileDir=`ls $source | grep -i offiles`
				size=`du -s $source --exclude="$offileDir" | awk '{print $1}'`
				size2=`du -s $source/offiles | awk '{print $1}'`
				size2=$(($size2 * $numOfWeeks))
				size=$(($size * $numOfWeeks))
				size=$(($size * 7))
				size=$(($size + $size2))
			else
				size="Unknown source"
			fi
			eval "$1=$size"
		}

		function isPathGW {
			local header="[isPathGW] :"
			if [ -f "$1/wpdomain.db" ];then
				log_info "$header Path verified as domain (wpdomain.db): $1"
				return 0
			elif [ -f "$1/wphost.db" ];then
				log_info "$header Path verified as po (wphost.db): $1"
				return 1
			else
				log_error "$header Path doesn't contain wpdomain.db or wphost.db: $1"
				return 3
			fi
		}

		function calcDestSize { # $1 = path to check | $2 = Output back to variable
			local size=`df "$1" | grep -vE '^udev|_admin|tmpfs|cdrom|Filesystem' | awk '{ print $4}'`
			eval "$2=$size"
		}

		function diskPercentUsed { 
			# $1 = path to check | $2 = Output back to variable
			local size=$(df $1 | grep -vE '^udev|_admin|tmpfs|cdrom|Filesystem' | awk '{ print $5}' | cut -d'%' -f1)
			eval "$2=$size"
		}

		function storagePercentCheck {
			local header="[storagePercentCheck] :"
			sizePercentWanring=0
			diskPercentUsed "$1" sizePercentWanring
			if [ $sizePercentWanring -ge 90 ]; then
				log_warning "$header Destination $1 low on disk space. $sizePercentWanring% Used"
			fi
		}

		function storageSizeCheck { # Requires calcSourceSize & calcDestSize be called to compare
			local header="[storageSizeCheck] :"
			calcSourceSize sourceSize;
			calcDestSize "$dest" destSize;
			if [ "$destSize" -lt "$sourceSize" ];then
				log_error "$header Destination $dest has insufficient storage space."
				sizeWarning=`echo $(date)" Destination $dest has insufficient storage space."`
			else sizeWarning=""
			fi
		}

		function configArray {
			local header="[configArray] :"
			arrayValue="'0'"
				for (( count=1; count<$numOfWeeks; count++));
				do
					arrayValue=`echo $arrayValue "'$count'"` 
				done
				echo -e "#gwBackup week array\nweekArray=( $arrayValue )\n" >> "$conf"
				log_info "$header Week array defaults have configured"
		}

		function cleanArray {
			local header="[cleanArray] :"
			sed -i '/#gwBackup week array/,+2d' $conf
			log_info "$header Week array configuration removed"
		}

		function configEmail {
			clear;
			echo -e "   Configuring gwBackup email\n"
			echo -e "1. SMTP"
			echo -e "2. Localhost"
			echo -n -e "\nSelection: "
			read opt
			case $opt in #Start of Case

			1) 
				echo
				read -p "Email address: " email_address;
				read -p "SMTP server address: " email_server;
				ns_email_server=`nslookup "$email_server" | grep Name | awk '{print $2}'`
				if [ -z "$ns_email_server" ];then
					ns_email_server=`nslookup $email_server | grep name | awk '{print $4}' | sed 's/.$//'`
					if [ -n "$ns_email_server" ];then
					email_server=$ns_email_server
					fi
				fi
				read -p "SMTP server port: " email_port;
				if askYesOrNo $"Authentication required?";then
					read -p "Username: " email_username;
					read -sp "Password: " email_password;
					echo
					email_username=`echo "$email_username" | base64`
					email_password=`echo "$email_password" | base64`
					echo -e "#SMTP Email Configuration\nemail_source=smtp\nemail_address=$email_address\nemail_server=$email_server\nemail_port=$email_port\nemail_auth=true\nemail_username=$email_username\nemail_password=$email_password\n" >> $conf
				else
					echo -e "#SMTP Email Configuration\nemail_source=smtp\nemail_address=$email_address\nemail_server=$email_server\nemail_port=$email_port\nemail_auth=false\n" >> $conf
				fi
			;;

			2)
				isPostfixRunning=`rcpostfix status | awk '{print $5}' | grep -o running`
				if [ "$isPostfixRunning" = "running" ];then
					echo
					read -p "Email address: " email_address;
					echo -e "#Local Email Configuration\nemail_source=local\nemail_address=$email_address\nemail_auth=false\n" >> $conf
				else
					echo -e "\npostfix not running for local sendmail"
				fi
			;;

	 	*) echo -e "\nInvalid selection"
	 	 ;;
		esac # End of Case
		}

		function cleanEmail {
			if [ "$email_source" = "smtp" ];then
				if($email_auth);then
					sed -i '/#SMTP Email Configuration/,+8d' $conf
				elif (! $email_auth);then
					sed -i '/#SMTP Email Configuration/,+6d' $conf
				fi
			fi
			if [ "$email_source" = "local" ];then
				sed -i '/#Local Email Configuration/,+4d' $conf
			fi
		}

		function sendMail {
			# requires 	expect
			#			mimencode (for attachments), .deb=metamail
			#
			# Koen Noens, November 2008
			# This is free software under the terms and conditions of GPL v3
			#
			# Modified Shane Nielson, Auguest 2014

			# $1 is passed in full path attachment.
			# $2 is passed in subject.
			# $3 is passed in message body
			local header="[sendMail] :"
			SUBJ=$2

				function getAttachment { # pass in $1 for path of attachment
					local header="[getAttachment] :"
					if [ -f "$1" ]; then
					    mimencode $1 -o $ATT_ENCODED
						ATTACH_NAME=$(basename $1)
					else
					   log_error "$header $1 file not found, sending email without attachment."
					   withAttach=0
					fi
					}

			if [ "$email_source" = "local" ];then
				log_info "$header Sending email to $email_address via localhost"
				if [ -n "$1" ];then
					echo "$3" | mail -s "$2" -r "gwBackup" -a "$1" $email_address ;
				else
					echo "$3" | mail -s "$2" -r "gwBackup" $email_address;
				fi
			 # Else case : Run SMPT via telnet
			else
				log_info "$header Sending email to $email_address via SMTP [$email_server]"
				# params for attachment
				MIME="MIME-Version: 1.0 "
				ENCODING="Content-transfer-encoding: base64; "
				CONTENTTYPE="Content-Type: multipart/mixed; "
				BOUNDARY="000MultipartBoundary000MultipartBoundary0000"
				ATTACH_TYPE="Content-Type: application/octet-stream; "
				ATTACH_NAME=""
				ATT_ENCODED=""

				BODY=$(mktemp)
				ATT_ENCODED=$(mktemp)

				# create mail msg
				(echo -e "$3" > $BODY)

				if [ -n "$1" ];then
					withAttach=1
					getAttachment "$1"

					if [ $withAttach -eq 1 ];then
						#modify body to multi-part
						BODYTEMP=$(mktemp)
						cat $BODY > $BODYTEMP; rm $BODY
						BODY=$(mktemp)
						
						echo "$MIME" >> $BODY
						echo -e "$CONTENTTYPE boundary=\\\"$BOUNDARY\\\"" >> $BODY

						#From, to, can be repeated here for mail client display
						#CC and BCC can be put here if the have a RCPT TO in envelop

						echo -e "Subject: $SUBJ \n\n"  >> $BODY  

						#subject line marks the end of the extra headers in DATA
						#newlines are significant in boundaries, don't change.

						### text part ###
						echo -e "\n--$BOUNDARY\n\n" >> $BODY
						cat $BODYTEMP >> $BODY

					    ### attachment ###	
						echo -e "\n--$BOUNDARY" >> $BODY
						echo "$ENCODING" >> $BODY
						echo -e "$ATTACH_TYPE name=$ATTACH_NAME \n" >> $BODY
						cat $ATT_ENCODED >> $BODY
						
						### body end ###
						echo -e "\n--$BOUNDARY--\n" >> $BODY
					fi
				else
					withAttach=0
				fi		

				## do protocol with expect
				expect <<EOF
				log_user 0
				spawn telnet $email_server $email_port
				expect "220*"

				## ENVELOPE 
				send "HELO $email_server \r"
				expect "250*"
				if {"$email_auth" == "true"} {
				send "AUTH LOGIN \r"
				expect "334 VXNlcm5hbWU6"
				send "$email_username \r"
				expect "334 UGFzc3dvcmQ6"
				send "$email_password \r"
				expect "235 Authentication*"
				}
				send "MAIL FROM: gwBackup \r"
				expect "250*"
				send "RCPT TO: $email_address \r"
				expect "250"

				## BODY / MSGs
				send "DATA \r"
				expect "354*"
				if {$withAttach == 0} {send "Subject: $SUBJ\r\r"}
				send "$(cat $BODY) \r\r.\r"
				expect "250*"
				send "quit \r"
				expect "250*"
				log_user 1
EOF
				# Clean up
				rm $BODY $ATT_ENCODED $BODYTEMP

			fi # End of local or smtp source if
		}

		# Init-Configure
			# Prompt for input: source/dest, maxWeeks
			function configure {
				clear; echo -e "###################################################\n#\n#	Configuring gwBackup\n#\n###################################################\n"

				while true
				do
					promptVerifyPath "Path to [DOM|PO] Directory: " source
					isPathGW "$source"
					if [ $? -ne 3 ]; then 
						pushConf "source" "\"$source\""
						isPathMounted "$source"
						if [ $? -eq 0 ]; then 
							pushConf "isSourceMounted" true
						fi
						break
					else
						echo -e "Path doesn't contain wphost.db or wpdomain.db - not a GW Path!\n"
					fi
				done

				promptVerifyPath "Destination path: " dest
				pushConf "dest" "\"$dest\""
				isPathMounted "$dest"
				if [ $? -eq 0 ]; then 
					pushConf "isDestMounted" true
				fi
				echo

				checkDBCopy

				# Get number of weeks for backups (Must be 3 or more)
				while true
				do
					local defaultnumOfWeeks=3
					read -ep "Number of weeks for backups [$numOfWeeks]: " numOfWeeks
						numOfWeeks="${numOfWeeks:-$defaultnumOfWeeks}"
					if [ "$numOfWeeks" -ge '1' ];then
						pushConf "numOfWeeks" $numOfWeeks
						break;
					else
						echo "3 or more required."
						numOfWeeks=$defaultnumOfWeeks;
					fi
				done

				# Check required storage space on $dest
				echo -e "\nChecking if $dest has required space for backup routine.\nPlease wait as this can take some time...\n"
				storageSizeCheck
				if [ -n "$sizeWarning" ];then
					echo $sizeWarning;
					rm $conf;
					exit 1;
				fi

				configCron "/etc/gwBackup/`basename $source`/";
				configureStartDay;

				if askYesOrNo $"Configure email?";then
					clear;
					configEmail;
				fi

				# Create empty array into gwback.conf
				configArray;

				# Set up log directory
				local logPath=/var/log/gwBackup/`basename $source`
				mkdir -p $logPath;
				configLogRotate "$logPath/gwBackup.log";
				pushConf "log" "$logPath/gwBackup.log"

				# Move old log if exists
				if [ -f /tmp/gwBackup.log ];then
					mv /tmp/gwBackup.log $logPath;
				fi

				pushConf "dayOfWeek" $(date '+%w')
				pushConf "configured" true

				# Set up configuration directory
				local configPath=/etc/gwBackup/`basename $source`
				mkdir -p $configPath;

				# Move old configuration if exists
				if [ -f /tmp/gwBackup.conf ];then
					mv /tmp/gwBackup.conf $configPath;
				fi

				echo -e "\ngwBackup for "`basename $source`" configured at $configPath"
				exit 0;
			}

			function configCron {
				configureStartHour;
				configureStartMin;
				local header="[configCron]"
				local sedFind=""
				if [ -n "$1" ];then
					local cronTask="$startMin $startHour * * * root $PWD/gwBackup.sh $1"
					sedFind="$1"
				else
					local cronTask="$startMin $startHour * * * root $PWD/gwBackup.sh $confDir"
					sedFind="$confDir"
				fi

				local grepVar=`grep "$sedFind" $cronFile 2>/dev/null`
				if [ -f "$cronFile" ]; then
					if [ -z "$grepVar" ];then
						echo "$cronTask" >> "$cronFile"
					elif [ -n "$grepVar" ];then
						sed -i "s|.*gwBackup.sh $sedFind|$cronTask|g" "$cronFile"
					fi
				else
					echo "$cronTask" > "$cronFile"
				fi

				log_info "$header : $cronTask"
			}

			function cleanCron {
				local header="[cleanCron] :"

				if [ -f "$cronFile" ]; then
					log_info "$header Removing $conf from $cronFile"
					local varGrepNum=`grep $confDir $cronFile -n | cut -f1 -d ':'`
					if [ -n "$varGrepNum" ];then
						sed -i "${varGrepNum}d" $cronFile;

						# Revmoe file is empty.
						local fileVar=`cat $cronFile`
						if [ -z "$fileVar" ];then rm $cronFile;fi
						return 0;
					fi
				else
					log_warning "File doesn't exist: $cronFile"
				fi
			}

			function configureStartHour {
				while true 
				do
					read -p "Enter start hour (24-hour clock: 0..23); 0 is midnight: " startHour
					if [[ $startHour =~ ^[0-9]{1,2}$ ]] && [ $startHour -lt 24 ]; then
						pushConf "startHour" $startHour
						break;
					else
						echo -e "Invalid hour format\n"
					fi
				done
			}

			function configureStartMin {
				while true 
				do
					read -p "Enter start minute (0..59): " startMin
					if [[ $startMin =~ ^[0-9]{1,2}$ ]] && [ $startMin -lt 60 ]; then
						break;
					else
						echo -e "Invalid minute format\n"
					fi
				done
			}

			function configureStartDay {
				echo -e "\nNote: gwBackup routines will be enabled on this day."
				while true 
				do
					read -p "Enter start day of week (0..6); 0 is Sunday: " startDay
					if [[ $startDay =~ ^[0-6]{1}$ ]]; then
						pushConf "startDay" $startDay
						break;
					else
						echo -e "Invalid day format\n"
					fi
				done
			}

			function cleanConf {
				local header="[cleanConf] :"
				cleanArray;
				cleanEmail;
				cleanCron;

				pushConf "currentDay" 1;
				pushConf "currentWeek" 0;
				pushConf "backupRoutine" false
				log_info "$header gwBackup.conf has been reset to defaults"
			}

			 # If $1 [true/false] is passed in. change backupRan=$1. otherwise compare backupRan
			 # If backupRan = true (for the day) abort running the backup. otherwise set back to false (not ran for the day)
			function backupOPD {
				local header="[backupOPD] :"
				local tmpCurrentDay=`expr $(date '+%w') + 1`
				# Set tmpCurrentDay to 0 if date (week) + 1 = 7
				if [ $tmpCurrentDay -eq 7 ];then
					tmpCurrentDay=0;
				fi

				if [ -n "$1" ];then
					pushConf "backupRan" $1
				elif [ "$backupRan" = "true" ] && [ $dayOfWeek -eq $tmpCurrentDay ];then
					log_warning "$header Backup already ran today. Aborting gwBackup."
				elif [ "$backupRan" = "true" ]; then
					backupRan=false
					pushConf "backupRan" false;
				fi
			}

		# Backup routine functions
			function validateDay {
				local header="[validateDay] :"
				weekCheckPass=1
				if [ $dayOfWeek -ne $(date '+%w') ];then
					log_error "$header Backup behind"
					log_info "$header Updating gwBackup.conf for day tracking"

					while [ $dayOfWeek -ne $(date '+%w') ]
					do
					  if [ $currentDay -eq 8 ];then
					  	currentDay=1;
					  	pushConf "currentDay" 1
					  fi
					  dayOfWeek=$(($dayOfWeek + 1));
					  pushConf "dayOfWeek" $(date '+%w')
					  currentDay=$(($currentDay + 1))
					  pushConf "currentDay" $currentDay
					  weekCheckPass=$(($weekCheckPass + 1));

					  if [ $dayOfWeek -eq 7 ];then
					      dayOfWeek=0;
					  fi
					done

					if [ $weekCheckPass -ge 7 ];then
					      backupRoutine=false;
					      pushConf "backupRoutine" false
					      log_info "$header Past start day. gwBackup routine set to false until next start day [$startDay]"
					fi
				fi
			}

			function bumpDay {
				# Increases currentDay by 1
				currentDay=$(($currentDay + 1))
				if [ $? -eq 0 ];then
					pushConf "currentDay" "$currentDay";
					log_debug "$header [Set] [currentDay] : Set to $currentDay"
				else
					log_error "$header [Set] [currentDay] : Failed to set $currentDay"
				fi
			}

			function checkDay {
				local header="[checkDay]"
					
				if [[ "$currentDay" -ne '8' ]];then
					if [ ! -d "$dest/gwBackup/${weekArray[$currentWeek]}/day"$currentDay"" ];then
						mkdir -p $dest/gwBackup/`basename $source`/${weekArray[$currentWeek]}/day"$currentDay"
						if [ $? -eq 0 ];then
							log_info "$header [${weekArray[$currentWeek]}/day$currentDay] : Day folder created."
						else
							log_error "$header [${weekArray[$currentWeek]}/day$currentDay] : Failed to create day folder."
						fi

						if [ "$currentDay" -ne '1' ] && [ "$currentDay" -ne '8' ];then
							# Create soft link to day1 offiles
							if [ -d "$dest/gwBackup/`basename $source`/${weekArray[$currentWeek]}/day1/offiles" ];then
								ln -s "$dest/gwBackup/`basename $source`/${weekArray[$currentWeek]}/day1/offiles" $dest/gwBackup/`basename $source`/${weekArray[$currentWeek]}/day"$currentDay";
								if [ $? -eq 0 ];then
									log_info "$header [${weekArray[$currentWeek]}/day$currentDay] : Offiles soft link created."
								else
									log_error "$header [${weekArray[$currentWeek]}/day$currentDay] : Failed to create soft link."
								fi
							fi
						fi

						# DBcopy source to dest/gwBackup
						log_info "[DBCopy] [${weekArray[$currentWeek]}/day$currentDay] : Running backup process."
						local tmpDayOfWeek=`expr $(date '+%w') + 1`
						$dbCopyUtil $source $dest/gwBackup/`basename $source`/${weekArray[$currentWeek]}/day"$currentDay" | sed 's,//,/,g' >> $log
						if [ $? -eq 0 ];then
							log_success "[DBCopy] [${weekArray[$currentWeek]}/day$currentDay] : Backup created."
							backupOPD true;
							if [ $tmpDayOfWeek -eq 7 ];then
								pushConf "dayOfWeek" 0
								log_debug "$header [Set] [dayOfWeek] : Set to 0"
							else
								pushConf "dayOfWeek" $tmpDayOfWeek
								log_debug "$header [Set] [dayOfWeek] : Set to $tmpDayOfWeek"
							fi
							bumpDay;
						else
							log_error "[DBCopy] [${weekArray[$currentWeek]}/day$currentDay] : Backup failed."
						fi
					else
						log_error "$header [${weekArray[$currentWeek]}/day$currentDay] : Folder already exists."
					fi
				fi

			}

			function checkWeek {
				local header="[checkWeek]"
				# Assign variable $now to current date in seconds.
				now=$(date +"%m-%d-%Y")

				# Set currentDay back to 1 if new week
				if ($nextWeek);then
					currentDay=1;
					if [ $? -eq 0 ];then
						pushConf "currentDay" "$currentDay";
						log_debug "$header [Set] [currentDay] : Set to $currentDay"
					else
						log_error "$header [Set] [currentDay] : Failed to set $currentDay"
					fi
					nextWeek=false;
				fi

				# Create new week folder on currentDay 1 and not at the end of week
				if [[ "$currentWeek" -lt "$numOfWeeks" ]] && [[ "$currentDay" -eq '1' ]];then
					mkdir -p $dest/gwBackup/`basename $source`/$now;
					if [ $? -eq 0 ];then
						log_info "$header [${weekArray[$currentWeek]}] : Week folder created."
						pushArrayConf "$currentWeek" "$now"
						pushArrayConf "${weekArray[$currentWeek]}" "$now"
						weekArray[$currentWeek]=$now;
						log_info "$header : Set weekArray index $currentWeek to $now"
					else
						log_error "$header [${weekArray[$currentWeek]}] : Failed to create week folder."
					fi

				# Jump to the next week, and delete any old folder (oldest) if folder exists
				elif  [[ "$currentWeek" -lt "$numOfWeeks" ]] && [[ "$currentDay" -eq '8' ]];then
					currentWeek=$(($currentWeek + 1))
					log_info "$header [currentWeek] : Set to $currentWeek"
					pushConf "currentWeek" "$currentWeek";
					if [ "$currentWeek" -ne "$numOfWeeks" ];then
						rm -rf $dest/gwBackup/`basename $source`/${weekArray[$currentWeek]}
						if [ $? -eq 0 ];then
							log_info "$header [Maint] [${weekArray[$currentWeek]}] : Folder removed"
						else
							log_error "$header [Maint] [${weekArray[$currentWeek]}] : Failed to remove folder"
						fi
					fi
					nextWeek=true
					checkWeek;

				# At the end of the week limit cycle. Set weeks to start over.
				elif [[ "$currentWeek" -eq "$numOfWeeks" ]] && [[ "$currentDay" -eq '1' ]];then
					rm -rf $dest/gwBackup/`basename $source`/${weekArray[0]}
					if [ $? -eq 0 ];then
						log_info "$header [Maint] [${weekArray[0]}] : Folder removed"
					else
						log_error "$header [Maint] [${weekArray[0]}] : Failed to remove folder"
					fi
					currentWeek=0;
					log_info "$header [Set] [currentWeek] : Set to $currentWeek"
					pushConf "currentWeek" "$currentWeek";
					nextWeek=true
					checkWeek;
				fi

			}


##################################################################################################
#
#	Switches
#
##################################################################################################
	shift;
	gwBackupSwitch=0
	while [ "$1" != "" ]; do
		case $1 in #Start of Case

		--help | '?' | -h) gwBackupSwitch=1
			echo -e "gwBackup switches for [`basename $source`]:";
			echo -e "     \t--debug\t\tToggle debug logging $log [$debug]"
			echo -e "  -r \t--run\t\tToggle gwBackup script run process [$gwBackupRun]"
			echo -e "  -c \t--clean\t\tRemove all configurations"
			echo -e "  -e \t--email\t\tgwBackup email menu"
			echo -e "  -a \t--autorun\tgwBackup auto-run menu"
		;;

		--clean | -c) gwBackupSwitch=1
			echo -e "\nRunning this will remove any current configuration for `basename $source`\nAny old backups will need to be manually removed.\n"
			if askYesOrNo $"Clean up `basename $source` from gwBackup?";then
				cleanProb=false;
				rm -fr $confDir; if [ $? -ne 0 ];then cleanProb=true;fi
				cleanCron;if [ $? -ne 0 ];then cleanProb=true;fi
				cleanLogRotate "/var/log/gwBackup/`basename $source`/"; if [ $? -ne 0 ];then cleanProb=true;fi
				if (! $cleanProb);then
					echo -e "Configuration for `basename $source` successfully removed."
					exit 0;
				else
					echo -e "Problem cleaning up configuration for `basename $source`"
					exit 1;
				fi
			fi
		;;

		--run | -r) gwBackupSwitch=1
			if [ "$gwBackupRun" = "true" ];then
				pushConf "gwBackupRun" false;
				echo "Setting gwBackup run process: false"
			else
				pushConf "gwBackupRun" true;
				echo "Setting gwBackup run process: true"
			fi
		;;

		--debug ) gwBackupSwitch=1
			if [ "$debug" = "true" ];then
				pushConf "debug" false;
				echo "Setting $log debug: false"
			else
				pushConf "debug" true;
				echo "Setting $log debug: true"
			fi
		;;

		--autorun | -a) gwBackupSwitch=1
			clear;
			echo -e "\tgwBackup auto-run Settings\n"
			echo -e "1. Congigure auto-run settings"
			echo -e "2. Remove auto-run settings"
			echo -n -e "\nSelection: "
			read opt
			case $opt in 
				1) 
					configCron;
					echo -e "\ngwBackup auto-run settings have been configured."
				;;

				2)	
					if [ -f "/etc/cron.d/gwBackup" ];then
						cleanCron;
						echo -e "\ngwBackup auto-run settings have been removed."
					else
						echo -e "\ngwBackup auto-run settings are not configured."
					fi
				;;

				*) echo -e "gwBackup: invalid option --  '$opt'"; gwBackupSwitch=1
		 	 ;; 
			esac 
		;;

		-e | --email) gwBackupSwitch=1
			clear;
			echo -e "\tgwBackup Email Settings\n"
			echo -e "1. Congigure email settings"
			echo -e "2. Remove email settings"
			echo -e "3. Check email settings"
			echo -e "\n4. Send test email"
			echo -n -e "\nSelection: "
			read opt
			case $opt in 
				1) 
					cleanEmail;
					configEmail;
				;;

				2)
					cleanEmail;
				;;

				3)
					clear;
					echo -e "\tgwBackup Email Settings"
					emailSwitch=`grep -i "Email Configuration" $conf`
					if [ -n "$emailSwitch" ];then
						echo -e "Email Address: $email_address"
						if [ "$email_source" = "smtp" ];then
							echo -e "Email Server: $email_server\nEmail Port: $email_port\nAuthentication Required: $email_auth"
							if ("$email_auth");then
								echo "Authentication Username: $(echo $email_username | base64 -d)"
							fi
						fi
					else
						echo -e "No email settings for gwBackup configured."
					fi
				;;

				4) 
					clear;
					echo -e "\tgwBackup Send Test Email"
					emailSwitch=`grep -i "Email Configuration" $conf`
					if [ -n "$emailSwitch" ];then
						sendMail "" "gwBackup Test Mail" "Test email of gwBackup email settings"
						echo -e "Sending email test to $email_address"
					else
						echo -e "Please configure gwBackup email settings."
					fi
				;;
		
		 	*) echo -e "gwBackup: invalid option --  '$opt'" ; gwBackupSwitch=1
		 	 ;; 
			esac 
		;;

		# Not valid switch case
	 	*) echo -e "gwBackup: invalid option -- '$1'" ; gwBackupSwitch=1
	 	 ;; 
		esac # End of Case
		shift;
	done

	# Exits 0 if gwBackupSwitch = 1
	if [ "$gwBackupSwitch" -eq "1" ];then
	exit 0;
	fi


### gwBackup run check ###
if ($gwBackupRun);then

	##################################################################################################
	#
	#	Startup / Initialization / User-Input Configuration
	#
	##################################################################################################

	# Configure gwBackup if not already configured
	if (! $configured); then
		configure
	else 
		# Checks
		storagePercentCheck "$dest"
	fi

	# If mounted. Verify it is still a mountpoint.
	if($isSourceMounted);then
		isPathMounted "$source"
		if [ $? -ne 0 ]; then 
			log_error "[isPathMounted] : Source $source mountpoint failure."
			exit 1;
		fi
	fi
	if($isDestMounted);then
		isPathMounted "$dest"
		if [ $? -ne 0 ]; then 
			log_error "[isPathMounted] : Destination $dest mountpoint failure."
			exit 1;
		fi
	fi

	##################################################################################################
	#
	#	Weekly Backup Routine / Nightly Incremental Backup Routine
	#
	##################################################################################################
	backupOPD;
	if [ "$backupRan" = "false" ];then

		# Check if backups are behind
		if($backupRoutine);then
			validateDay;
		fi

		# Only start the routine backup process on the day that is selected during configuration (one-time configuration)
		if (! $backupRoutine); then
			if [[ $startDay -eq $(date '+%w') ]]; then
				backupRoutine=true
				pushConf "backupRoutine" true
			fi
		fi

		# Runs main dbcopy backup routine.
		if($backupRoutine);then
			log_info "Beginning backup routine: Source: $source | Dest: $dest"
			echo -e "\n" >> $log
			checkWeek;
			checkDay;
		fi
	fi

	# Checks if email is configured.
	# If the logs reported any problem. Zip up logs, and email them to $email_address
	emailSwitch=`grep -i "Email Configuration" $conf`
	if [ -n "$emailSwitch" ] && [ $log_problem = 1 ];then
		# Convert $log to .txt for easy read format on all devices
		tempLog="/var/log/gwBackup/`basename $source`/gwBackup.txt"
		cp $log $tempLog

		# Zip up logs, and email them to $email_address
		zip /root/gwBackup_logs $tempLog >/dev/null
		sendMail "/root/gwBackup_logs.zip" "gwBackup log report" "gwBackup logs have detected an error with `basename $source`. Please review logs."
		# Clean up
		rm -f "/root/gwBackup_logs.zip" "$tempLog"
	fi
fi

exit 0;