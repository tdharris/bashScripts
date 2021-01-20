#!/bin/bash
server=''
port=''

[[ -z "$server" || -z "$port" ]] && echo -e "\nERROR: Missing server or port, please provide values in script.\n" && exit 1

echo -e "\n$server:$port\n"

function simpleSFTPConnect {
  echo "Connecting as $user@$server:$port ..."
  sftp -P $port $user@$server
}

function expectSFTPConnect {
  echo "Connecting as $user@$server:$port ..."
  ./lib/spawnSFTPSession.sh $server $port $user $password
}

# Prompt for credentials
while read -p "Username: " user && [[ -z "$user" ]]; do
  echo -e "No blank username!\n"
done

if ! command -v expect &>/dev/null; then
  echo -e "\nCan't find expect binary, connecting with simple sftp..."
  simpleSFTPConnect
else
  while read -s -p "Password: " password && [[ -z "$password" ]]; do
    echo -e "No blank password!\n"
  done
  echo -e "\n\nFound expect binary, connecting with expect sftp script: ./lib/spawnSFTPSession.sh..."
  expectSFTPConnect
fi
