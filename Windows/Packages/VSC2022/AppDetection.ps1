try {
    # Define the path to the Visual Studio executable (adjusted for admin installation path)
    $VSExecutablePath = "$env:ProgramFiles\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe"

    # Check if the executable exists
    if (Test-Path $VSExecutablePath) {
        Write-Output "Visual Studio 2022 Community is installed."
        exit 0
    } else {
        Write-Output "Visual Studio 2022 Community is not installed on this device."
        exit 1
    }
}
catch {
    Write-Output "Detection script failed: $($_.Exception.Message)"
    exit 1
}
