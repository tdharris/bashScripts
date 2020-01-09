#!/bin/bash

# Configuration
base_dir="/opt/netiq/npum"
strfwd_dir="$base_dir/service/local/strfwd"
file_size="+2G"
clear

echo "Discovering large strfwd logs..."
find . -type f -name "audit_*.MSQ.tmp" -size "$file_size" -print0 | while read -d $'\0' file
do

 echo -e "\nDetected large audit file:"
 ls -lh $file
 filename=$(basename $file)

 # determine audit id from filename 'audit_<respective audit manager UID>.MSQ.tmp'
 # involves some parsing:
 # + converts to -
 # _ converts to /
 # = is appended
 rawId=$(echo $filename | sed 's/audit_//' | sed 's/.MSQ.tmp//')
 parsedId=$(echo $rawId | sed 's/+/-/g' | sed 's/_/\//g')
 parsedId+="="
 echo -e "\nrawId: $rawId"
 echo "parsedId: $parsedId"

 # Fetch host info by service id
 echo -e "\nService:" 
 service=$(sqlite3 "$base_dir/service/local/registry/registry.db" "select id, name, host from Service where id='$parsedId';")
 if [ -z "$service" ]; then
  echo "Unable to determine service."
  else echo -e "id,name,host\n$service"
 fi
 echo -e "--"

done

echo "Finished."
