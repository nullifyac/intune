# Detection Method Script

try {
    # Get the latest version of Postman online
    $JBNSearch = winget.exe search -e --id Postman.Postman --accept-source-agreements
    $JBNOnlineVersion = (-split $JBNSearch[-1])[-2]
    
    # Get the locally installed version
    $JBNLocalSearch = winget.exe list -e --id Postman.Postman
    
    # Check if "Available" is in the output
    $JBNCheckIfAvailableExist = (-split $JBNLocalSearch[-3])[-2]
    
    if ($JBNCheckIfAvailableExist -eq "Available") {
        $JBNLocalVersion = (-split $JBNLocalSearch[-1])[-3]
    } else {
        $JBNLocalVersion = (-split $JBNLocalSearch[-1])[-2]
    }
    
    if ($JBNLocalVersion -eq "input") {
        Write-Output "Detection failed: No local version detected."
        exit 1
    }
    
    # Compare versions
    if ($JBNLocalVersion -ge $JBNOnlineVersion) {
        Write-Output "The device has the latest version of Postman installed."
        exit 0
    } else {
        Write-Output "The local version of Postman is outdated."
        exit 1
    }
}
catch {
    Write-Output "Detection script failed: $($_.Exception.Message)"
    exit 1
}
