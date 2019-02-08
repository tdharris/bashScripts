#!/bin/bash

find . -type f | rev | cut -d'.' -f 1 | rev | sort | uniq -c | sort

#- it grabs all files in current directory recursively down (I think..)
#- reverses the string
#- grabs the characters until it finds the first '.'
#- reverses it back to normal
#- sorts the filetypes
#- uniq count of each now that it's sorted
#- then sorts that list so largest is on bottom
