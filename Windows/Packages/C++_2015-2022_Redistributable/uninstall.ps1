#powershell.exe -WindowStyle hidden -ExecutionPolicy Bypass -File .\uninstall.ps1
Write-Host "Uninstalling Visual C++ Redistributables..."

# GUIDs for uninstalling - Update these if you're using newer versions
$x86GUID = "{C9F91221-B99B-4B06-B82E-C14376291BF4}" # Replace with actual x86 GUID
$x64GUID = "{C9F91222-B99B-4B06-B82E-C14376291BF4}" # Replace with actual x64 GUID

# Uninstall commands
Start-Process -FilePath "msiexec.exe" -ArgumentList "/X$x86GUID /quiet /norestart" -Wait
Start-Process -FilePath "msiexec.exe" -ArgumentList "/X$x64GUID /quiet /norestart" -Wait

Write-Host "Uninstallation completed."
