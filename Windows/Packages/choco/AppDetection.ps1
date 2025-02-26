# Chocolatey Detection Script

$chocoPath = "C:\ProgramData\chocolatey\bin\choco.exe"

if (Test-Path $chocoPath) {
    Write-Output "Chocolatey is installed."
    exit 0
} else {
    Write-Output "Chocolatey is not installed."
    exit 1
}
