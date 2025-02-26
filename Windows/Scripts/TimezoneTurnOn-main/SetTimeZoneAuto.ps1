# Define the log file path
$LogDirectory = "C:\Logs"
$LogPath = "$LogDirectory\timezone_script.log"

# Ensure the log directory exists
if (-not (Test-Path -Path $LogDirectory)) {
    New-Item -Path $LogDirectory -ItemType Directory -Force *>$null
}

# Set timezone
try {
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate' `
                     -Name 'Start' -Value 3 -PropertyType DWord *>$null
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' `
                     -Name 'Value' -Value 'Allow' *>$null
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters' `
                     -Name 'Type' -Value 'NTP' *>$null
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters' `
                     -Name 'NtpServer' -Value 'time.windows.com,0x9' *>$null
} 
catch {
    # Capture the error message
    $ErrorMessage = "$(Get-Date) - $($_.Exception.Message)"
    
    # Log the error to the specified log file
    Add-Content -Path $LogPath -Value $ErrorMessage
}

exit
