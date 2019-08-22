#!/bin/bash

# User Variables
SERVER="localhost"
ADMIN="admin"
PASSWORD="<password>"

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

# API Requests
GET_SSH_VAULTS="$REST_URL/prvcrdvlt/Vaults/ssh"
GET_VAULT_BY_ID="$REST_URL/prvcrdvlt/Vault/"
GET_SSH_HOST_KEY="$REST_URL/sshagnt/HostKey"
PUT_VAULT="$REST_URL/prvcrdvlt/Vault"

# Get SSH Vaults
echo -e "Fetching all ssh vaults from crdvlt: $GET_SSH_VAULTS ..."
GET_SSH_VAULTS_RESPONSE=$(curl -s -k -u "$ADMIN:$PASSWORD" --header "$HTTP_HEADER" -X "GET" "$GET_SSH_VAULTS")
if [ "$?" -ne 0 ]; then
	echo "Error in GET_SSH_VAULTS_RESPONSE!"
	exit 2
fi
SSH_VAULTS_BY_ID=$(echo "$GET_SSH_VAULTS_RESPONSE" | "$jq" -r '.Vault[].id')
echo "Found $(echo $SSH_VAULTS_BY_ID | sed 's/ /\n/g' | wc -l) ssh vaults."

# Iterate through every SSH_VAULT
{ echo "$SSH_VAULTS_BY_ID" | while read -r VAULT_ID; do 

    # Get ssh vault details
    echo -e "\n--\n"
    echo "Requesting Vault details: $VAULT_ID"
    GET_VAULT_BY_ID_RESPONSE=$(curl -s -k -u "$ADMIN:$PASSWORD" --header "$HTTP_HEADER" -X "GET" "$GET_VAULT_BY_ID/$VAULT_ID")
    if [ "$?" -ne 0 ]; then
		echo "Error in GET_VAULT_BY_ID_RESPONSE!"
        exit
	fi
    VAULT_NAME=$(echo "$GET_VAULT_BY_ID_RESPONSE" | "$jq" -r '.Vault.name')
    SSH_CFG=$(echo "$GET_VAULT_BY_ID_RESPONSE" | "$jq" -r '.Vault.CFG.SSH')
    SSH_HOST=$(echo "$SSH_CFG" | "$jq" -r '.host')
    SSH_PORT=$(echo "$SSH_CFG" | "$jq" -r '.port')

    # Get new ssh host key
    echo -e "Requesting the host key for VAULT_NAME:$VAULT_NAME SSH_CFG:$SSH_HOST:$SSH_PORT..."
    GET_SSH_HOST_KEY_RESPONSE=$(curl -s -k -u "$ADMIN:$PASSWORD" --header "$HTTP_HEADER" -X "GET" "$GET_SSH_HOST_KEY?ssh_host=$SSH_HOST&port=$SSH_PORT")
    if [ "$?" -ne 0 ]; then
		echo "Error in GET_SSH_HOST_KEY_RESPONSE!"
        exit
	fi
    NEW_SSH_HOST_KEY=$(echo "$GET_SSH_HOST_KEY_RESPONSE" | "$jq" -r '.Host.hkey')

    # Verify before update
    echo -e "{ \"VAULT_ID\": \"$VAULT_ID\", \"SSH_HOST\": \"$SSH_HOST\", \"SSH_PORT\": $SSH_PORT, \"NEW_HOST_KEY\":\"$NEW_SSH_HOST_KEY\"}" | "$jq"
    
    echo
    read -u 3 -p "Continue and update crdvlt with above details (y/n)? " choice
    case "$choice" in 
    y|Y ) 
        # Update vault with new ssh host key
        echo -e "Updating vault with the new ssh host key..."
        PUT_VAULT_BODY="{ \"Vault\": { \"CFG\": { \"SSH\": { \"host\": \"$SSH_HOST\", \"port\": \"$SSH_PORT\", \"hkey\": \"$NEW_SSH_HOST_KEY\" }}}}"
        PUT_VAULT_RESPONSE=$(curl -s -k -u "$ADMIN:$PASSWORD" --header "$HTTP_HEADER" -X "PUT" -d "$PUT_VAULT_BODY" "$PUT_VAULT/$VAULT_ID")
        if [ "$?" -ne 0 ]; then
            echo "Error in PUT_VAULT_RESPONSE!"
            exit
            else echo $PUT_VAULT_RESPONSE | jq '"\(.status) \(.message)"'
        fi
        ;;
    n|N ) echo "no - skipping";;
    * ) echo "invalid - skipping";;
    esac

done } 3<&0

echo -e "\nFinished."
exit 0