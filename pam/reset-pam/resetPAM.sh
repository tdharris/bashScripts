#!/bin/bash

# Variables
BACKUP_DIR="/tmp/pam-backup"
APP_DIR="/opt/netiq/npum"
AUDIT_DIR="$APP_DIR/service/local/audit"

echo -e "Backup directory: $BACKUP_DIR\nPAM directory:$APP_DIR\nAudit directory: $AUDIT_DIR\n--\n"

# Stop PAM
echo "Stopping PAM Service, this may take some time, so please be patient..."
service npum stop
if [ $? -eq 0 ]; then
  echo -e "Done.\n"
  else echo "[ERROR] Problem stopping PAM Service..." && exit 1
fi

# Create required directories
# 'mkdir -p' will create directories/sub-directories if they don't already exist,
# starting with parent and moving down.
echo "Creating backup directories..."
mkdir -pv "$BACKUP_DIR/"{logs,audit}
mkdir -pv "$BACKUP_DIR/audit/video/capture"
echo -e "Done.\n"

# Backup operation
echo "Starting backup..."
mv -v $APP_DIR/logs/*.log "$BACKUP_DIR/logs"
mv -v $AUDIT_DIR/*.db "$BACKUP_DIR/audit"
mv -v $AUDIT_DIR/video/capture/* "$BACKUP_DIR/audit/video/capture"
echo -e "Done.\n"

# Start PAM
service npum start
if [ $? -eq 0 ]; then
  echo -e "Done.\n"
  else echo "[ERROR] Problem starting PAM Service..." && exit 1
fi

ls -lhR "$BACKUP_DIR"

exit 0
