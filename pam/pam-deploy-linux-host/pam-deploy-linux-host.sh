#!/bin/bash
#
# Deploy PAM to linux server for internal lab
# by Tyler Harris
#

# Variables
# Enable/Disable
DRY_RUN=true
ENABLE_OS_CHECK=true
ENABLE_MOUNT=true
ENABLE_CREATE_USERS=true
ENABLE_TIME_SYNC=true
ENABLE_FIREWALL_CHECK=true
ENABLE_PAM_INSTALL=true

# Other
PAM_INSTALL_PATH="/opt/netiq/npum"
PAM_UNIFI="$PAM_INSTALL_PATH/sbin/unifi"
MOUNT_TARGET="/mnt/wrk"
MOUNT_SOURCE="fileServer:/wrk"
MOUNT_OPTIONS="nfs defaults 0 0"
LOCAL_USERS="localuser,admin"
LOCAL_USER_PASSWORD="defaultpassword"
PAM_SHELL="/usr/bin/cpcksh"
TIME_SYNC_SERVER="default.timeserver"
FIREWALL_PORTS="29120\|22\|2222\|13389"
INSTALL_SOURCE_DIR="$MOUNT_TARGET/public/outgoing/pam/download"

# Colors
DEFAULT="\e[0m"
GREEN="\e[32m"
RED="\e[31m"
PURPLE="\e[35m"
YELLOW="\e[93m"

# Functions
function PRINT_TITLE {
    echo -e "\n--\n"$PURPLE"$1."$DEFAULT
}

function askYesOrNo {
    REPLY=""
    while [ -z "$REPLY" ] ; do
        read -ep "$1 $YES_NO_PROMPT" -n1 REPLY
        REPLY=$(echo ${REPLY}|tr [:lower:] [:upper:])
        case $REPLY in
            $YES_CAPS ) return 0 ;;
            $NO_CAPS ) return 1 ;;
            * ) REPLY=""
        esac
    done
}

function CHECK_DRY_RUN {
    if $DRY_RUN; then 
        echo -e $YELLOW"WARNING"$DEFAULT": Skipping due to DRY_RUN"
        return 1
    else
        return 0
    fi
}

# Initialize the yes/no prompt
YES_STRING=$"y"
NO_STRING=$"n"
YES_NO_PROMPT=$"[y/n]: "
YES_CAPS=$(echo ${YES_STRING}|tr [:lower:] [:upper:])
NO_CAPS=$(echo ${NO_STRING}|tr [:lower:] [:upper:])

# Procedure

# Determine OS Platform
if $ENABLE_OS_CHECK; then
    PRINT_TITLE "Checking OS Platform"
    lowercase(){
        echo "$1" | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/"
    }

    OS=`lowercase \`uname\``
    KERNEL=`uname -r`
    MACH=`uname -m`

    if [ "{$OS}" == "windowsnt" ]; then
        OS=windows
    elif [ "{$OS}" == "darwin" ]; then
        OS=mac
    else
        OS=`uname`
        if [ "${OS}" = "SunOS" ] ; then
            OS=Solaris
            ARCH=`uname -p`
            OSSTR="${OS} ${REV}(${ARCH} `uname -v`)"
        elif [ "${OS}" = "AIX" ] ; then
            OSSTR="${OS} `oslevel` (`oslevel -r`)"
        elif [ "${OS}" = "Linux" ] ; then
            if [ -f /etc/redhat-release ] ; then
                DistroBasedOn='RedHat'
                DIST=`cat /etc/redhat-release |sed s/\ release.*//`
                PSUEDONAME=`cat /etc/redhat-release | sed s/.*\(// | sed s/\)//`
                REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
            elif [ -f /etc/SuSE-release ] ; then
                DistroBasedOn='SuSe'
                DIST=`cat /etc/os-release | grep '^NAME' | sed 's/"//g' | sed 's/.*=//'`
                PSUEDONAME=`cat /etc/os-release | grep 'PRETTY_NAME' | sed 's/"//g' | sed 's/.*=//'`
                REV=`cat /etc/os-release | grep 'VERSION_ID' | sed 's/"//g' | sed 's/.*=//'`
            elif [ -f /etc/mandrake-release ] ; then
                DistroBasedOn='Mandrake'
                PSUEDONAME=`cat /etc/mandrake-release | sed s/.*\(// | sed s/\)//`
                REV=`cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//`
            elif [ -f /etc/debian_version ] ; then
                DistroBasedOn='Debian'
                DIST=`cat /etc/lsb-release | grep '^DISTRIB_ID' | awk -F=  '{ print $2 }'`
                PSUEDONAME=`cat /etc/lsb-release | grep '^DISTRIB_CODENAME' | awk -F=  '{ print $2 }'`
                REV=`cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F=  '{ print $2 }'`
            fi
            if [ -f /etc/UnitedLinux-release ] ; then
                DIST="${DIST}[`cat /etc/UnitedLinux-release | tr "\n" ' ' | sed s/VERSION.*//`]"
            fi
            OS=`lowercase $OS`
            DistroBasedOn=`lowercase $DistroBasedOn`
            readonly OS
            readonly DIST
            readonly DistroBasedOn
            readonly PSUEDONAME
            readonly REV
            readonly KERNEL
            readonly MACH
        fi
    fi
    echo "$DistroBasedOn, $DIST $REV"
fi

# Mount wrk dire# Setup share(s) on new Linux environment
if $ENABLE_MOUNT; then
    PRINT_TITLE "Validating mount $MOUNT_SOURCE."
    if mountpoint -q "$MOUNT_TARGET"; then
        echo "$MOUNT_TARGET already mounted."
    else
        echo "Attempting to mount $MOUNT_TARGET"

        if CHECK_DRY_RUN; then
            mkdir -p "$MOUNT_TARGET"
            echo "$MOUNT_SOURCE $MOUNT_TARGET $MOUNT_OPTIONS" >> /etc/fstab
            mount "$MOUNT_TARGET"
            if [ $? -eq 0 ]; then 
                echo "Added mount(s) successfully."
            else
                echo "Failed to add mount(s)."
            fi
        fi
    fi
fi

# Create Users (local)
if $ENABLE_CREATE_USERS; then
    PRINT_TITLE "Creating local users"
    echo "$LOCAL_USERS" | tr ',' '\n' | while IFS=, read user
    do
        echo -e "\nCreating user $user"
        if CHECK_DRY_RUN; then
            useradd -s $PAM_SHELL $user
            echo -e "$LOCAL_USER_PASSWORD\n$LOCAL_USER_PASSWORD" | passwd $user
            mkhomedir_helper $user
        fi
    done
fi

# Time Sync
if $ENABLE_TIME_SYNC; then
    PRINT_TITLE "Checking time synchronization"
    grep "novell.com" /etc/ntp.conf
    if [ $? -ne 0 ]; then 
        echo -e $YELLOW"WARNING"$DEFAULT": Timesync not setup!"
    fi
fi

# Firewall
if $ENABLE_FIREWALL_CHECK; then
    PRINT_TITLE "Checking firewall status"
    echo -e "\nfirewall state:"
    if [ "$DistroBasedOn" = "redhat" ]; then 
        FIREWALL_STATE=$(firewall-cmd --state)
        else
        echo -e "NOT SUPPORTED."
    fi
    echo $FIREWALL_STATE
    echo -e "\niptables:"
    iptables -S | grep $FIREWALL_PORTS
fi

# Install PAM
if $ENABLE_PAM_INSTALL; then
    INSTALLED=1
    PRINT_TITLE "Installing Privileged Account Manager (PAM)"

    echo -e "\nFinding PAM rpms available for install:"
    find $INSTALL_SOURCE_DIR -name "*.rpm"
    echo

    # Install rpm
    while true; do
        read -ep "Enter path of rpm to install: " rpm;
        if [ -f $rpm ]; then
            echo
            if askYesOrNo $"Proceed to install PAM?"; then
                if [ -d /opt/netiq/npum ]; then 
                    if askYesOrNo $"PAM directory already exists, are you sure?"; then
                        if CHECK_DRY_RUN; then
                            rpm -ihv $rpm
                            INSTALLED=$?
                        fi
                        else echo "Skipping PAM Install."
                    fi
                else
                   if CHECK_DRY_RUN; then
                        rpm -ihv $rpm
                        INSTALLED=$?
                    fi
                fi
                break
            fi
        else echo -e "File does not exist.\n"
        fi
    done

    # Register host
    PRINT_TITLE "Registering host"
    if [[ $INSTALLED -ne 0 && ! $DRY_RUN ]]; then
        echo -e "Problem with installation."
        exit 1
    fi
    echo "Proceeding with registration..."
    if [ ! -f "$PAM_UNIFI" ]; then
        echo $YELLOW"ERROR"$DEFAULT": Unable to find unifi binary in configured PAM Install Path: $PAM_UNIFI"
        exit 1
    fi
    # Register host
    if CHECK_DRY_RUN; then
        "$pam_unifi" regclnt register
    fi

    echo -e "\n--\n\nDone."

fi
