#!/bin/bash
serverAddress="localhost:21"
sClientOpts="-starttls ftp"

# Fetch certificate expiration date
certExpires=$(echo | openssl s_client -connect $(echo "$serverAddress") $(echo "$sClientOpts") 2>/dev/null | openssl x509 -noout -dates 2>/dev/null | grep 'notAfter' | cut -d = -f2-)
expirationTime=$(date -d "$certExpires" +%s)
currentTime=$(TZ=GMT date +%s)

# Check expiration
if [ $expirationTime -le $currentTime ]; then
  # certificate expired, likely has been renewed, restart vsftpd to pickup renewed cert
  systemctl restart vsftpd
  exit $?
fi
