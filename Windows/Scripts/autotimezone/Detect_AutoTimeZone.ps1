<#
.SYNOPSIS
    Detects whether Windows time zone is correctly set based on location data
    or—if that fails—whether the fallback tzautoupdate service/registry is configured for auto update.

.DESCRIPTION
    This script attempts to determine the expected Windows time zone using the following steps:
      1. Enable location services and try to obtain coordinates via GeoCoordinateWatcher.
      2. If that fails (or returns “empty” values), use an IP‑based geolocation API (ip-api.com)
         to retrieve an IANA time zone.
      3. Convert the IANA time zone to a Windows time zone using an internal mapping table.
      4. Compare the expected Windows time zone with the current setting.
      5. If neither location method yields a valid time zone, fall back to checking that the
         tzautoupdate service (and its registry Start value) is configured for automatic updates.
         
    Exit code 0 indicates compliance; nonzero indicates non‑compliance or an error.

.NOTES
    • No external API keys are needed.
    • The “original” fallback reads the tzautoupdate service registry value.
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
    $logFile = "$env:windir\Temp\Detect-WindowsTimeZone_Auto.log"
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
        # (Optional) Set registry keys to enable location services.
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
    # Sample mapping table (extend as needed)
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
# Main Detection Logic
#############################################
try {
    Write-LogEntry "Starting detection of Windows time zone."
    Enable-LocationServices

    $coords = Get-GeoCoordinate

    # If no (or invalid) coordinates are returned, try IP-based geolocation.
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

    # If we obtained an IANA timezone, convert and compare.
    if ($null -ne $ianaTimeZone) {
        $expectedWinTZ = Convert-IanaToWindowsTimeZone -IanaTimeZone $ianaTimeZone
        if ($null -eq $expectedWinTZ) {
            Write-LogEntry "Could not map IANA timezone '$ianaTimeZone' to a Windows timezone. Falling back to registry check."
            # Fallback: check tzautoupdate registry.
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate"
            try {
                $regValue = (Get-ItemProperty -Path $regPath -Name Start -ErrorAction Stop).Start
                Write-LogEntry "tzautoupdate Start value: $regValue"
                if ($regValue -eq 2) {
                    Write-LogEntry "tzautoupdate service is set to auto. Device considered compliant."
                    Disable-LocationServices
                    exit 0
                }
                else {
                    Write-LogEntry "tzautoupdate service is not set to auto." "Warning"
                    Disable-LocationServices
                    exit 1
                }
            }
            catch {
                Write-LogEntry "Failed to read tzautoupdate registry: $_" "Error"
                Disable-LocationServices
                exit 1
            }
        }
        else {
            $currentWinTZ = (Get-TimeZone).Id
            Write-LogEntry "Current Windows timezone: $currentWinTZ; Expected: $expectedWinTZ"
            if ($currentWinTZ -eq $expectedWinTZ) {
                Write-LogEntry "Device is compliant."
                Disable-LocationServices
                exit 0
            }
            else {
                Write-LogEntry "Device is not compliant." "Warning"
                Disable-LocationServices
                exit 1
            }
        }
    }
    else {
        Write-LogEntry "Failed to obtain timezone from both location services and IP geolocation. Falling back to registry check."
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate"
        try {
            $regValue = (Get-ItemProperty -Path $regPath -Name Start -ErrorAction Stop).Start
            Write-LogEntry "tzautoupdate Start value: $regValue"
            if ($regValue -eq 2) {
                Write-LogEntry "tzautoupdate service is set to auto. Device considered compliant."
                Disable-LocationServices
                exit 0
            }
            else {
                Write-LogEntry "tzautoupdate service is not set to auto." "Warning"
                Disable-LocationServices
                exit 1
            }
        }
        catch {
            Write-LogEntry "Failed to read tzautoupdate registry: $_" "Error"
            Disable-LocationServices
            exit 1
        }
    }
}
catch {
    Write-LogEntry "An error occurred during detection: $_" "Error"
    Disable-LocationServices
    exit 1
}
