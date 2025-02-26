# Define log path
$logPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\QZ_Tray_Install.log"
Start-Transcript -Path $logPath -Append

Write-Output "Starting QZ Tray installation."

try {
    # Set execution policy for the current process
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
    Write-Output "Execution policy set to RemoteSigned for the current process."

    # Download and install QZ Tray silently using the latest stable release
    Write-Output "Downloading and installing the latest stable release of QZ Tray..."
    Invoke-Expression (Invoke-RestMethod -Uri "https://pwsh.sh")
    Write-Output "QZ Tray installed successfully."
} catch {
    Write-Output "ERROR: Exception occurred during QZ Tray installation. Details: $_"
} finally {
    Stop-Transcript
}
