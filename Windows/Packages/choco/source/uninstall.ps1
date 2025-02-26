# Chocolatey Uninstall Script

try {
    # Remove the main Chocolatey installation folder
    if ($env:ChocolateyInstall -ne '' -and $env:ChocolateyInstall -ne $null) {
        Write-Output "Removing Chocolatey installation folder..."
        Remove-Item -Recurse -Force "$env:ChocolateyInstall"
    }

    # Remove Chocolatey from the PATH for Current User
    $userPath = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment').GetValue('PATH', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames).ToString()
    $userPath = [System.Text.RegularExpressions.Regex]::Replace($userPath, [System.Text.RegularExpressions.Regex]::Escape("$env:ChocolateyInstall\bin") + '(?>;)?', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    [System.Environment]::SetEnvironmentVariable('PATH', $userPath, 'User')

    # Remove Chocolatey from the PATH for Local Machine
    $machinePath = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment\').GetValue('PATH', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames).ToString()
    $machinePath = [System.Text.RegularExpressions.Regex]::Replace($machinePath, [System.Text.RegularExpressions.Regex]::Escape("$env:ChocolateyInstall\bin") + '(?>;)?', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    [System.Environment]::SetEnvironmentVariable('PATH', $machinePath, 'Machine')

    # Remove ChocolateyBinRoot if it exists
    if ($env:ChocolateyBinRoot -ne '' -and $env:ChocolateyBinRoot -ne $null) {
        Write-Output "Removing ChocolateyBinRoot folder..."
        Remove-Item -Recurse -Force "$env:ChocolateyBinRoot"
    }

    # Remove ChocolateyToolsRoot if it exists
    if ($env:ChocolateyToolsRoot -ne '' -and $env:ChocolateyToolsRoot -ne $null) {
        Write-Output "Removing ChocolateyToolsRoot folder..."
        Remove-Item -Recurse -Force "$env:ChocolateyToolsRoot"
    }

    # Clear Chocolatey environment variables
    [System.Environment]::SetEnvironmentVariable("ChocolateyBinRoot", $null, 'User')
    [System.Environment]::SetEnvironmentVariable("ChocolateyToolsLocation", $null, 'User')

    Write-Output "Chocolatey uninstalled successfully."
    exit 0
}
catch {
    Write-Output "Chocolatey uninstallation failed: $($_.Exception.Message)"
    exit 1
}
