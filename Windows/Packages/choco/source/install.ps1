# Chocolatey Install Script using Official Chocolatey Install Command

try {
    # Define Chocolatey path
    $chocoPath = 'C:\ProgramData\chocolatey\bin'

    # Refresh PATH and check if Chocolatey is accessible
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
    
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Output "Installing Chocolatey using the official method..."

        # Official Chocolatey installation command
        Set-ExecutionPolicy Bypass -Scope Process -Force;
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    } else {
        Write-Output "Chocolatey is already installed and accessible."
    }

    # Add Chocolatey to PATH if not already present
    if ($env:Path -notmatch [regex]::Escape($chocoPath)) {
        Write-Output "Adding Chocolatey to PATH..."
        [System.Environment]::SetEnvironmentVariable("Path", "$env:Path;$chocoPath", [System.EnvironmentVariableTarget]::Machine)
        
        # Refresh the PATH for the current session
        $env:Path += ";$chocoPath"
    }

    # Verify Chocolatey installation
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Output "Chocolatey installation verified."
        exit 0
    } else {
        Write-Output "Chocolatey installation failed."
        exit 1
    }
}
catch {
    Write-Output "Chocolatey installation failed: $($_.Exception.Message)"
    exit 1
}
