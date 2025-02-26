# Path to the SketchUp executable
$sketchUpPath = "C:\Program Files\SketchUp\SketchUp 2024\SketchUp.exe"

# Check if the SketchUp executable exists
if (Test-Path -Path $sketchUpPath) {
    Write-Output "SketchUp Pro 2024 is installed."
    exit 0
} else {
    Write-Output "SketchUp Pro 2024 is not installed."
    exit 1
}
