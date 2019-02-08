#!/bin/bash
clear; echo

read -ep " TO: " TO
read -ep " FROM: " FROM
read -ep " SUBJECT: " SUBJECT
read -ep " MESSAGE: " MESSAGE
read -ep " How many? " NUMBER

for (( i=1; i<=$NUMBER; i++ )); 
do 
	echo -e "$MESSAGE" | mail -s "$SUBJECT #$i" -r "$FROM" "$TO"; 
done

if [ $? -eq 0 ]; then
	# echo -e "\nTO: $TO\nFROM: $FROM\nSUBJECT: $SUBJECT\nMESSAGE: $MESSAGE"
	echo -e "\nFinished."; exit 0
else echo -e "\nThere was a problem..."; exit 1
fi