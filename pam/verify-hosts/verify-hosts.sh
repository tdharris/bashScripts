#!/bin/bash

# Variables
WORK_DIR="/tmp"
FILE_HOSTS_EXPORT="$WORK_DIR/registry.txt"
SQL_GET_HOSTS="select name, host, port from Service;"
REGISTRY_DB="/opt/netiq/npum/service/local/registry/registry.db"
DEFAULT_TIMEOUT_SECONDS=1

# Tests to Run
DNS=true
PING=true
PORT=true
CRT=true
TIME=true

# Colors
DEFAULT="\e[0m"
GREEN="\e[32m"
RED="\e[31m"

# Execute
sqlite3 "$REGISTRY_DB" "$SQL_GET_HOSTS" > "$FILE_HOSTS_EXPORT"

cat "$FILE_HOSTS_EXPORT" | while read -r line; do

	# Parse Agent info
	name=$(echo "$line" | cut -d '|' -f1)
	host=$(echo "$line" | cut -d '|' -f2)
	port=$(echo "$line" | cut -d '|' -f3)
	echo "------------------------------------------------------------------------"
	echo "Processing Agent $name"
	echo "host:$host"
	echo "port:$port"
	echo "------------------------------------------------------------------------"

	# Verify DNS
	# Note: `dig <ipAddress>` shouldn't be a problem since the return code is 0
	if [ $DNS ]; then
		echo -e "\nVerifying DNS..."
		dns_response=$(host "$host")
		if [ "$?" -eq 0 ]; then
			echo -e "$GREEN Got answer$DEFAULT: $dns_response"
		else
			echo -e "$RED ERROR $DEFAULT: Failed dns lookup! $dns_response"
		fi
	fi
	
	# Verify basic network connectivity
	if [ $PING ]; then
		echo -e "\nVerifying basic network activity..."
		ping_response=$(ping -c 1 -W $DEFAULT_TIMEOUT_SECONDS "$host")
		if [ "$?" -eq 0 ]; then
			echo -e "$GREEN Server is up $DEFAULT: $(echo "$ping_response" | tail -n1)"
		else
			echo -e "$RED ERROR $DEFAULT: Failed ping test! $ping_response"
		fi
	fi

	# Verify port connectivity
	if [ $PORT ]; then
		echo -e "\nVerifying port connectivity..."
		netcat_response=$(netcat -zv -w $DEFAULT_TIMEOUT_SECONDS "$host" "$port")
		if [ "$?" -eq 0 ]; then
			echo -e "$GREEN Connection established $DEFAULT: $netcat_response"
		else
			echo -e "$RED ERROR $DEFAULT: Failed port connectivity test! $netcat_response"
		fi
	fi

	# Verify certificate validity
	if [ $CRT ]; then
		echo -e "\nVerifying certificate validity..."
		openssl_connection=$(echo "QUIT" | openssl s_client -connect "$host:$port")
		if [ "$?" -ne 0 ]; then
			echo -e "$RED ERROR $DEFAULT: Problem connecting to host! $openssl_connection"
		else 
			openssl_response=$(echo "$openssl_connection" | openssl x509 -noout -checkend 0)
			if [ "$?" -eq 0 ]; then
			  echo -e "$GREEN Certificate is valid$DEFAULT."
			else
			  echo -e "$RED ERROR $DEFAULT: Problem with openssl or certificate! $openssl_response"
			fi
		fi
	fi

	# Verify time sync (current vs remote)
	if [ $TIME ]; then
		echo -e "\nVerifying time synchronization..."
		# Check if clockdiff command is available (ICMP TIMESTAMP)
		if [[ ! -x $(command -v clockdiff) ]]; then
			echo "ntpq is not installed: skipping test."
		else
			clockdiff_response=$(timeout $DEFAULT_TIMEOUT_SECONDS clockdiff -o "$host")
			if [ "$?" -eq 0 ]; then
			  echo -e "clockdiff:$GREEN Time in sync$DEFAULT."
			else
			  echo -e "clockdiff:$RED ERROR $DEFAULT: Time is unsynchronized! $clockdiff_response"
			fi
		fi
		# Hmmm.. only would work if testing directly with ntp host server..
		# # Check ntpq command is available
		# if [[ ! -x $(command -v ntpq) ]]; then
		# 	echo "ntpq is not installed: skipping test."
		# else
		# 	ntp_offset=$(ntpdate -q "$host" | awk 'BEGIN { offset=1000 } $1 ~ /\*/ { offset=$9 } END { print offset }')
		# 	if [ "$?" -eq 0 ]; then
		# 	  echo -e "ntpq:$GREEN Time in sync$DEFAULT."
		# 	else
		# 	  echo -e "ntpq:$RED ERROR $DEFAULT: Time is unsynchronized! offset:$ntp_offset"
		# 	fi
		# fi
	fi

done

# Cleanup
rm "$WORK_DIR/$FILE_HOSTS_EXPORT" 2>/dev/null

exit 0