# Check for the Wacom Center executable
$wacomExePath = "C:\Program Files\Tablet\Wacom\WacomCenter\WacomCenterUI.exe"

if (Test-Path $wacomExePath) {
    Write-Output "Wacom Drivers are installed."
    exit 0
} else {
    Write-Output "Wacom Drivers are not installed."
    exit 1
}
