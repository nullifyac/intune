#powershell.exe -WindowStyle hidden -ExecutionPolicy Bypass -File .\uninstall.ps1

# Path to the uninstaller executable
$uninstallerPath = "C:\Program Files (x86)\InstallShield Installation Information\{254252d5-9a26-4c38-bc17-6283e2fd9316}\SketchUp-2024-0-594-241.exe"

# Check if the uninstaller exists
if (Test-Path -Path $uninstallerPath) {
    Write-Host "Starting SketchUp Pro 2024 silent uninstallation..."
    Start-Process -FilePath $uninstallerPath -ArgumentList "-remove -runfromtemp -silent" -Wait -NoNewWindow
    Write-Host "SketchUp Pro 2024 uninstallation completed silently."
} else {
    Write-Host "Uninstaller for SketchUp Pro 2024 not found."
    exit 1
}
