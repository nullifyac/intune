# Define the registry path for x64 Redistributable
$x64Path = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"

# Check x64 Redistributable
if (Test-Path $x64Path) {
    $x64Registry = Get-ItemProperty -Path $x64Path -ErrorAction SilentlyContinue
    if ($x64Registry -and $x64Registry.Installed -eq 1 -and $x64Registry.Version -eq "v14.42.34433.00") {
        Write-Output "Visual C++ Redistributables are installed (assumed from x64)."
        exit 0
    }
}

# If not detected, return failure
Write-Output "Visual C++ Redistributables are missing or incorrect version."
exit 1
