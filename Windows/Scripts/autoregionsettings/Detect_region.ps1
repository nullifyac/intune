<#
.SYNOPSIS
    Intune remediation script to update Windows Home Location and regional format.

.DESCRIPTION
    This script attempts to detect the device's country using Windows Location Services 
    (with a reverse geocoding call to Nominatim, and falling back to IP-based geolocation).
    It maps the detected country to a GeoID and updates the system’s Home Location using 
    Set-WinHomeLocation. It then ensures that the regional format is set to "sv-SE" using 
    Set-WinUILanguageOverride and Set-WinUserLanguageList.

.NOTES
    Ensure the script is run with appropriate privileges.
#>

#region Functions

function Get-DeviceLocation {
    try {
        $locator = New-Object Windows.Devices.Geolocation.Geolocator
        $position = $locator.GetGeopositionAsync().AsTask().Result
        return [PSCustomObject]@{
            Latitude  = $position.Coordinate.Latitude
            Longitude = $position.Coordinate.Longitude
        }
    }
    catch {
        Write-Warning "Windows Location Services failed: $_. Falling back to IP-based geolocation."
        return $null
    }
}

function Get-IPGeolocation {
    try {
        $geoData = Invoke-RestMethod -Uri "http://ip-api.com/json"
        if ($geoData.status -eq "success" -and $geoData.country) {
            return $geoData.country
        }
        else {
            throw "IP Geolocation returned error status: $($geoData.status)"
        }
    }
    catch {
        Write-Warning "Failed to retrieve location from IP geolocation: $_"
        return $null
    }
}

function Get-GeoID {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Country
    )
    $normalizedCountry = $Country.ToLowerInvariant()
    $geoIdMapping = @{
        "sweden"         = 221
        "united states"  = 244
        "germany"        = 94
        "france"         = 84
        "united kingdom" = 242
        "canada"         = 39
        "australia"      = 12
        "japan"          = 122
        "china"          = 45
        "india"          = 105
        "brazil"         = 31
        "netherlands"    = 151
        "norway"         = 164
        "denmark"        = 58
        "finland"        = 77
        "mexico"         = 148
        "italy"          = 118
        "spain"          = 203
        "south korea"    = 234
        "russia"         = 182
        "south africa"   = 236
    }
    return $geoIdMapping[$normalizedCountry]
}

function Set-LocationAndRegionalSettings {
    param (
        [string]$ExpectedLocale = "sv-SE"
    )
    
    $detectedCountry = $null

    # Try Windows Location Services first.
    $locationObject = Get-DeviceLocation
    if ($locationObject) {
        try {
            $headers = @{ "User-Agent" = "RemediationScript/1.0 (contact@yourdomain.com)" }
            $uri = "https://nominatim.openstreetmap.org/reverse?format=json&lat=$($locationObject.Latitude)&lon=$($locationObject.Longitude)"
            $geoData = Invoke-RestMethod -Uri $uri -Headers $headers
            if ($geoData.address -and $geoData.address.country) {
                $detectedCountry = $geoData.address.country
                Write-Output "Detected country via reverse geocoding: $detectedCountry"
            }
            else {
                throw "Country not found in reverse geocoding data."
            }
        }
        catch {
            Write-Warning "Reverse geolocation failed: $_. Falling back to IP-based geolocation."
        }
    }

    if (-not $detectedCountry) {
        $detectedCountry = Get-IPGeolocation
        if ($detectedCountry) {
            Write-Output "Detected country via IP geolocation: $detectedCountry"
        }
    }

    if (-not $detectedCountry) {
        Write-Warning "Unable to detect country; defaulting to Sweden."
        $detectedCountry = "Sweden"
    }

    $geoId = Get-GeoID -Country $detectedCountry
    if (-not $geoId) {
        Write-Warning "GeoID mapping failed for '$detectedCountry'; defaulting to Sweden (221)."
        $geoId = 221
    }

    # Set Windows Home Location.
    try {
        Set-WinHomeLocation -GeoId $geoId
        Write-Output "Home location updated to GeoID $geoId based on detected country: $detectedCountry"
    }
    catch {
        Write-Error "Failed to set Home Location: $_"
    }

    # Update the regional format if necessary.
    try {
        $currentLanguageList = Get-WinUserLanguageList
        if ($currentLanguageList.Count -gt 0 -and $currentLanguageList[0].LanguageTag) {
            $currentLocale = $currentLanguageList[0].LanguageTag
        }
        else {
            $currentLocale = ""
        }
        if ($ExpectedLocale -ne $currentLocale) {
            Set-WinUILanguageOverride -Language $ExpectedLocale
            Set-WinUserLanguageList -LanguageList $ExpectedLocale -Force
            Write-Output "Regional format updated to $ExpectedLocale."
        }
        else {
            Write-Output "Regional format is already set to $ExpectedLocale."
        }
    }
    catch {
        Write-Error "Failed to update regional format: $_"
    }
}

#endregion Functions

#region Main Remediation Execution

Set-LocationAndRegionalSettings -ExpectedLocale "sv-SE"

#endregion Main Remediation Execution
