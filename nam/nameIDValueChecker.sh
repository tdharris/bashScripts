#!/bin/bash
banner="
############################################################################################
#
# nameIDValueChecker.sh
#
# This script is intended to show duplicate nameIDValues being assigned to different users
# This will parse through NAM log(s) to build an index of nameIDValues and users. If a 
# particular nameIDValue is assigned to more than one unique user, then it will be printed.
#
############################################################################################
"
clear; 
echo "$banner";

read -e -p "log file or directory: " file

declare -A USERMAP

# grep -ihRa -B10 -A5 'nameIDValue' "$file"
sed -n '/<amLogEntry>/,/<\/amLogEntry>/H; /<amLogEntry>/h; /\/amLogEntry/{x;s/<amLogEntry>\(.*[^\n]\)\n*<\/amLogEntry>/\1/p;}' "$file" | grep Corning-Netiq | while read -r line; do

	case "$line" in
		--)
			# '--' signifies a new match pattern group (opportunity to parse 'nameIDValue' and 'principal')
			# only proceed if nameIDValue and principal have been parsed successfully (ignore first '--' when no parsing has occurred yet)
			if [[ -n "$nameIDValue" && -n "$principal" ]]; then
				# is nameIDValue already in use?
				if [[ "${USERMAP[$nameIDValue]}" ]]; then
					# lookup in index/hashmap: is nameIDValue being used by a different user? (ignore if being used by the same/correct user)
					if [[ "${USERMAP[$nameIDValue]}" != "$principal" ]]; then
						echo -e "---\n date\t\t\t: $dateEntry\n Thread \t\t: $thread \n nameIDValue\t\t: $nameIDValue\n originallyAssignedTo\t: ${USERMAP["$nameIDValue"]}\n beingAssignedTo\t: $principal"
					fi
				else
					# store what was found in associative array (index)
					USERMAP["$nameIDValue"]="$principal" 
					# echo "$nameIDValue | $principal" # key-value pairs being stored in associative array
				fi  
			fi
			# reset value for next pattern match grouping
			dateEntry=""
			nameIDValue=""
			principal=""
			thread=""
			;;

		*"<amLogEntry"*) # parse out date in group
			dateEntry=$(echo "$line" | cut -d'>' -f2- | sed 's\DEBUG.*:\\' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
			;;

		*"Thread"*) # parse out thread id in group
			thread=$(echo "$line" | cut -d ':' -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
			;;
			
		*nameIDValue:*)
			nameIDValue=$(echo "$line" | cut -d ':' -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
			;;

		*principal:*)
			principal=$(echo "$line" | cut -d ':' -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
			;;

	esac

done

exit 0
