#!/bin/bash
##################################################################################################
#
# v1.0.0
# Example PAM script to register an agent
# https://github.com/tdharris/bashScripts/tree/master/pam/pam-register-agent
# 
# by Tyler Harris
#
##################################################################################################

# Configuration Options
# Change dry_run to false to register agent
dry_run=true
manager=""
manager_port=29120
manager_username=""
manager_password=""
pam_install_path="/opt/netiq/npum"
# (Optional) If you want to register an agent to a domain, you must specify the domain path 
# in the format /Domain/SubDomain1/SubDomain2
agent_opt_domain_path=""

pam_unifi="$pam_install_path/sbin/unifi"
# Verify configured PAM install path
if [ ! -f "$pam_unifi" ]; then
    echo "ERROR: Unable to find unifi binary in configured PAM Install Path: $pam_unifi"
    exit 1
fi

function checkResult {
    local code="$1"
    local exitOnErr="$2"
    local errMessage="$3"
    local showSuccess="$4"
    local successMessage="$5"

    if [ "$code" -ne 0 ]; then
        echo -e "\nERROR: $errMessage\n"
        if [ "$exitOnErr" = true ]; then
            exit $code
        fi
        else if [ "$showSuccess" = true ]; then 
            echo -e "OK: $successMessage" 
        fi
    fi
}

# Retrieve hostname
agent_hostname=$(hostname)
checkResult $? true "not able to detect hostname" true "detected hostname $agent_hostname"

# Is detected hostname resolvable?
agent_ip=$(nslookup "$agent_hostname" | awk '/^Address: / { print $2 }')
checkResult $? true "$agent_hostname is not resolvable by dns." true "$agent_hostname is resolvable." 

# Is the resolved ip bound to this server?
agent_interfaces=$(ip address show | awk '/inet / {split($2,var,"/*"); print $7,":",var[1]}')
agent_resolved_interface=$(echo "$agent_interfaces" | grep "$agent_ip")
checkResult $? true "Resolved hostname:$agent_hostname to ip:$agent_ip, yet ip is not bound to any interfaces:\n$agent_interfaces" true "ip resolved to interface: $agent_resolved_interface"

# Verify if any variables are empty (just in case)
if [[ -z $manager || -z $manager_port || -z $agent_ip || -z $agent_hostname || -z $manager_username || -z $manager_password ]]; then
    echo "ERROR: One or more variables are undefined." && exit 1
fi

agent_name="$agent_hostname"
if [ ! -z "$agent_opt_domain_path" ]; then
    # Prepend domain path to agent name and remove any repeated "/" characters in a row
    agent_name=$(echo "$agent_opt_domain_path/$agent_hostname" | tr -s '/')
fi

# Show arguments
arguments="$manager $manager_port $agent_ip $agent_name $manager_username $manager_password 0"
echo -e "\nThis host will be registered to PAM Manager with the following arguments:\n$arguments\n"

if [ "$dry_run" = true ]; then
    echo "INFO: Skipping registration since dry_run: $dry_run"
    else
        # Register host
        "$pam_unifi" regclnt register $arguments
        checkResult $? true "Failed to register host." true "Host registration successful."
fi

exit 0