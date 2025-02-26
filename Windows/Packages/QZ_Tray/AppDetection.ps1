# Define detection path
$detectionPath = "C:\Program Files\QZ Tray\qz-tray.exe"

if (Test-Path $detectionPath) {
    Write-Output "QZ Tray is installed."
    exit 0
} else {
    Write-Output "QZ Tray is not installed."
    exit 1
}
