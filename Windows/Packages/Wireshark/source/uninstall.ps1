# Uninstall as a non-admin user

#powershell.exe -WindowStyle hidden -ExecutionPolicy Bypass -File .\uninstall.ps1

try {
    # Silent uninstall using winget, suppressing all output
    winget.exe uninstall -e --id WiresharkFoundation.Wireshark --silent --accept-source-agreements

    # Verify the uninstallation
    $appPath = "C:\Program Files\Wireshark\wireshark.exe"
    
    if (-not (Test-Path $appPath)) {
        Write-Output "Uninstalled successfully."
        exit 0
    } else {
        Write-Output "Uninstallation failed."
        exit 1
    }
}
catch {
    Write-Output "Uninstallation failed: $($_.Exception.Message)"
    exit 1
}
