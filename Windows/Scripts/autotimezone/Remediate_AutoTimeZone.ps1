<#
.SYNOPSIS
    Remediates Windows time zone settings using location data (via GPS or IP-based geolocation)
    or—if those methods fail—by configuring the tzautoupdate service/registry for automatic time zone updates.

.DESCRIPTION
    This script attempts to determine the correct Windows time zone:
      1. It first enables location services and tries to obtain coordinates via GeoCoordinateWatcher.
      2. If that method fails, it falls back to IP-based geolocation (ip-api.com) to get an IANA timezone.
      3. If a valid IANA timezone is obtained, it is converted to the corresponding Windows time zone
         and compared to the current setting. If they differ, Set-TimeZone is called.
      4. If neither method yields a valid timezone, the script falls back to configuring the
         tzautoupdate service to Automatic (with registry Start value = 2) so that Windows will auto-update
         its time zone.

    Exit code 0 indicates remediation succeeded (or no change was needed); nonzero indicates an error.

.NOTES
    • No external API keys are required.
    • Created: 2025-02-06
#>

# Ensure TLS 1.2 for HTTPS calls.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#############################################
# Logging Function
#############################################
function Write-LogEntry {
    param(
        [string]$Message,
        [ValidateSet("Info","Warning","Error")]
        [string]$Level = "Info"
    )
    $logFile = "$env:windir\Temp\Remediate-WindowsTimeZone_Auto.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp [$Level] $Message"
    try {
        Add-Content -Path $logFile -Value $entry
    }
    catch {
        Write-Host "Logging failed: $_"
    }
}

#############################################
# Functions to Enable/Disable Location Services
#############################################
function Enable-LocationServices {
    try {
        $AppsAccessLocation = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
        if (Test-Path $AppsAccessLocation) {
            Set-ItemProperty -Path $AppsAccessLocation -Name "LetAppsAccessLocation" -Value 0 -ErrorAction SilentlyContinue
        }
        $LocationConsentKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
        if (Test-Path $LocationConsentKey) {
            Set-ItemProperty -Path $LocationConsentKey -Name "Value" -Value "Allow" -ErrorAction SilentlyContinue
        }
        $SensorKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}"
        if (Test-Path $SensorKey) {
            Set-ItemProperty -Path $SensorKey -Name "SensorPermissionState" -Value 1 -ErrorAction SilentlyContinue
        }
        $LocationServiceKey = "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration"
        if (Test-Path $LocationServiceKey) {
            Set-ItemProperty -Path $LocationServiceKey -Name "Status" -Value 1 -ErrorAction SilentlyContinue
        }
        $svc = Get-Service -Name "lfsvc" -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.Status -ne "Running") {
                Start-Service -Name "lfsvc" -ErrorAction SilentlyContinue
            }
            else {
                Restart-Service -Name "lfsvc" -ErrorAction SilentlyContinue
            }
        }
        Write-LogEntry "Location services enabled."
    }
    catch {
        Write-LogEntry "Failed to enable location services: $_" "Error"
    }
}

function Disable-LocationServices {
    try {
        $LocationConsentKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
        if (Test-Path $LocationConsentKey) {
            Set-ItemProperty -Path $LocationConsentKey -Name "Value" -Value "Deny" -ErrorAction SilentlyContinue
        }
        $SensorKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}"
        if (Test-Path $SensorKey) {
            Set-ItemProperty -Path $SensorKey -Name "SensorPermissionState" -Value 0 -ErrorAction SilentlyContinue
        }
        $LocationServiceKey = "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration"
        if (Test-Path $LocationServiceKey) {
            Set-ItemProperty -Path $LocationServiceKey -Name "Status" -Value 0 -ErrorAction SilentlyContinue
        }
        Write-LogEntry "Location services disabled."
    }
    catch {
        Write-LogEntry "Failed to disable location services: $_" "Error"
    }
}

#############################################
# Function: Get Coordinates via GeoCoordinateWatcher
#############################################
function Get-GeoCoordinate {
    $coords = [PSCustomObject]@{
        Latitude  = $null
        Longitude = $null
    }
    try {
        Add-Type -AssemblyName "System.Device" -ErrorAction Stop
        $watcher = New-Object System.Device.Location.GeoCoordinateWatcher
        $watcher.Start()
        $counter = 0
        while (($watcher.Status -ne "Ready") -and ($counter -lt 60)) {
            Start-Sleep -Seconds 1
            $counter++
        }
        if ($watcher.Permission -eq "Denied") {
            Write-LogEntry "GeoCoordinateWatcher permission denied." "Warning"
            $watcher.Stop()
            $watcher.Dispose()
            return $coords
        }
        $coords.Latitude = ($watcher.Position.Location.Latitude).ToString().Replace(",", ".")
        $coords.Longitude = ($watcher.Position.Location.Longitude).ToString().Replace(",", ".")
        $watcher.Stop()
        $watcher.Dispose()
        Write-LogEntry "GeoCoordinateWatcher obtained coordinates: Lat=$($coords.Latitude), Lon=$($coords.Longitude)"
    }
    catch {
        Write-LogEntry "Error in GeoCoordinateWatcher: $_" "Error"
    }
    return $coords
}

#############################################
# Function: Convert IANA to Windows Time Zone
#############################################
function Convert-IanaToWindowsTimeZone {
    param(
        [string]$IanaTimeZone
    )
    $mapping = @{
        "America/Los_Angeles" = "Pacific Standard Time"
        "America/Denver"      = "Mountain Standard Time"
        "America/Chicago"     = "Central Standard Time"
        "America/New_York"    = "Eastern Standard Time"
        "Europe/London"       = "GMT Standard Time"
        "Europe/Berlin"       = "W. Europe Standard Time"
        "Europe/Paris"        = "Romance Standard Time"
        "Europe/Moscow"       = "Russian Standard Time"
        "Asia/Tokyo"          = "Tokyo Standard Time"
        "Asia/Shanghai"       = "China Standard Time"
        "Australia/Sydney"    = "AUS Eastern Standard Time"
    }
    if ($mapping.ContainsKey($IanaTimeZone)) {
        return $mapping[$IanaTimeZone]
    }
    else {
        Write-LogEntry "No mapping found for IANA time zone '$IanaTimeZone'" "Warning"
        return $null
    }
}

#############################################
# Main Remediation Logic
#############################################
try {
    Write-LogEntry "Starting remediation of Windows time zone."
    Enable-LocationServices

    $coords = Get-GeoCoordinate

    # If no valid coordinates, attempt IP-based geolocation fallback.
    if (( $null -eq $coords.Latitude ) -or ( $null -eq $coords.Longitude ) -or ($coords.Latitude -eq "0") -or ($coords.Longitude -eq "0")) {
        Write-LogEntry "GeoCoordinateWatcher did not return valid coordinates. Trying IP-based geolocation fallback."
        try {
            $ipResponse = Invoke-RestMethod -Uri "http://ip-api.com/json" -Method Get -ErrorAction Stop
            if ($ipResponse.status -eq "success" -and $ipResponse.timezone) {
                $ianaTimeZone = $ipResponse.timezone
                Write-LogEntry "IP-based geolocation returned timezone: $ianaTimeZone"
            }
            else {
                Write-LogEntry "IP-based geolocation did not return a valid timezone." "Warning"
            }
        }
        catch {
            Write-LogEntry "IP-based geolocation API call failed: $_" "Error"
        }
    }
    else {
        # Optionally, use IP-based geolocation even if GPS data is available.
        try {
            $ipResponse = Invoke-RestMethod -Uri "http://ip-api.com/json" -Method Get -ErrorAction Stop
            if ($ipResponse.status -eq "success" -and $ipResponse.timezone) {
                $ianaTimeZone = $ipResponse.timezone
                Write-LogEntry "Using IP-based timezone: $ianaTimeZone"
            }
        }
        catch {
            Write-LogEntry "IP-based geolocation fallback error: $_" "Warning"
        }
    }

    $fallback = $false
    if ($null -ne $ianaTimeZone) {
        $expectedWinTZ = Convert-IanaToWindowsTimeZone -IanaTimeZone $ianaTimeZone
        if ($null -eq $expectedWinTZ) {
            Write-LogEntry "Could not map IANA timezone '$ianaTimeZone' to a Windows timezone. Will fall back to auto update."
            $fallback = $true
        }
        else {
            $currentWinTZ = (Get-TimeZone).Id
            Write-LogEntry "Current Windows timezone: $currentWinTZ; Expected: $expectedWinTZ"
            if ($currentWinTZ -ne $expectedWinTZ) {
                try {
                    Set-TimeZone -Id $expectedWinTZ -ErrorAction Stop
                    Write-LogEntry "Windows time zone successfully set to $expectedWinTZ."
                }
                catch {
                    Write-LogEntry "Failed to set Windows time zone: $_" "Error"
                    $fallback = $true
                }
            }
            else {
                Write-LogEntry "Windows time zone is already correctly set to $expectedWinTZ."
            }
        }
    }
    else {
        Write-LogEntry "Failed to obtain a timezone from location services or IP geolocation." "Warning"
        $fallback = $true
    }

    # Fallback: If neither method provided a valid timezone (or mapping failed), configure tzautoupdate to auto.
    if ($fallback) {
        Write-LogEntry "Falling back to configuring tzautoupdate service for automatic time zone updates."
        try {
            # Set the tzautoupdate service to Automatic and start it.
            Set-Service -Name "tzautoupdate" -StartupType Automatic -ErrorAction Stop
            Start-Service -Name "tzautoupdate" -ErrorAction Stop
            # Update the registry Start value to 2 (Automatic).
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate"
            Set-ItemProperty -Path $regPath -Name "Start" -Value 2 -ErrorAction Stop
            Write-LogEntry "tzautoupdate service configured for automatic updates."
        }
        catch {
            Write-LogEntry "Failed to configure tzautoupdate service: $_" "Error"
            Disable-LocationServices
            exit 1
        }
    }
    Disable-LocationServices
    exit 0
}
catch {
    Write-LogEntry "An error occurred during remediation: $_" "Error"
    Disable-LocationServices
    exit 1
}
