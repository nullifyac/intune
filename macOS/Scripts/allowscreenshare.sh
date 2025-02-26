#!/bin/bash

#set -x

## This script will enable remote screen sharing on the Mac so that an Administrator can connecta via the Remote Screen Sharing App
##

# User Defined variables
appname="EnableScreenSharing"                                                   # The name of our App deployment script (also used for Octory monitor)
logandmetadir="/Library/Logs/Microsoft/IntuneScripts/EnableScreenSharing"       # The location of our logs and last updated data

# Generated variables
log="$logandmetadir/$appname.log"                                               # The location of the script log file
metafile="$logandmetadir/$appname.meta"                                         # The location of our meta file (for updates)

# Function to start logging
function startLog() {

    ###################################################
    ###################################################
    ##
    ##  start logging - Output to log file and STDOUT
    ##
    ####################
    ####################

    if [[ ! -d "$logandmetadir" ]]; then
        ## Creating Metadirectory
        echo "$(date) | Creating [$logandmetadir] to store logs"
        mkdir -p "$logandmetadir"
    fi

    exec &> >(tee -a "$log")
    
}

# Initiate logging
startLog

echo ""
echo "##############################################################"
echo "# $(date) | Logging configuration of [$appname] to [$log]"
echo "############################################################"
echo ""

echo "$(date) | Writing to /var/db/launchd.db/com.apple.launchd/overrides.plist"
sudo defaults write /var/db/launchd.db/com.apple.launchd/overrides.plist com.apple.screensharing -dict Disabled -bool false

echo "$(date) | Launching com.apple.screensharing Launch Daemon"
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist

#
# Note: If you don't do this, the remote client will just see a black screen with the vnc client or screen sharing app won't connect.
# however, by resetting the Screen Capture permissions, anything that has previously been granted the permission will need to be re-added
# this includes things like Teams, Zoom, Snagit etc.
#
# On an ADE enrolled Mac this probably isn't a problem, but for a user initiated enrollment it probably is something you'll want to think about
# before deploying widely.
echo "$(date) | Reset Screen Capture Permissions"
sudo tccutil reset ScreenCapture
