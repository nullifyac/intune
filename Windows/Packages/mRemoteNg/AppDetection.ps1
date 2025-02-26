# Detection script

$appPath = Join-Path "${env:ProgramFiles(x86)}" "mRemoteNG\mRemoteNG.exe"

if (Test-Path $appPath) {
    Write-Output "mRemoteNG is installed."
    exit 0
} else {
    Write-Output "mRemoteNG is not installed."
    exit 1
}
