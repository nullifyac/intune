#powershell.exe -WindowStyle hidden -ExecutionPolicy Bypass -File .\install.ps1

$logPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\WacomDrivers_Install.log"
Start-Transcript -Path $logPath -Append

Write-Output "Starting Wacom Drivers installation."

try {
    Write-Output "Installing Wacom Drivers via Chocolatey..."
    choco install wacom-drivers -y --no-progress --ignore-package-exit-codes | Out-Null
    $exitCode = $LASTEXITCODE
    Write-Output "Chocolatey install exit code: $exitCode"

    if ($exitCode -eq 3010) {
        Write-Warning "Installation succeeded, but a reboot is required to complete the process."
        Write-Output "Reboot required to finalize the Wacom Drivers installation."
        exit 3010
    } elseif ($exitCode -ne 0) {
        Write-Error "ERROR: Wacom Drivers installation failed with exit code: $exitCode"
        exit $exitCode
    } else {
        Write-Output "Wacom Drivers installed successfully."
    }
} catch {
    Write-Output "ERROR: Exception occurred during installation. Details: $_"
    exit 1
} finally {
    Stop-Transcript
}
