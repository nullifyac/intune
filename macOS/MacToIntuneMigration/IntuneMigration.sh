#!/bin/bash

###############################################
# This script will provide temporary admin    #
# rights to a standard user right from self   #
# service. First it will grab the username of #
# the logged in user, elevate them to admin   #
# and then create a launch daemon that will   #
# count down from 60 minutes and then create  #
# and run a secondary script that will demote #
# the user back to a standard account. The    #
# launch daemon will continue to count down   #
# no matter how often the user logs out or    #
# restarts their computer.                    #
###############################################

#############################################
# find the logged in user and let them know #
#############################################

# Get the current logged-in user and their UID
currentUser=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')
uid=$(id -u "$currentUser")

# Convenience function to run a command as the current user
runAsUser() {
    if [ "$currentUser" != "loginwindow" ]; then
        launchctl asuser "$uid" sudo -u "$currentUser" "$@"
    else
        echo "No user logged in"
        exit 1
    fi
}

# Prompt user for confirmation
osascript -e 'display dialog "You now have administrative rights for 60 minutes. DO NOT ABUSE THIS PRIVILEGE..." buttons {"Make me an admin, please"} default button 1'

##################################
# give the user admin privileges #
##################################

/usr/sbin/dseditgroup -o edit -a "$currentUser" -t user admin

#########################################################
# write a daemon that will let you remove the privilege #
# with another script and chmod/chown to make sure      #
# it'll run, then load the daemon                       #
#########################################################

# Create the plist
sudo defaults write /Library/LaunchDaemons/removeAdmin.plist Label -string "removeAdmin"
sudo defaults write /Library/LaunchDaemons/removeAdmin.plist ProgramArguments -array -string /bin/sh -string "/Library/Application Support/JAMF/removeAdminRights.sh"
sudo defaults write /Library/LaunchDaemons/removeAdmin.plist StartInterval -integer 3600
sudo defaults write /Library/LaunchDaemons/removeAdmin.plist RunAtLoad -boolean yes

# Set ownership
sudo chown root:wheel /Library/LaunchDaemons/removeAdmin.plist
sudo chmod 644 /Library/LaunchDaemons/removeAdmin.plist

# Load the daemon
launchctl load /Library/LaunchDaemons/removeAdmin.plist
sleep 10

#########################
# make file for removal #
#########################

if [ ! -d /private/var/userToRemove ]; then
    mkdir /private/var/userToRemove
    echo "$currentUser" >> /private/var/userToRemove/user
else
    echo "$currentUser" >> /private/var/userToRemove/user
fi

########################################
# write a script for the launch daemon #
# to run to demote the user back and   #
# then pull logs of what the user did. #
########################################

cat << 'EOF' > /Library/Application\ Support/JAMF/removeAdminRights.sh
if [[ -f /private/var/userToRemove/user ]]; then
    userToRemove=$(cat /private/var/userToRemove/user)
    echo "Removing $userToRemove's admin privileges"
    /usr/sbin/dseditgroup -o edit -d $userToRemove -t user admin
    rm -f /private/var/userToRemove/user
    launchctl unload /Library/LaunchDaemons/removeAdmin.plist
    rm /Library/LaunchDaemons/removeAdmin.plist
    log collect --last 60m --output /private/var/userToRemove/$userToRemove.logarchive
fi
EOF

###############################################
# The original Jamf to Intune migration steps #
###############################################

# Global Variables
JAMF_BINARY="/usr/local/bin/jamf"
SERIAL=$(system_profiler SPHardwareDataType | awk '/Serial Number/{print $4}')
SYNC_LAUNCH_AGENT='/Library/LaunchAgents/com.jamf.connect.sync.plist'
VERIFY_LAUNCH_AGENT='/Library/LaunchAgents/com.jamf.connect.verify.plist'
CONNECT_LAUNCH_AGENT='/Library/LaunchAgents/com.jamf.connect.plist'
CONNECT_APP='/Applications/Jamf Connect.app/'
SYNC_APP='/Applications/Jamf Connect Sync.app/'
VERIFY_APP='/Applications/Jamf Connect Verify.app/'
CONFIG_APP='/Applications/Jamf Connect Configuration.app/'
EVALUATION_ASSETS='/Users/Shared/JamfConnectEvaluationAssets/'
CHROME_EXTENSIONS='/Library/Google/Chrome/NativeMessagingHosts/'

# Function to prompt user for confirmation or continuation
prompt_continue_or_abort() {
    local message=$1
    local choice
    choice=$(osascript -e "display dialog \"$message\" buttons {\"Continue\", \"Abort\"} default button \"Abort\" with icon caution")
    [[ "$choice" != "button returned:Continue" ]] && exit 1
}

# Function to display a message to the user
prompt_user() {
    osascript -e "display dialog \"$1\" buttons {\"OK\"} default button \"OK\" with icon note"
}

# Function to disable FileVault
disable_filevault() {
    if fdesetup status | grep -q "^FileVault is Off."; then
        prompt_user "FileVault is already off."
        return 0
    fi

    local PASS
    PASS=$(osascript <<EOT
    tell application "System Events"
    display dialog "Enter password to disable FileVault:" default answer "" with hidden answer
    return text returned of result
    end tell
EOT
)

    if [ -z "$PASS" ]; then exit 0; fi

    /usr/bin/expect <<EOF
    spawn fdesetup disable
    expect ":"
    send -- "$currentUser\r"
    expect ":"
    send -- "$PASS\r"
    expect "Decryption"
EOF

    sleep 2

    if fdesetup status | grep -q "Decryption in progress"; then
        prompt_user "FileVault is now decrypting."
    else
        choice=$(osascript -e 'display dialog "Failed to disable FileVault. Retry, Restart, or Abort?" buttons {"Retry", "Restart", "Abort"} default button "Retry"')
        case "$choice" in
            "button returned:Retry") disable_filevault ;;
            "button returned:Restart") sudo shutdown -r now ;;
            "button returned:Abort") exit 1 ;;
        esac
    fi
}

# Function to remove Jamf Connect components and framework
remove_jamf_connect_and_framework() {
    # Reset authentication database
    if [ -f "/usr/local/bin/authchanger" ]; then
        sudo /usr/local/bin/authchanger -reset
        [ $? -eq 0 ] && prompt_user "Authentication database reset." || prompt_continue_or_abort "Failed to reset the authentication database."
        
        sudo rm /usr/local/bin/authchanger /usr/local/lib/pam/pam_saml.so.2
        sudo rm -r /Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle
        prompt_user "Jamf Connect Login components removed."
    fi

    # Remove Jamf Connect Launch Agents and applications
    for agent in "$SYNC_LAUNCH_AGENT" "$VERIFY_LAUNCH_AGENT" "$CONNECT_LAUNCH_AGENT"; do
        [ -f "$agent" ] && sudo launchctl bootout gui/"$uid" "$agent" && sudo rm -f "$agent"
    done
    for app in "$CONNECT_APP" "$SYNC_APP" "$VERIFY_APP" "$CONFIG_APP"; do
        [ -d "$app" ] && sudo rm -rf "$app"
    done

    sudo rm -rf "$EVALUATION_ASSETS" "$CHROME_EXTENSIONS"
    prompt_user "Removed Jamf Connect evaluation assets and Chrome extensions."

    # Remove Jamf Connect profiles
    local profilesArray=($(profiles list | grep -i com.jamf.connect | awk '{print $4}'))
    for profile in "${profilesArray[@]}"; do
        sudo profiles -R -p "$profile"
        [ $? -eq 0 ] && prompt_user "Removed Jamf Connect profile: $profile." || prompt_user "Failed to remove profile: $profile."
    done

    # Remove Jamf management framework
    if [ -f "$JAMF_BINARY" ]; then
        sudo "$JAMF_BINARY" removeFramework
        [ $? -eq 0 ] && prompt_user "Jamf management framework removed." || prompt_continue_or_abort "Failed to remove Jamf management framework."
    fi
}

# Function to check if Jamf MDM has been removed
check_mdm_status() {
    local status=$(profiles status -type enrollment)
    if echo "$status" | grep -q "MDM enrollment: No"; then
        return 0
    else
        return 1
    fi
}

# Function to check if Intune MDM profile is assigned
check_intune_mdm_status() {
    local status=$(profiles status -type enrollment)
    if echo "$status" | grep -q "MDM enrollment: Yes (User Assigned)"; then
        return 0
    else
        return 1
    fi
}

# Function to prompt user to unmanage device in Jamf, repoint MDM to Intune in ABM, and start Intune enrollment
prompt_sync_intune_and_enroll() {
    # Step 1: Unmanage device from Jamf
    prompt_user "Please unmanage the device with serial number: $SERIAL from Jamf MDM."
    prompt_continue_or_abort "Once removed, click 'Continue'."

    # Step 2: Verify Jamf MDM removal
    while true; do
        if check_mdm_status; then
            prompt_user "Jamf MDM successfully removed."
            break
        else
            prompt_user "Jamf MDM is still active. Checking again in 30 seconds."
            sleep 30
        fi
    done

    # Remove Jamf Connect components and framework after verifying Jamf MDM removal
    remove_jamf_connect_and_framework

    # Step 3: Point device to Intune in ABM
    prompt_user "Repoint MDM to Intune in Apple Business Manager for device serial number: $SERIAL."
    prompt_continue_or_abort "Once done, click 'Continue'."

    # Step 4: Sync device enrollment in Intune
    prompt_user "Sync device enrollment in Intune. The device serial number $SERIAL should appear."
    prompt_continue_or_abort "Once the device appears in Intune, click 'Continue'."

    # Step 5: Check for Intune MDM enrollment
    while true; do
        runAsUser profiles renew -type enrollment
        if check_intune_mdm_status; then
            prompt_user "Intune MDM enrollment complete."
            break
        else
            prompt_user "Waiting for Intune profile assignment. Checking again in 60 seconds."
            sleep 60
        fi
    done
}

# Main script execution
disable_filevault
prompt_sync_intune_and_enroll

exit 0
