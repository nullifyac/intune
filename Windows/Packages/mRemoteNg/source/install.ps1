# mRemoteNG Install Script

try {
    # Verify Chocolatey is accessible
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        # Install mRemoteNG using Chocolatey
        Write-Output "Installing mRemoteNG..."
        choco install mremoteng --ignore-checksums -y

        # Check if mRemoteNG was installed successfully
        $appPath = "C:\Program Files (x86)\mRemoteNG\mRemoteNG.exe"
        if (Test-Path $appPath) {
            Write-Output "mRemoteNG installed successfully."
            exit 0
        } else {
            Write-Output "mRemoteNG installation failed."
            exit 1
        }
    } else {
        Write-Output "Chocolatey is not accessible. Please ensure Chocolatey is installed."
        exit 1
    }
}
catch {
    Write-Output "mRemoteNG installation failed: $($_.Exception.Message)"
    exit 1
}
