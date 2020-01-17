#!/bin/bash

# user input
echo
read -e -p "File: " file
if [ ! -f "$file" ]; then
  echo "File does not exist! $file" && exit 2
fi

# variables
tmpDir="/tmp"
convertFileFormat="csv"
column_completedDate=16
dateLastRunFile="/tmp/kcs-parse-courseCompletionReport-dateLastRun.txt"
dateLastRunFormat="+%Y-%m-%d"
interestedColumns="3,4,8,9,14,15,16"

# determine filename
fileName=$(basename "$file")
fileNameWithoutExt="${fileName%.*}"
convertedFile="/tmp/$fileNameWithoutExt.$convertFileFormat"
echo -e "\nExpected converted filename: $convertedFile"

# convert xlsx to csv
echo -e "\nConverting $file to $convertFileFormat ..."
libreoffice --headless --convert-to "$convertFileFormat" --outdir "$tmpDir" "$file"
if [ $? -ne 0 ]; then
  echo "Missing dependency libreoffice!" && exit 2;
fi

ls -lh "$convertedFile" &>/dev/null
if [ $? -ne 0 ]; then
  echo -e "\nFailed to convert file!" && exit 1
fi

# grab table section
report=$(sed -n '/^,,,,,,,,,,,,,,,,,,/,/^,,,,,,,,,,,,,,,,,,/p' "$convertedFile")
report=$(echo "$report" | sed 's/^,,,,,,,,,,,,,,,,,,//g')

# when is the last time this report was ran?
echo -e "\nParsing dates..."
if [ ! -f "$dateLastRunFile" ]; then
  echo -e "dateLastRunFile not found, creating it: $dateLastRunFile"
  echo $(date -d 2017-01-01 "$dateLastRunFormat") > "$dateLastRunFile"
fi
dateRaw=$(cat "$dateLastRunFile")
dateLastRun=$(date -d "$dateRaw" +%s)
echo -e "dateRaw: $dateRaw\ndateLastRun: $dateLastRun"

# are there any completions since last time?
echo -e "\nParsing and comparing dates from report, the following is a csv report of new completions:\n"
echo "$report" | sed -n '2p' | cut -d, -f "$interestedColumns"

newCompletions="/tmp/newCompletions.txt"
if [ -f "$newCompletions" ]; then
  rm "$newCompletions"
fi

i=0
echo "$report" | while read line ; do
  ((i = i + 1))
  completion=$(echo "$line" | cut -d , -f"$column_completedDate")

  # skip blank
  if [ -z "$completion" ]; then
    continue
  fi

  # ignore bad parse
  parsedDate=$(date -d "$completion" +%s 2>/dev/null)
  if [ $? -ne 0 ]; then
    #echo -e "--\nskipping bad date parse: $completion\n--"
    continue
  fi

  if [ $parsedDate -ge $dateLastRun ]; then
    echo -e "$line" | cut -d, -f "$interestedColumns"
  fi

done

echo $(date "$dateLastRunFormat") > "$dateLastRunFile"

exit 0
