#!/bin/bash
bash_aliases="/path/to/.bash_aliases"
public_key="/path/to/.ssh/id_ed25519.pub"

# Colors
DEFAULT="\e[0m"
GREEN="\e[32m"
RED="\e[31m"
PURPLE="\e[35m"
YELLOW="\e[93m"

# Validate
if [[ ! ( -f "$bash_aliases" && -f "$public_key" ) ]]; then
    echo -e "\n$RED ERROR $DEFAULT: Missing file.\n" && exit 1
fi

# Define prompt User for Yes/No
function askYesOrNo {
	REPLY=""
	while [ -z "$REPLY" ] ; do
		read -ep "$1 $YES_NO_PROMPT" REPLY
		REPLY=$(echo ${REPLY}|tr [:lower:] [:upper:])
		case $REPLY in
			$YES_CAPS ) return 0 ;;
			$NO_CAPS ) return 1 ;;
			$CANCEL_CAPS) exit;;
			* ) REPLY=""
		esac
	done
}
YES_STRING=$"y"
NO_STRING=$"n"
CANCEL_STRING=$"c"
YES_NO_PROMPT=$"[y/n/c]: "
YES_CAPS=$(echo ${YES_STRING}|tr [:lower:] [:upper:])
NO_CAPS=$(echo ${NO_STRING}|tr [:lower:] [:upper:])
CANCEL_CAPS=$(echo ${CANCEL_STRING}|tr [:lower:] [:upper:])

# START
# Get a list of servers to ssh-copy-id to
servers=$(cat ~/.bash_aliases | grep 'ssh' | sed 's/alias.* //' | sed 's/"//' | sort | uniq)

echo -e "Detected servers from $bash_aliases:\n\n$servers\n"
if askYesOrNo "Continue to ssh-copy-id $public_key to the above servers?"; then
    # Copy the ssh-key
    for server in $servers; do
        echo -e "\n$server"
        ssh-copy-id -i $public_key $server
        if [ $? -ne 0 ]; then 
            echo -e "$RED ERROR $DEFAULT";
            else echo -e "$GREEN SUCCESS $DEFAULT"
        fi
        echo -e "\n--"
    done
fi

exit 0
