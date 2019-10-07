#!/bin/bash
##################################################################################################
# 
# v1.0.0
# Example PAM Application to Application Password Management script (AAPM) with DB Monitoring
# - Check-out an application credential for an oracle database using an authorized api key
# - Executes a sql query using docker oracle instantclient with the checked out credential
#   through a PAM DB Connector so the session is monitored.
# - Check-in credential
#
# by Tyler Harris
#
##################################################################################################

# Configuration
DEBUG=false
jq="jq"

# PAM Configuration
pamServer='api_server'
pamAppl="pam_application_name"
emailid="user@domain.com"
apiKey="API TOKEN"
pamdbConnector='server:port'

# Docker Oracle Client Configuration
dockerImage="oracle/instantclient:19"
sqlRunAs="AS SYSDBA"
sqlQuery="SELECT
    EMPLOYEE_ID,
    NAME,
    HIRE_DATE,
    JOB_ID,
    DEPARTMENT_ID
FROM EMPLOYEES
WHERE HIRE_DATE >= '01-AUG-19';"

###########################
#
# Operation below..
#
###########################
def='\e[0m' # No Color - default
red='\e[91m' # Red
green='\e[92m' # Green

# Verify Dependencies
if [[ ! -x $(command -v "$jq") ]]; then
	echo -e "Failed library dependency: jq\nPlease install in '$jq': https://stedolan.github.io/jq/"
	exit 1
fi

function checkResult {
    local code="$1"
    local desiredCode="$2"
    local message="$3"
    local showSuccess="$4"

    if [ "$code" -ne "$desiredCode" ]; then
        echo -e "\n${red}Error${def}: $message\n" && exit $code
        else if [ "$showSuccess" = true ]; then
		echo -e "${green}Success${def}.\n"
	fi
    fi
}

# 1) Checkout
echo -e "\n1) Check-out result of PAM application $pamAppl:\n"
co_result=$(curl -s --insecure -X POST -H "Authorization:Token token=$apiKey" -H "Cache-Control: no-cache" -H "Content-Type:application/json" -d '{
    "Request": {
        "type": "PasswordCheckout",
        "runHost": "'"$pamAppl"'",
        "reason": "Need Oracle DB access",
        "duration": 360,
        "emailid": "'"$emailid"'"
    }
}' 'https://'$pamServer'/rest/cmdctrl/Request')
checkResult "$?" 0 "Failed to connect to $pamServer"

# Handle and parse response
echo "$co_result" | jq .
checkResult "$?" 0 "Failed to parse check-out response!"
co_status=$(echo "$co_result" | jq '.status')
checkResult $co_status 200 "Failed to check-out credential!" true
co_requestid=$(echo "$co_result" | jq '.CheckOut.Request.id' | sed 's/"//g')
co_account=$(echo "$co_result" | jq '.CheckOut.account' | sed 's/"//g')
co_passwd=$(echo "$co_result" | jq '.CheckOut.passwd' | sed 's/"//g')

if [ "$DEBUG" = true ]; then
    echo -e "\nParsed variables from check-out response.."
	echo "Request id: $co_requestid"
	echo "Account: $co_account"
	echo "Password: $co_passwd"
fi

# 2) Execute db query
echo -e "\n2) Connect to db $pamdbConnector and execute query:\n"
dockerCommand="sqlplus $co_account/$co_passwd@$pamdbConnector $sqlRunAs"
echo -e "docker run -i --rm $dockerImage $dockerCommand <<EOF\n$sqlQuery\nEOF"
docker run -i --rm $dockerImage $dockerCommand <<EOF
$sqlQuery
EOF
checkResult "$?" 0 "Failed to connect to database!"

# 3) Check-in
echo -e "\n3) Check-in credential:\n"
ci_result=$(curl -s --insecure -X PUT -H "Authorization:Token token=$apiKey" -H "Cache-Control: no-cache" -H "Content-Type:application/json" -d '{
    "Request": {
        "type":"PasswordCheckin",
        "id":"'"$co_requestid"'",
        "runHost": "'"$pamAppl"'"
    }
}' 'https://'$pamServer'/rest/cmdctrl/Request')
checkResult "$?" 0 "Failed to connect to $pamServer"

# Handle and parse response
echo "$ci_result" | jq .
checkResult "$?" 0 "Failed to parse check-in response!"
ci_status=$(echo "$ci_result" | jq '.status')
checkResult $ci_status 200 "Failed to check-in credential!" true

exit 0
