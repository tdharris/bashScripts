#!/bin/bash
file="ldif.txt"

cat "$file" | grep 'dn:\|sAMAccountName\|^$' | sed 's/^$/--/g' | while read -r line; do

  case "$line" in
   	"dn:"*)
		dn=$(echo "$line" | cut -d ':' -f2- | cut -d ',' -f1 | sed 's/CN=//g')
		;;
	
	"sAMAccountName:"*)
		sAMAccountName=$(echo "$line" | cut -d ':' -f2-)
		;;

	--) # '--' signifies a new match pattern group, execute comparison when we see this line
		if [[ "$dn" != "$sAMAccountName" ]]; then
			echo "mismatch! parsedDN:$dn | sAMAccountName:$sAMAccountName"
		fi
		# reset value for next pattern match grouping
		dn=""
		sAMAccountName=""
		;;
	
	esac

done

exit 0