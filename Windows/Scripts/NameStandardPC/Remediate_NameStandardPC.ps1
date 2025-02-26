# Define the registry path and key
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}"
$valueName = "(Default)"
$desiredValueData = "$env:COMPUTERNAME"

# Check if the registry path exists; if not, create it
if (!(Test-Path -Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

# Remediation: Set the correct value
Set-ItemProperty -Path $regPath -Name $valueName -Value $desiredValueData

# Verify the change
$newValueData = (Get-ItemProperty -Path $regPath -Name $valueName).$valueName

# Restart Explorer to apply the change
Stop-Process -Name explorer -Force
Start-Process explorer

if ($newValueData -eq $desiredValueData) {
    Write-Output "Remediation successful. The registry key has been updated."
    exit 0
} else {
    Write-Output "Remediation failed. The registry key could not be updated."
    exit 1
}
