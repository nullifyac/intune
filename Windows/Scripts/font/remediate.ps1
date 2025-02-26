$fontURLs = @(
    "https://example.com/NeueHelveticaforAS-Bold.otf"
)

$fontDir = "C:\Windows\Fonts"
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

foreach ($url in $fontURLs) {
    $fontName = [System.IO.Path]::GetFileName($url)
    $localFontPath = "$fontDir\$fontName"

    if (!(Test-Path $localFontPath)) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $localFontPath
            New-ItemProperty -Path $registryPath -Name $fontName -Value $localFontPath -PropertyType String -Force | Out-Null
            Write-Output "Installed: $fontName"
        } catch {
            Write-Output "Failed to download: $fontName"
        }
    } else {
        Write-Output "$fontName is already installed."
    }
}

Write-Output "Font installation process completed."
