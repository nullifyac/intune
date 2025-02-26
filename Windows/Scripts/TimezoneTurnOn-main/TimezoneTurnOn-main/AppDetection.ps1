$installedSdks = & "C:\Program Files\dotnet\dotnet.exe" --list-sdks
if ($installedSdks -match "8\.0\.402") {
    Write-Output "Detected"
    exit 0
} else {
    exit 1
}
