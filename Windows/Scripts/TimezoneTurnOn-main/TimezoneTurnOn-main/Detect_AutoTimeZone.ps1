$ServiceName = 'tzautoupdate'
$ExpectedAction = 'Manual'
$ExpectedRegistryValue = 3
$RegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate'
$RegistryKey = 'Start'

# Get the service object
$Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

# Get the registry value
$RegistryValue = (Get-ItemProperty -Path $RegistryPath -Name $RegistryKey -ErrorAction SilentlyContinue).$RegistryKey

# Check if the service start type and registry value are both correct
if ($Service.StartType -eq $ExpectedAction -and $RegistryValue -eq $ExpectedRegistryValue) {
    Write-Host "$ServiceName is already configured correctly with start type '$ExpectedAction' and registry value '$RegistryValue'."
    Exit 0
}
else {
    Write-Warning "$ServiceName is not configured correctly. Expected start type '$ExpectedAction' and registry value '$ExpectedRegistryValue'."
    Exit 1
}
