#powershell.exe -WindowStyle hidden -ExecutionPolicy Bypass -File .\install.ps1

# Path to the SketchUp Pro installer
$installerPath = Join-Path -Path $PSScriptRoot -ChildPath "SketchUp-2024-0-594-241.exe"

# Silent installation command
$arguments = "/silent"

# Execute the installer
Write-Host "Starting SketchUp 2024 installation..."
Start-Process -FilePath $installerPath -ArgumentList $arguments -Wait -NoNewWindow
Write-Host "SketchUp 2024 installation completed."
