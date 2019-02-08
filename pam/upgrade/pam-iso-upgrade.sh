#!/bin/bash
#
# NetIQ Privileged Account Manager
# Publish packages from ISO to Package Manager
# https://www.netiq.com/documentation/privileged-account-manager-3/npam_install/data/bjjnusa.html
# Author: Tyler Harris <tyler.harris@microfocus.com>

# script variables
tmp="/tmp/framework"
mnt="/mnt/pam"
fileToPublishFromISO="Package_Manager/netiq-npam-packages-*.tar.gz"
frameworkAdmin="admin"
cleanup=true
######################

# Prompt for iso
echo -e "\nPublish packages to the Package Manager.\n"
read -ep "Path to PAM iso: " isofile

# Mount .iso file
echo -e "\nMounting iso file $isofile..."
if [[ $(echo ${isofile##*.} | grep -i 'iso') -ne 0 ]]; then
  echo "$isofile is not an iso file. Extension needs to be .iso."
  exit 1
  else 
    sudo umount "$mnt" 2>/dev/null
    sudo rm -r "$mnt" 2>/dev/null
    sudo mkdir -p "$mnt"
    sudo mount -o loop "$isofile" "$mnt"
    if [ $? -ne 0 ]; then
      echo -e "There was a problem mounting the .iso file: $isofile\n"
    else echo -e "Successfully mounted $isofile to $mnt\n"
    fi
fi

# Extract fileToPublish from mounted iso
echo -e "\nExtracting packages from mounted iso..."
sudo rm -r "$tmp" 2>/dev/null
sudo mkdir -p "$tmp"
fileToExtract=`sudo ls -1 $mnt/$fileToPublishFromISO | head -n1` # get filename to extract
if [[ -z "$fileToExtract" ]]; then
  echo "Unable to determine file to extract: $fileToPublishFromISO"
  sudo ls -1 $mnt/$fileToPublishFromISO
  exit 1
else
  sudo tar -xvf "$fileToExtract" -C "$tmp"
  sudo ls -lh "$tmp"
fi

# publish to local package manager
echo -e "\nPublishing packages to local package manager..."
/opt/netiq/npum/sbin/unifi -u $frameworkAdmin distrib publish -d "$tmp"
if [ $? -ne 0 ]; then
  echo -e "\nThere was a problem publishing packages to the Package Manager.\n"
else 
  echo -e "\nSuccessfully published packages to the Package Manager.\n"
  echo -e "Please visit the Hosts Console to install new or upgrade existing packages and/or upgrade agents.\nFor more details, please see documentation for upgrade instructions.\n"
fi

# cleanup
if $cleanup; then
  sudo umount "$mnt" 2>/dev/null
  sudo rm -r "$tmp" 2>/dev/null
fi

exit 0
