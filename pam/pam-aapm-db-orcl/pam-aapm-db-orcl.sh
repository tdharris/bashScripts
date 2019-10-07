#!/bin/bash

# Configuration
pamServer='api_server'
pamAppl="pam_application_name"
emailid="user@domain.com"
apiKey="API TOKEN"
pamdbConnector='server:port'

# Checkout
echo -e "\n1) Checkout result of PAM application $pamAppl:\n"
co_result=$(curl -s --insecure -X POST -H "Authorization:Token token=$apiKey" -H "Cache-Control: no-cache" -H "Content-Type:application/json" -d '{
        "Request": {
                     "type": "PasswordCheckout",
                     "runHost": "'"$pamAppl"'",
                     "reason": "Need Oracle DB access",
                     "duration": 360,
                     "emailid": "'"$emailid"'"
        }
}' 'https://'$pamServer'/rest/cmdctrl/Request')

echo "$co_result" | jq .

co_requestid=$(echo "$co_result" | jq '.CheckOut.Request.id' | sed 's/"//g')
co_account=$(echo "$co_result" | jq '.CheckOut.account' | sed 's/"//g')
co_passwd=$(echo "$co_result" | jq '.CheckOut.passwd' | sed 's/"//g')

#echo "Request id: $co_requestid"
#echo "Account: $co_account"
#echo "Password: $co_passwd"

# Execute db query
echo -e "\n2) Connect to db $pamdbConnector and execute query:\n"
echo "docker run -i --rm oracle/instantclient:19 sqlplus $co_account/$co_passwd@$pamdbConnector AS SYSDBA ..."
docker run -i --rm oracle/instantclient:19 sqlplus $co_account/$co_passwd@$pamdbConnector AS SYSDBA <<EOF
SELECT
    EMPLOYEE_ID,
    NAME,
    HIRE_DATE,
    JOB_ID,
    DEPARTMENT_ID
FROM EMPLOYEES
WHERE HIRE_DATE >= '01-AUG-19';
EOF

# Checkin
echo -e "\n3) Checkin credential:\n"
ci_result=$(curl -s --insecure -X PUT -H "Authorization:Token token=$apiKey" -H "Cache-Control: no-cache" -H "Content-Type:application/json" -d '{
        "Request": {
                      "type":"PasswordCheckin",
                      "id":"'"$co_requestid"'",
                      "runHost": "'"$pamAppl"'"
        }
}' 'https://'$pamServer'/rest/cmdctrl/Request')

echo $ci_result | jq .

exit 0
