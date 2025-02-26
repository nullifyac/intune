# Install as a non-admin user

#powershell.exe -WindowStyle hidden -ExecutionPolicy Bypass -File .\install.ps1

try {
    # Silent install using winget, suppressing all output
    winget.exe install -e --id Insomnia.Insomnia --silent --scope=user --accept-package-agreements --accept-source-agreements
  
    # Verify the installation
    $appPath = "$env:USERPROFILE\AppData\Local\insomnia\Insomnia.exe"
    
    if (Test-Path $appPath) {
        Write-Output "Installed successfully."
        exit 0
    } else {
        Write-Output "Installation failed."
        exit 1
    }
}
catch {
    Write-Output "Installation failed: $($_.Exception.Message)"
    exit 1
}
