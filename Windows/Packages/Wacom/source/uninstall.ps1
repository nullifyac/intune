#powershell.exe -WindowStyle hidden -ExecutionPolicy Bypass -File .\uninstall.ps1

$logPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\WacomDrivers_Uninstall.log"
Start-Transcript -Path $logPath -Append

Write-Output "Starting Wacom Drivers uninstallation."

try {
    Write-Output "Uninstalling Wacom Drivers via Chocolatey..."
    choco uninstall wacom-drivers -y --no-progress | Out-Null
    $exitCode = $LASTEXITCODE
    Write-Output "Chocolatey uninstall exit code: $exitCode"

    if ($exitCode -ne 0) {
        Write-Error "ERROR: Wacom Drivers uninstallation failed with exit code: $exitCode"
        exit $exitCode
    } else {
        Write-Output "Wacom Drivers uninstalled successfully."
    }
} catch {
    Write-Output "ERROR: Exception occurred during uninstallation. Details: $_"
    exit 1
} finally {
    Stop-Transcript
}
