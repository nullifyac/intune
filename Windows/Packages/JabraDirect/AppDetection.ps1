# Define the expected hardcoded path for Jabra Direct executable
$appPath = "C:\Program Files (x86)\Jabra\Direct6\jabra-direct.exe"

# Check for the existence of the file
if (Test-Path $appPath) {
    Write-Output "Jabra Direct is installed at $appPath."
    exit 0
} else {
    Write-Output "Jabra Direct is not installed at expected path: $appPath."
    exit 1
}
