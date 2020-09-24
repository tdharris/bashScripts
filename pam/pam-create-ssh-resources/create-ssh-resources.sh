#!/bin/bash
admin="admin"
password="password"
rest_server="server"

# Colors
DEFAULT="\e[0m"
GREEN="\e[32m"
RED="\e[31m"
PURPLE="\e[35m"
YELLOW="\e[93m"

# How many Vault Resources?
for i in {3500..5000}; do

# Create the Vault Resource
echo -e "\n--\nCreating Vault Resource."
echo " ssh-server-$i"
response=$(curl -s -k --insecure \
-u $admin:$password \
--header 'Accept: application/json' \
-X PUT \
--data '{"Vault":{"type":"ssh","profile":101,"name":"ssh-server-'$i'","CFG":{"hkey":"tharris1.lab.novell.com,151.155.221.26 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBCxPyAii6VIMZnQU777u0jkN1RKA08624GnuGb6+79n0PEQm+IXIYhFzw/J3RV3owSvm9cXkckgsVywHyz2jE5o=\n","host":"tharris1.lab.novell.com","port":22}}}' \
'https://'$server'/rest/prvcrdvlt/Vault')

response1Result=$(echo $response | ~/jq .status)
if [ $response1Result -eq 200 ]; then
  echo -e "$GREEN  SUCCESS $DEFAULT: $response1Result"
else
  echo -e "$RED  ERROR $DEFAULT: $response1Result $(echo $response | ~/jq .message)"
fi

# Add credentials to the resource
echo -e "\nCreating Credentials."
if [ $response1Result -eq 200 ]; then
  id=$(echo $response | ~/jq .Vault.id | sed 's/"//g')
  echo -e " Vault Id:$PURPLE $id $DEFAULT"
  # How many credentials?
  for i in {1..5}; do
    echo " admin$i"
    response2=$(curl -s -k --insecure -u $admin:$password --header 'Accept: application/json' -X PUT --data '{"Credential":{"vault":"'$id'","account":"'admin$i'","type":"pkey","PCD":{"passwd":"microfocus123"}}}' 'https://'$server'/rest/prvcrdvlt/Credential')
    response2Result=$(echo $response2 | ~/jq .status)
    if [ $response1Result -eq 200 ]; then
      echo -e "$GREEN  SUCCESS $DEFAULT: $response2Result"
    else
      echo -e "$RED  ERROR $DEFAULT: $response2Result $(echo $response2 | ~/jq .message)"
    fi
  done
else 
  echo -e "$YELLOW WARNING $DEFAULT: Skipping credentials."
fi

done
exit 0
