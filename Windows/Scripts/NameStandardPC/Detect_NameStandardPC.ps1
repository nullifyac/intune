# Define the registry path and key
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}"
$valueName = "(Default)"
$desiredValueData = "$env:COMPUTERNAME"

try {
    # Check if the registry key exists
    if (Test-Path -Path $regPath) {
        # Retrieve the current value
        $currentValueData = (Get-ItemProperty -Path $regPath -Name $valueName).$valueName

        if ($currentValueData -eq $desiredValueData) {
            Write-Output "The registry key is correctly set. Exiting with code 0 (compliant)."
            # Exit code 0 indicates that the value is correct (compliant)
            exit 0
        } else {
            Write-Output "The registry key is not set correctly. Exiting with code 1 (non-compliant)."
            # Exit code 1 indicates that remediation is needed
            exit 1
        }
    } else {
        Write-Output "The registry path does not exist. Exiting with code 1 (non-compliant, requires remediation)."
        # Exit code 1 to indicate remediation is needed
        exit 1
    }
} catch {
    Write-Output "An error occurred: $_"
    # Exit code 1 to indicate remediation is needed in case of an error
    exit 1
}
