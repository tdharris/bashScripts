#!/bin/bash

# User Variables
SERVER="localhost"
ADMIN="admin"
PASSWORD="<password>"
ORG_ID="2"
OUTPUT_CSV="./PAM_SERVICE_STATUS_ORG_$ORG_ID.csv"

# Create CSV file and headers for report
echo -e "Manager Server:,$SERVER\n" > "$OUTPUT_CSV"
echo "DOMAIN_ID,DOMAIN_NAME,AGENT,VERSION,STATUS" >> "$OUTPUT_CSV"

# Verify Dependencies
# "jq-linux64" should be in lib directory
jq="./lib/jq-linux64"
if [[ ! -x $(command -v "$jq") ]]; then
	echo -e "Failed library dependency: jq\nPlease install in '$jq': https://stedolan.github.io/jq/"
	exit 1
fi

if [[ ! -x $(command -v curl) ]]; then
	echo -e "Failed library dependency: curl"
	exit 1
fi

# REST Variables
PROTOCOL="https://"
REST_URI_ENDPOINT="/rest"
REST_URL="$PROTOCOL$SERVER$REST_URI_ENDPOINT"
HTTP_HEADER="Accept: application/json"

# Requests
GET_SERVICES="$REST_URL/registry/Organization/"
GET_SERVICES_PARAMS="?recursive=1&services=1"
GET_SERVICE_STATUS="$REST_URL/registry/Service/"
GET_SERVICE_STATUS_PARAMS="?getStatus=1"

# Get Services by Organization Id
echo -e "Discovering Agents by OrganizationId: $ORG_ID ..."
GET_SERVICES_RESPONSE=$(curl -s -k -u "$ADMIN:$PASSWORD" --header "$HTTP_HEADER" -X "GET" "$GET_SERVICES/$ORG_ID$GET_SERVICES_PARAMS")
if [ "$?" -ne 0 ]; then
	echo "Error!"
	exit 2
fi

ORG_NAME=$(echo "$GET_SERVICES_RESPONSE" | "$jq" -r '.OrgUnit.name')
echo -e "Found Organization $ORG_NAME (id:$ORG_ID)...\n\nProcessing Agents..."

SERVICES=$(echo "$GET_SERVICES_RESPONSE" | "$jq" -r '.OrgUnit.Service[].name')
echo "$SERVICES" | while read -r line; do

	AGENT_NAME="$line"
	echo "--"
	echo "Requesting Agent Status: $AGENT_NAME..."
	GET_SERVICE_STATUS_RESPONSE=$(curl -s -k -u "$ADMIN:$PASSWORD" --header "$HTTP_HEADER" -X "GET" "$GET_SERVICE_STATUS/$AGENT_NAME$GET_SERVICE_STATUS_PARAMS")
	if [ "$?" -ne 0 ]; then
		echo "Error in GET_SERVICE_STATUS_RESPONSE!"
	fi
	AGENT_VERSION=$(echo "$GET_SERVICE_STATUS_RESPONSE" | "$jq" -r '.Service.spf.vrm')
	AGENT_STATUS=$(echo "$GET_SERVICE_STATUS_RESPONSE" | "$jq" -r '.Service.status')
	echo -e "\t$AGENT_NAME: $AGENT_STATUS"
	echo "$ORG_ID,$ORG_NAME,$AGENT_NAME,$AGENT_VERSION,$AGENT_STATUS" >> "$OUTPUT_CSV"

done

echo -e "\nPlease find the csv report:\n$OUTPUT_CSV\n"

exit 0
