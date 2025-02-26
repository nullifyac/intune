# Uninstallas a non-admin user

#powershell.exe -WindowStyle hidden -ExecutionPolicy Bypass -File .\uninstall.ps1

try {
    # Kill any running Visual Studio installer processes
    $processes = Get-Process -Name "setup", "vs_setup_bootstrapper" -ErrorAction SilentlyContinue
    if ($processes) {
        $processes | Stop-Process -Force
    }

    # Silent uninstall using Chocolatey
    choco uninstall visualstudio2022community -y

    # Verify the uninstallation
    $appPath = "$env:ProgramFiles\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe"
    
    if (-not (Test-Path $appPath)) {
        Write-Output "Uninstalled successfully."
        exit 0
    } else {
        Write-Output "Uninstallation failed."
        exit 1
    }
}
catch {
    Write-Output "Uninstallation failed: $($_.Exception.Message)"
    exit 1
}
