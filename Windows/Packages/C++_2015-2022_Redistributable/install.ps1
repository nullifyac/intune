#powershell.exe -WindowStyle hidden -ExecutionPolicy Bypass -File .\install.ps1
Write-Host "Installing Visual C++ Redistributables..."

# Path to the executables
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$x86Path = Join-Path $scriptPath "VC_redist.x86.exe"
$x64Path = Join-Path $scriptPath "VC_redist.x64.exe"

# Execute installations
Start-Process -FilePath $x86Path -ArgumentList "/quiet /norestart" -Wait
Start-Process -FilePath $x64Path -ArgumentList "/quiet /norestart" -Wait

Write-Host "Installation completed."
