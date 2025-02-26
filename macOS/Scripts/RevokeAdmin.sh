#!/bin/zsh
#set -x

############################################################################################
## Script to downgrade all users to Standard Users
############################################################################################

# Define variables
scriptname="Downgrade Admin Users to Standard"
log="/var/tmp/downgradeadminusers.log"   # Change log location to /var/tmp
logandmetadir="/var/tmp/Microsoft/IntuneScripts/downgradeAdminUsers"   # New temporary log directory

function startLog() {
    if [[ ! -d "$logandmetadir" ]]; then
        echo "$(date) | Creating [$logandmetadir] for logs"
        mkdir -p "$logandmetadir"
    fi
    echo "$(date) | Logging to [$log]"
    exec > >(tee -a "$log") 2>&1
}

# Function to delay until the user has finished setup assistant
function waitforSetupAssistant() {
  until [[ -f /var/db/.AppleSetupDone ]]; do
    delay=$(( $RANDOM % 50 + 10 ))
    echo "$(date) | Waiting on SetupAssistant [$delay seconds]"
    sleep $delay
  done
  echo "$(date) | SetupAssistant done"
}

startLog

# Begin Script Body
echo ""
echo "##############################################################"
echo "# $(date) | Starting $scriptname"
echo "##############################################################"
echo ""

# Is this an ABM DEP device?
if [[ "$abmcheck" = true ]]; then
  downgrade=false
  echo "$(date) | Checking MDM Profile"
  profiles status -type enrollment | grep "Enrolled via DEP: Yes"
  if [[ $? -ne 0 ]]; then
    echo "$(date) | Not ABM managed. Exiting script."
    exit 0
  else
    echo "$(date) | ABM Managed. Downgrade will proceed."
    downgrade=true
  fi
else
  echo "$(date) | ABM check is disabled. Proceeding with downgrade."
  downgrade=true
fi

# Check for setup assistant
waitforSetupAssistant

# Perform downgrades
if [[ $downgrade = true ]]; then
  echo "$(date) | Downgrade process starting..."
  while read useraccount; do
    echo "$(date) | Checking user: $useraccount"
    if [[ "$useraccount" == *"Admin"* ]]; then
        echo "$(date) | Leaving Admin account as Admin."
    else
        echo "$(date) | Demoting user: $useraccount"
        demotion_result=$(/usr/sbin/dseditgroup -o edit -d $useraccount -t user admin 2>&1)
        if [[ $? -eq 0 ]]; then
          echo "$(date) | Successfully demoted $useraccount."
        else
          echo "$(date) | ERROR demoting $useraccount: $demotion_result"
        fi
    fi
  done < <(dscl . list /Users UniqueID | awk '$2 >= 501 {print $1}')
else
  echo "$(date) | Downgrade is not enabled. Exiting script."
fi

echo "$(date) | Script completed."
