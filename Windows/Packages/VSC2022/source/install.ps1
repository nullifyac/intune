# Install as a non-admin user

#powershell.exe -WindowStyle hidden -ExecutionPolicy Bypass -File .\install.ps1

try {
    # Kill any running Visual Studio installer processes
    $processes = Get-Process -Name "setup", "vs_setup_bootstrapper" -ErrorAction SilentlyContinue
    if ($processes) {
        $processes | Stop-Process -Force
    }

    # Silent install using Chocolatey
    choco install visualstudio2022community -y --params "'--add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.NetWeb'"
  
    # Verify the installation
    $appPath = "$env:ProgramFiles\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe"
    
    if (Test-Path $appPath) {
        Write-Output "Installed successfully."
        exit 0
    } else {
        Write-Output "Installation failed."
        exit 1
    }
}
catch {
    Write-Output "Installation failed: $($_.Exception.Message)"
    exit 1
}
