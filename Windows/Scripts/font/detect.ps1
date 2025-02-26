$fonts = @(
    "NeueHelveticaforAS-Bold.otf",
    "NeueHelveticaforAS-BoldIt.otf",
    "NeueHelveticaforAS-Italic.otf",
    "NeueHelveticaforAS-Medium.otf",
    "NeueHelveticaforAS-MediumIt.otf",
    "NeueHelveticaforAS-Regular.otf"
)

$fontPath = "C:\Windows\Fonts"
$missingFonts = $false

foreach ($font in $fonts) {
    if (!(Test-Path "$fontPath\$font")) {
        $missingFonts = $true
    }
}

if ($missingFonts) {
    Write-Output "One or more fonts are missing."
    exit 1
} else {
    Write-Output "All fonts are installed."
    exit 0
}
