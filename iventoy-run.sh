#!/usr/bin/env bash

###############################################
############ Author: Jonah Grasso #############
############### For System76 ##################
###############################################
########### iVentoy auto run script ###########
###############################################

FIRST_RUN=0
DATE=$(date '+%Y-%m-%d %H:%M:%S')
SCRIPT_PATH=$(pwd)
CURRENT_USER=$(whoami)
DEBUG=0
DBUG_LOG=1
LOG=1
LOG_DIR="$SCRIPT_PATH/system76-iventoy-log"
BASE_LOG_NAME="install"
DEBUG_LOG_NAME="debug"
LOG_EXT=".log"

Help()
{
    echo "Usage: iventoy-run.sh [options]"
    echo ""
    echo "Options:"
    echo "-f        For use with first run testing. Remove in a later commit."
    echo "-d        Run in debug mode."
}

while getopts ":fd" option; do
    case $option in
        f) # First run testing
            FIRST_RUN=1;;
        d) # Run in debug mode
            DEBUG=1;;
        *) # Invalid opt.
            echo "Error: invalid option." 1>&2
                Help 1>&2
            exit 1;;
    esac
done

# Change to first_run=0 once finished w/ testing
if [ "$FIRST_RUN" -eq 1 ]; then
    echo "Is this the first run? Make sure to use "-f"."
    sleep 5
    echo "Check if you can keep an IP assigned using the MAC addr. on router"
    echo "this will help with re-installs"
    exit 1
fi

# Setup incrementing debug logs
log_debug_setup()
{
    while [ -f "$LOG_DIR/$DEBUG_LOG_NAME-$DBUG_LOG$LOG_EXT" ]; do
        DBUG_LOG=$((DBUG_LOG + 1))
    done

    DEBUG_LOG_PATH="$LOG_DIR/$DEBUG_LOG_NAME-$DBUG_LOG$LOG_EXT"

#    if [ "$DBUG_LOG" -gt 1 ]; then
#        OLD="old-logs/installer"
#        OLD_LOG=1
#        
#        mkdir -p "$LOG_DIR/$DEBUG_OLD"
#        mv "$LOG_DIR/$BASE_LOG_NAME-"* "$LOG_DIR/$DEBUG_OLD"
#
#        while [ -f "$LOG_DIR/$DEBUG_OLD/$DEBUG_LOG_NAME-$LOG$LOG_EXT" ]; do
#           OLD_LOG=$((LOG + 1))
#        done
#   fi
}

log_debug_setup

# Debug
log_debug()
{
    if [ "$DEBUG" -eq 1 ]; then
        if [ ! -e "$DEBUG_LOG_PATH" ]; then
            touch "$DEBUG_LOG_PATH"
        fi
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$DEBUG_LOG_PATH"
}

# check if the log directory is made
inst_log_setup()
{
    LOG_MADE=0

    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
    else LOG_MADE=1
    fi

    while [ -f "$LOG_DIR/$INST_LOG_NAME-$LOG$LOG_EXT" ]; do
        LOG=$((LOG + 1))
    done

    INST_LOG_PATH="$LOG_DIR/$BASE_LOG_NAME-$LOG$LOG_EXT"

#    if [ -e "$ISNT_LOG_PATH" ]; then
#        OLD="old-logs/installer"
#        OLD_LOG="old1"
#
#        while [ -f "$LOG_DIR/$OLD/$INST_LOG_NAME-$LOG$LOG_EXT" ]; do
#            OLD_LOG=$((LOG + 1))
#        done
#
#        mv "$LOG_DIR/$INST_LOG_NAME-"* "$LOG_DIR/$INST_LOG_NAME-$OLD_LOG$LOG_EXT"
#
#        mkdir -p "$LOG_DIR/$OLD"
#        mv "$LOG_DIR/$INST_LOG_NAME-"* "$LOG_DIR/$OLD"
#    fi
#
#    touch "$INST_LOG_PATH"
   
    if [ "$LOG_MADE" -gt 1 ]; then
        log_debug "Old installer log moved to $LOG_DIR/old-logs"
        log_debug "Installer log created in $INST_LOG_PATH"
    else log_debug "Installer log created in $INST_LOG_PATH"
    fi
}

inst_log_setup

# Check if root
if [ "$CURRENT_USER"  = "root" ]; then 
    echo "Please do not run as root"
    exit 1
    # Get root permissions
    else sudo touch 1>&/dev/null
fi

# Check network status
NETWORK_CHECK=$(hostname -i)
NETWORK_FALSE="::1 127.0.0.2"

if [ "$NETWORK_CHECK" = "$NETWORK_FALSE" ]; then
    sudo dhclient
    if [ "$NETWORK_CHECK" = "$NETWORK_FALSE" ]; then
       echo "No network found. Please connect."
       exit 1
    fi
else log_debug "Network appears to be connected. $NETWORK_CHECK"
fi

# Check is openssh-server is installed. If not, install it.
# Then get the IP and write it to a file in the script's working dir
IP_PATH="$LOG_DIR/ip"
IP=$(hostname -i)
SSH_RUNNING=0
SSH_CHECK=$(sudo dpkg -s openssh-server | grep -i "install ok installed" 1>&/dev/null)
SYSCTL_CHECK=$(sudo systemctl status ssh | grep "(running)")
SYSCTL_MASK_CHECK=$(sudo systemctl status ssh | grep "masked")
SYSCTL_MASK=0

if [ -n "$SSH_CHECK" ]; then
    echo "Openssh-server is installed" >> "$INST_LOG_PATH"
    if [ ! "ls "/home/$USER/Desktop/ip"" ]; then
        touch $IP_PATH
        echo "$DATE $USER's IP: $IP" >> "$IP_PATH" 
        echo "$DATE $USER's IP: $IP" >> "$INST_LOG_PATH"
    fi
    # fix this
    log_debug "$DATE $USER: Path of "ip" $IP_PATH"
    log_debug "$DATE $USER's $IP:"
else sudo apt install openssh-server -y 1>&/dev/null
    log_debug "Openssh-server should be installed."
    if [ -n "$SSH_CHECK" ]; then
        echo "Openssh-server is now installed." >> "$INST_LOG_PATH"
    fi
fi

# Function to make below work... didn't think ahead and didn't want to re-write
sysctl_mask()
{
    # SYSCTL_MASK=0 means unmasked SYSCTL_MASK=1 is masked
    if [ "$SYSCTL_MASK_CHECK" = "masked" ]; then
        echo "SSH masked in systemctl. Unmasking"
        systemctl unmask ssh >> "$INST_LOG_PATH"
        if [ "$SYSCTL_MASK_CHECK" != "masked" ]; then
            echo "SSH is not masked in systemctl."
            SYSCTL_MASK=0
        else echo "Failed unmasking SSH." >> "$INST_LOG_PATH"
            SYSCTL_MASK=1
        fi
    fi
}

# Check if the SSH-server is running
if [ -n "$SYSCTL_CHECK" ]; then
    SSH_RUNNING=1
else SSH_RUNNING=0
fi

# If the SSH-server is running, this will do nothing except log the IP.
if [ "$SSH_RUNNING" -eq 1 ]; then
    log_debug "$DATE $USER: Path of "ip" $IP_PATH"
    log_debug "$DATE $USER's $IP:"
else sudo systemctl enable ssh >> "$INST_LOG_PATH"
    sudo systemctl start ssh >> "$INST_LOG_PATH"
    log_debug "$DATE $USER: Path of "ip" $IP_PATH"
    log_debug "$DATE $USER's $IP:"
    if [ "$SYSCTL_CHECK" != "(running)" ]; then
        echo "Checking if service is masked." >> "$INST_LOG_PATH"
        sysctl_mask
    fi
fi

# Just update IVENTOY_RELEASE with the latest. Should be fine :shrug:
IVENTOY_RELEASE="1.0.20"
IVENTOY_DIR="$SCRIPT_PATH/iventoy-$IVENTOY_RELEASE"
IVENTOY_TAR_PATH="$SCRIPT_PATH/iventoy-$IVENTOY_RELEASE-linux-free.tar.gz"
# After it is moved to the log folder
IVENTOY_TAR_PATH_AFTER="$LOG_DIR/iventoy-$IVENTOY_RELEASE-linux-free.tar.gz"
IVENTOY_GIT_LINK="https://github.com/ventoy/PXE/releases/download/v1.0.20/iventoy-$IVENTOY_RELEASE-linux-free.tar.gz"
IVENTOY_GIT_DOWNLOADED=0

# check if iventoy release 1.0.20 is present. If not, download the tar and extract, if it is, start it.
if [ ! -e "$IVENTOY_TAR_PATH" ]; then
    if [ ! -e "$IVENTOY_TAR_PATH_AFTER" ]; then
        # Check for errors with link with curl 302=success 404=fail/not found
        echo "Downloading iVentoy $IVENTOY_RELEASE."
        wget -q --show-progress "$IVENTOY_GIT_LINK"
        IVENTOY_GIT_DOWNLOADED=1
    fi

    if [ "$IVENTOY_GIT_DOWNLOADED" -eq 1 ]; then
        # Make sure it's downloaded
        if [ -e "iventoy-$IVENTOY_RELEASE-linux-free.tar.gz" ]; then
            echo "Downloaded iventoy-$IVENTOY_RELEASE-linux-free.tar.gz." >> "$INST_LOG_PATH"
            echo "Downloaded iventoy-$IVENTOY_RELEASE-linux-free.tar.gz."
            log_debug "Downloaded iventoy-$IVENTOY_RELEASE-linux-free.tar.gz."
        else
            echo "Failed to download iVentoy tarball."
            echo "Check your networking and check the link: $IVENTOY_GIT_LINK"
            log_debug "Failed to download iVentoy tarball. Networking? Dead link?"
            exit 1
        fi
    else echo "Already downloaded iventoy-$IVENTOY_RELEASE-linux-free.tar.gz."
    fi

    # Uncompress tarball
    if [ -e "$IVENTOY_TAR_PATH" ]; then
        if [ -e "$IVENTOY_DIR" ]; then
            tar -xf "$IVENTOY_TAR_PATH"
            echo "Inflated iVentoy".
            log_debug "Inflated iVentoy tarball"
        fi
    else echo "Already inflated iVentoy tarball."
        log_debug "Already inflated iVentoy tarball"
    fi

    # Move tarball to log folder
    if [ -e "$IVENTOY_TAR_PATH" ]; then
        mv "$IVENTOY_TAR_PATH" "$LOG_DIR/"
        log_debug "Moved tarball to log dir" 
    fi
else
    # Uncompress tarball
    if [ -e "$IVENTOY_TAR_CHECK" ]; then
        tar -xf "$IVENTOY_TAR_PATH"
        echo "Inflated iventoy tarball."
        log_debug "Inflated iventoy tarball"
    fi
    
    # Move tarball to log folder
    if [ -e "$IVENTOY_TAR_PATH" ]; then
        mv "$IVENTOY_TAR_PATH" "$LOG_DIR/"
        log_debug "Moved tarball to log dir" 
    fi
    
    echo "Tarball iventoy-$IVENTOY_RELEASE already downloaded." >> "$INST_LOG_PATH"
    echo "iVentoy already present."
    log_debug "Iventoy present"
fi

# Run iVentoy
IVENTOY_SCRIPT="$IVENTOY_DIR/iventoy.sh"
sudo bash "$IVENTOY_SCRIPT" start

# sudo is unable to access the lib dir in the iventoy dir... 