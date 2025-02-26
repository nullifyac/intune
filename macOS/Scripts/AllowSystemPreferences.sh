#!/bin/bash

# Variables
SECURITYBIN="/usr/bin/security"

# The following commands succeeded

# Unlock Print & Scan preference pane
$SECURITYBIN authorizationdb write system.preferences.printing allow

# Unlock Date & Time preference pane
$SECURITYBIN authorizationdb write system.preferences.datetime allow

# Unlock Wi-Fi settings
$SECURITYBIN authorizationdb write com.apple.wifi allow

# Clean up temporary files if any were generated
rm /tmp/system.preferences.plist 2>/dev/null
rm /tmp/system.preferences.energysaver.plist 2>/dev/null
rm /tmp/system.preferences.datetime.plist 2>/dev/null

echo "Preference panes have been unlocked for non-admin users."
