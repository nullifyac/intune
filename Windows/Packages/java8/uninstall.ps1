# uninstall.ps1

$BatchFilePath = Join-Path $PSScriptRoot 'java_nuker.bat'

Write-Host "Batch file path: $BatchFilePath"
if (Test-Path $BatchFilePath) {
    Write-Host "Batch file found."
} else {
    Write-Host "Batch file NOT found."
    exit 1
}

Start-Process -FilePath $BatchFilePath `
              -WindowStyle Hidden `
              -Wait
