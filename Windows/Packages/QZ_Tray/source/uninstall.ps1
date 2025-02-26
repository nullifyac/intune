# Define log path
$logPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\QZ_Tray_Uninstall.log"
Start-Transcript -Path $logPath -Append

Write-Output "Starting QZ Tray uninstallation."

try {
    # Define uninstall path
    $uninstallPath = "C:\Program Files\QZ Tray\uninstall.exe"

    if (Test-Path $uninstallPath) {
        Write-Output "Uninstalling QZ Tray silently..."
        Start-Process -FilePath $uninstallPath -ArgumentList "/S" -Wait
        Write-Output "QZ Tray uninstalled successfully."
    } else {
        Write-Output "QZ Tray is not installed."
    }
} catch {
    Write-Output "ERROR: Exception occurred during QZ Tray uninstallation. Details: $_"
} finally {
    Stop-Transcript
}
