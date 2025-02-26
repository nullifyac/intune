<#
.SYNOPSIS
    Remediation script to update Windows Home Location and regional format.

.DESCRIPTION
    This script attempts to detect the device's country using Windows Location Services 
    (with reverse geocoding via Nominatim and a fallback to IP-based geolocation).
    It maps the detected country to a GeoID and updates the system’s Home Location using 
    Set-WinHomeLocation. It also ensures that the regional format is set to the expected value 
    (default: "sv-SE").

    Additional improvements include:
      - Parameterization of expected locale, fallback country, and User-Agent.
      - A check to ensure the script is run with administrator privileges.
      - Enhanced error handling and verbose logging.

.PARAMETER ExpectedLocale
    The regional locale to set. Default is "sv-SE".

.PARAMETER FallbackCountry
    The country to default to if geolocation detection fails. Default is "Sweden".

.PARAMETER UserAgent
    The User-Agent string to use when making HTTP requests to external geolocation services.
    Default is "RemediationScript/1.0 (contact@yourdomain.com)".

.EXAMPLE
    .\Remediate_region.ps1 -ExpectedLocale "sv-SE" -FallbackCountry "Sweden" -UserAgent "MyScript/1.0 (admin@contoso.com)"

.NOTES
    This script must be run with administrator privileges.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ExpectedLocale = "sv-SE",

    [Parameter()]
    [string]$FallbackCountry = "Sweden",

    [Parameter()]
    [string]$UserAgent = "RemediationScript/1.0 (contact@yourdomain.com)"
)

# Ensure the script is running with administrator rights.
function Assert-Administrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "Administrator privileges are required to run this script. Exiting."
        exit 1
    }
}
Assert-Administrator

#region Functions

function Get-DeviceLocation {
    <#
    .SYNOPSIS
        Retrieves the device's geographic coordinates using Windows Location Services.
    .OUTPUTS
        PSCustomObject with Latitude and Longitude, or $null if detection fails.
    #>
    try {
        # Create a Geolocator instance.
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
    <#
    .SYNOPSIS
        Retrieves the country name based on the device's public IP address.
    .OUTPUTS
        String containing the detected country or $null on failure.
    #>
    try {
        $response = Invoke-RestMethod -Uri "http://ip-api.com/json" -UseBasicParsing
        if ($response.status -eq "success" -and $response.country) {
            return $response.country
        }
        else {
            throw "IP Geolocation error: $($response.status)"
        }
    }
    catch {
        Write-Warning "IP-based geolocation failed: $_"
        return $null
    }
}

function Get-GeoID {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Country
    )
    <#
    .SYNOPSIS
        Maps a country name to its corresponding GeoID.
    .OUTPUTS
        An integer representing the GeoID, or $null if no mapping is found.
    #>
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
        [string]$ExpectedLocale,
        [string]$FallbackCountry,
        [string]$UserAgent
    )
    
    $detectedCountry = $null

    # Attempt detection via Windows Location Services.
    $locationObject = Get-DeviceLocation
    if ($locationObject) {
        try {
            $headers = @{ "User-Agent" = $UserAgent }
            $uri = "https://nominatim.openstreetmap.org/reverse?format=json&lat=$($locationObject.Latitude)&lon=$($locationObject.Longitude)"
            $geoData = Invoke-RestMethod -Uri $uri -Headers $headers -UseBasicParsing
            if ($geoData.address -and $geoData.address.country) {
                $detectedCountry = $geoData.address.country
                Write-Verbose "Detected country via reverse geocoding: $detectedCountry"
            }
            else {
                throw "Country not found in reverse geocoding data."
            }
        }
        catch {
            Write-Warning "Reverse geocoding failed: $_. Falling back to IP-based geolocation."
        }
    }

    # Fall back to IP-based geolocation if necessary.
    if (-not $detectedCountry) {
        $detectedCountry = Get-IPGeolocation
        if ($detectedCountry) {
            Write-Verbose "Detected country via IP geolocation: $detectedCountry"
        }
    }

    # If detection fails entirely, default to the provided fallback.
    if (-not $detectedCountry) {
        Write-Warning "Unable to detect country; defaulting to $FallbackCountry."
        $detectedCountry = $FallbackCountry
    }

    # Map the detected country to a GeoID.
    $geoId = Get-GeoID -Country $detectedCountry
    if (-not $geoId) {
        Write-Warning "GeoID mapping failed for '$detectedCountry'; defaulting to Sweden (221)."
        $geoId = 221
    }

    # Update Windows Home Location.
    try {
        Set-WinHomeLocation -GeoId $geoId
        Write-Output "Home location updated to GeoID $geoId based on detected country: $detectedCountry"
    }
    catch {
        Write-Error "Failed to set Home Location: $_"
    }

    # Update the regional format if necessary.
    try {
        $languageList = Get-WinUserLanguageList
        if ($languageList.Count -gt 0 -and $languageList[0].LanguageTag) {
            $currentLocale = $languageList[0].LanguageTag
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

#region Main Execution

try {
    Write-Output "Starting remediation process..."
    Set-LocationAndRegionalSettings -ExpectedLocale $ExpectedLocale -FallbackCountry $FallbackCountry -UserAgent $UserAgent
    Write-Output "Remediation completed successfully."
}
catch {
    Write-Error "An unexpected error occurred: $_"
    exit 1
}

#endregion Main Execution
