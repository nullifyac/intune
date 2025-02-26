#powershell.exe -WindowStyle hidden -ExecutionPolicy Bypass -File .\install.ps1

$logPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\JabraDirect_Install.log"
Start-Transcript -Path $logPath -Append

Write-Output "Starting Jabra Direct installation."

try {
    Write-Output "Installing Jabra Direct via Chocolatey..."
    choco install jabra-direct -y | Out-Null
    Write-Output "Jabra Direct installed successfully."
} catch {
    Write-Output "ERROR: Exception occurred during installation. Details: $_"
} finally {
    Stop-Transcript
}
