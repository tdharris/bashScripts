#!/bin/bash

read -e -p "initial grep pattern: " initialPattern
read -e -p "logfile: " logfile
#initialPattern="U273672"
#logfile="ag-edir-02_httpheaders2017-04-19-1492589401"

eventids=$(grep "$initialPattern" "$logfile" | awk '{ print $4 }' | cut -d ':' -f2 | sort -u)

for eventid in $eventids; do
  echo -e "\neventid: $eventid"
  grep "$eventid" "$logfile"
  echo -e "-----------------------------------------"
done

exit 0
