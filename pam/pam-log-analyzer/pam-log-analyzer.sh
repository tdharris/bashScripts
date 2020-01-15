#!/bin/bash
echo
# Prompt for user input
#log="/wrk/mnt/t5/logs/unifid.log"
#user="User2"

read -e -p "Log file: " log
if [ ! -f "$log" ]; then echo "File doesn't exist: $log." && exit 1; fi

read -p "Username: " user
if [ -z "$user" ]; then echo "Username is required." && exit 1; fi

# Variables
DEBUG=false
filter_cmdctrl="Error\|Warning\|process rules:\|cmdctrl request\|cc_authorize\|checkauth\|prvcrdvlt getCredential\|prvcrdvlt getVault\|process_rules"
filter_auth="Error,\|Warning\|Logging on user\|SecAuthCfg\|spf_peer connect\|Connecting\|Logon process start\|Secondary login\|Authentication status\|auth login\|LDAP mapping\|getUserSecAuthMethods\|auth doSecAuth"
ignore_errors="Failed to parse utf8 in parser_deserialize.*Error : 70014\|SSL Error: error:14094416:SSL routines:ssl3_read_bytes:sslv3 alert certificate\|Message occurred.*times"

# Find most recent instance of logon
startLogon=$(cat "$log" | grep -n "Logging on user $user" | tail -n1)
startLine=$(echo "$startLogon" | cut -d : -f1)
endLine=$(cat "$log" | grep -n "cmdctrl request" | tail -n1 | cut -d : -f1)
threadid=$(echo "$startLogon" | cut -d , -f4)

if $DEBUG; then
  echo "startLogon: $startLogon"
  echo "startLine: $startLine"
  echo "endLine: $endLine"
  echo "threadid: $threadid"
fi

sedExpression=$(echo "$startLine","$endLine"p)
content=$(sed -n "$sedExpression" "$log")

# Report
function showHeader {
  echo -e "\n$lines\n $1\n$lines"
}

lines="---------------------------------------------------------------------"
echo -e "\n$lines\n\n PAM Log Parser Report\n\n$lines"
echo "log: $log"
echo "user: $user"

showHeader "Authentication"
echo "$content" | grep "$filter_auth" | grep -v "$ignore_errors"
echo -e "\n--\nIdentity:"
echo "$content" | awk '/Identity: <Identity>/,/<\/Identity>/'
echo -e "\n--\nBlocked Users:"
echo "$content" | awk '/USER GROUP - BLOCKED USERS/,/<\/spf>/'

showHeader "Authentication - 2FA (e.g. AA)"
echo "$content" | awk '/Logon process start - Response/,/<\/o.n.NULL>/{print NR, "\t", $0}'
echo
echo "$content" | awk '/start logon -/,/<\/aaresponse>/{print NR, "\t", $0}'
echo
echo "$content" | awk '/Secondary login - Response/,/<\/o.n.NULL>/{print NR, "\t", $0}'
echo
echo "$content" | awk '/Methods -/,/<\/aaresponse>/{print NR, "\t", $0}'

showHeader "Authorization cmdctrl"
echo "$content" | grep "$filter_cmdctrl" | grep -v "$ignore_errors"

echo -e "\n--\ncmdctrl rule matches:\n"
echo "$content" | grep 'checkauth: log' | tail -n1 | cut -d "<" -f2- | sed 's/^/</' | xmllint --format - | grep 'b.matched="1"' | grep -v 'disabled="1"' | sed G

showHeader "Audit"
echo "$content" | awk '/Audit Message :/,/<\/Audit>/'

exit 0
