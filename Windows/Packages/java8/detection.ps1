<#
.SYNOPSIS
    Intune Detection Script for any Java installation

.DESCRIPTION
    This script detects whether there are any references to Java 
    (JRE or JDK) installed on a Windows system.

    If ANY Java is detected:
        Exit code 0  (means "installed" in Intune)
    If NO Java is detected:
        Exit code 1  (means "not installed" in Intune)
#>

param(
    [switch]$FileSystemCheck = $true
)

#region Helper: Write-Log (Optional logging to file — harmless if you keep or remove)
$LogPath = "$($env:SystemDrive)\Logs"
$LogFileName = "$($env:COMPUTERNAME)_java_detection.log"
function Write-Log {
    param(
        [Parameter(Mandatory=$true)] [string]$Message
    )
    # Write to the local log file, also helpful for debugging.
    if (!(Test-Path $LogPath)) {
        try {
            New-Item -Path $LogPath -ItemType Directory -ErrorAction Stop | Out-Null
        } catch {
            # If we cannot create the folder, just skip logging
        }
    }
    $logFullPath = Join-Path $LogPath $LogFileName
    Add-Content -Path $logFullPath -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message)
}
#endregion

#region Get-WMIJava
function Get-WMIJava {
    Write-Log "Detecting Java via WMI (Win32_Product)..."
    $results = @()
    try {
        $products = Get-WmiObject -Class Win32_Product -Namespace "root\cimv2" -ErrorAction Stop
        foreach ($p in $products) {
            if ($p.Name -match "Java" -or $p.Name -match "JRE" -or $p.Name -match "JDK") {
                $results += [PSCustomObject]@{
                    Name              = $p.Name
                    Version           = $p.Version
                    IdentifyingNumber = $p.IdentifyingNumber
                    Source            = 'WMI'
                }
            }
        }
    }
    catch {
        Write-Log "WMI detection failed: $($_.Exception.Message)"
    }
    return $results
}
#endregion

#region Get-RegistryJava
function Get-RegistryJava {
    Write-Log "Detecting Java via Registry..."
    $pathsToCheck = @(
        'HKLM:\SOFTWARE\JavaSoft',
        'HKLM:\SOFTWARE\Wow6432Node\JavaSoft',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )

    $results = @()
    foreach ($regPath in $pathsToCheck) {
        if (Test-Path $regPath) {
            try {
                Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue | ForEach-Object {
                    $keyPath = $_.Name
                    if ($keyPath -match "Java" -or $keyPath -match "JRE" -or $keyPath -match "JDK") {
                        # Attempt to read DisplayName, etc.
                        $props = Get-ItemProperty -Path $_.PsPath -ErrorAction SilentlyContinue
                        if ($props.DisplayName -match "Java" -or 
                            $props.DisplayName -match "JRE" -or 
                            $props.DisplayName -match "JDK") {

                            $results += [PSCustomObject]@{
                                Name              = $props.DisplayName
                                Version           = $props.DisplayVersion
                                IdentifyingNumber = $props.UninstallString
                                Source            = 'Registry'
                                KeyPath           = $keyPath
                            }
                        }
                        else {
                            # Maybe a JavaSoft subkey without "DisplayName"
                            # e.g., HKLM:\SOFTWARE\JavaSoft\Java Runtime Environment\<version>
                            $subSubKeys = Get-ChildItem -Path $_.PSPath -ErrorAction SilentlyContinue
                            foreach ($ssk in $subSubKeys) {
                                if ($ssk.PSChildName -match '^\d' -or $ssk.PSChildName -match "JRE|JDK") {
                                    $javakey = Get-ItemProperty -Path $ssk.PSPath -ErrorAction SilentlyContinue
                                    if ($javakey) {
                                        $results += [PSCustomObject]@{
                                            Name              = "JavaSoft\$($ssk.PSChildName)"
                                            Version           = $javakey.JavaHome  # or Release
                                            IdentifyingNumber = "N/A"
                                            Source            = 'Registry'
                                            KeyPath           = "$keyPath\$($ssk.PSChildName)"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            catch {
                Write-Log "Registry detection error at $regPath $($_.Exception.Message)"
            }
        }
    }
    return $results
}
#endregion

#region Get-FSJava
function Get-FSJava {
    Write-Log "Detecting Java directories via File System..."
    $rootPaths = @(
        $Env:ProgramFiles,
        ${Env:ProgramFiles(x86)},
        "$Env:ProgramFiles\Common Files\Oracle\Java",
        "$Env:ProgramFiles(x86)\Common Files\Oracle\Java"
    )

    $results = @()
    $maxDepth = 3
    foreach ($root in $rootPaths) {
        if ([string]::IsNullOrEmpty($root) -or -not (Test-Path $root)) { continue }
        try {
            Get-ChildItem -Path $root -Directory -Recurse -Depth $maxDepth -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match 'Java|JRE|JDK' } |
                ForEach-Object {
                    $results += [PSCustomObject]@{
                        Name              = $_.Name
                        Version           = 'N/A'
                        IdentifyingNumber = $_.FullName
                        Source            = 'FileSystem'
                    }
                }
        }
        catch {
            Write-Log "FS detection error at $root $($_.Exception.Message)"
        }
    }
    return $results
}
#endregion

# ----------------------------
# MAIN DETECTION LOGIC
# ----------------------------
Write-Log "Java Detection Script starting..."

$wmiResults = Get-WMIJava
$regResults = Get-RegistryJava
$fsResults = $null

if ($FileSystemCheck) {
    $fsResults = Get-FSJava
}

# Combine all findings
$allResults = $wmiResults + $regResults + $fsResults

Write-Log "Total Java references found: $($allResults.Count)"

# Intune Detection Logic:
#   - If any result is found, detection = success => exit 0
#   - If no result is found, detection = fail => exit 1
if ($allResults.Count -gt 0) {
    Write-Log "At least one Java reference found. Exiting with code 0."
    exit 0
}
else {
    Write-Log "No Java references found. Exiting with code 1."
    exit 1
}
