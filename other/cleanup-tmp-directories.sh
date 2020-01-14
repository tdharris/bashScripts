#!/bin/bash

# cleanup files older than 90 days
find /wrk/tmp -mtime +90 -type f -delete
find /wrk/public/tmp -mtime +90 -type f -delete

# cleanup empty directories
find /wrk/tmp -type d -empty -delete 
find /wrk/public/tmp -type d -empty -delete

exit 0
