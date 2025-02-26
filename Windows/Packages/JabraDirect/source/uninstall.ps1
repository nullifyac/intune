#powershell.exe -WindowStyle hidden -ExecutionPolicy Bypass -File .\uninstall.ps1

$logPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\JabraDirect_Uninstall.log"
Start-Transcript -Path $logPath -Append

Write-Output "Starting Jabra Direct uninstallation."

try {
    Write-Output "Uninstalling Jabra Direct via Chocolatey..."
    choco uninstall jabra-direct -y | Out-Null
    Write-Output "Jabra Direct uninstalled successfully."
} catch {
    Write-Output "ERROR: Exception occurred during uninstallation. Details: $_"
} finally {
    Stop-Transcript
}
