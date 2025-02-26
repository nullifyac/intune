# mRemoteNG Uninstall Script

try {
    # Verify Chocolatey is accessible
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        # Uninstall mRemoteNG using Chocolatey
        Write-Output "Uninstalling mRemoteNG..."
        choco uninstall mremoteng -y

        # Confirm mRemoteNG uninstallation
        $appPath = "C:\Program Files (x86)\mRemoteNG\mRemoteNG.exe"
        if (!(Test-Path $appPath)) {
            Write-Output "mRemoteNG uninstalled successfully."
            exit 0
        } else {
            Write-Output "mRemoteNG uninstallation failed."
            exit 1
        }
    } else {
        Write-Output "Chocolatey is not accessible. Please ensure Chocolatey is installed."
        exit 1
    }
}
catch {
    Write-Output "mRemoteNG uninstallation failed: $($_.Exception.Message)"
    exit 1
}
