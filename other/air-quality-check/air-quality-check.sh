#!/bin/bash

# Configuration
recipients="tyler.harris@microfocus.com,andrew.santos@microfocus.com"

passConditions="rgb(0,228,0)\|rgb(255,255,0)"
url="https://air.utah.gov/currentconditions.php?id=ln"
conditionBoxFilter="class=\"pm25"

# Dependencies
sendmailPath="/usr/sbin/sendmail"

if ! [ -x "$(command -v $sendmailPath)" ]; then
  echo 'Error: sendmail is not installed.' >&2
  exit 1
fi

# Process
result=$(curl "$url" | grep "$conditionBoxFilter" | grep -o "background-color:.*;")
if [ "$?" -ne 0 ]; 
  then echo "Failed to connect or parse current conditions!"
  exit 1
fi

echo "$result" | grep "$passConditions"
if [ "$?" -eq 0 ]; 
  then echo "Today is a fine day. :)"
else 
  # Send alert
  echo "Notifying $email..."
  echo -e "Subject: ALERT! Bad Air Quality Conditions in Utah County \n\n$url\n" | $sendmailPath -v "$recipients"
  if [ $? -eq 0 ]; then
    echo "Successfully notified recipient(s)."
    exit 0
  else
    echo "Failed to notify recipient(s)!"
  fi
fi

exit 0
