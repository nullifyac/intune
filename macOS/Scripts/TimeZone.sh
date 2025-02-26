#!/bin/bash

uuid=$("/usr/sbin/system_profiler" SPHardwareDataType | grep "Hardware UUID" | awk '{ print $3 }')
timedPrefs="/private/var/db/timed/Library/Preferences/com.apple.timed.plist"
dateTimePrefs="/private/var/db/timed/Library/Preferences/com.apple.preferences.datetime.plist"
locationPrefs="/private/var/db/locationd/Library/Preferences/ByHost/com.apple.locationd.${uuid}"
byHostPath="/var/db/locationd/Library/Preferences/ByHost/com.apple.locationd"

# Set preferences.
echo "Ensuring location services are enabled"
sudo -u "_locationd" /usr/bin/defaults -currentHost write "$locationPrefs" LocationServicesEnabled -int 1
sudo defaults write "${byHostPath}" LocationServicesEnabled -int 1
/usr/sbin/chown "_locationd:_locationd" "$locationPrefs"

echo "Configuring automatic time"
/usr/bin/defaults write "$timedPrefs" TMAutomaticTimeZoneEnabled -bool YES
/usr/bin/defaults write "$timedPrefs" TMAutomaticTimeOnlyEnabled -bool YES
/usr/bin/defaults write "$dateTimePrefs" timezoneset -bool YES
/usr/sbin/chown "_timed:_timed" "$timedPrefs" "$dateTimePrefs"

# Detect the region using the locale
region=$(/usr/bin/defaults read NSGlobalDomain AppleLocale | cut -d '_' -f 2)

# List of countries using the 12-hour time format
twelve_hour_countries=("US" "CA" "AU" "NZ" "PH" "MY" "GB" "IN")

# Default to 24-hour time format
echo "Setting default to 24-hour time format"
/usr/bin/defaults write NSGlobalDomain AppleICUForce24HourTime -bool true

# Check if the region is one of the 12-hour format countries
if [[ " ${twelve_hour_countries[@]} " =~ " ${region} " ]]; then
  echo "${region} detected, setting 12-hour time format"
  /usr/bin/defaults write NSGlobalDomain AppleICUForce24HourTime -bool false
else
  echo "Non 12-hour region detected (${region}), keeping 24-hour time format"
fi

exit 0
