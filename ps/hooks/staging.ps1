Write-Debug "Init staging.ps1"

$script:destinationFilePath = ""
$script:stagingPath = "\tmp\staging\"

Write-Debug "    Adding to SetDestinationPathListeners (Length $($SetDestinationPathListeners.Length))"
$SetDestinationPathListeners += {
    param($filepath)

    $script:destinationFilePath = $filepath

    $drive = [System.IO.Path]::getPathRoot($filepath)
    $stagingPath = Join-Path $drive $script:stagingPath

    Write-Debug "Staging path set to $stagingPath"

    # Create staging directory if needed
    if (!(Test-Path $stagingPath)) {
        New-Item -ItemType Directory $stagingPath | Out-Null
    }

    return $stagingPath
}
Write-Debug "    Done adding to SetDestinationPathListeners (Length $($SetDestinationPathListeners.Length))"

Write-Debug "    Adding to TransferWrapupListeners (Length $($TransferWrapupListeners.Length))"
$TransferWrapupListeners += {
    param($status)

    $status['message'] = "Moving file from staging"

    SendStatusToServer -status $status

    $stagedFile = $status['destination']

    Write-Debug "Staged file: $stagedFile"

    $filename = [System.IO.Path]::getFileName($stagedFile)

    if (!(Test-Path $script:destinationFilePath)) {
        New-Item -ItemType Directory $script:destinationFilePath | Out-Null
    }

    $destination = Join-Path $script:destinationFilePath $filename
    Write-Debug "Moving file $stagedFile to $destination"
    Move-Item -LiteralPath $stagedFile -Destination $destination
}
Write-Debug "    Done adding to TransferWrapupListeners (Length $($TransferWrapupListeners.Length))"

Write-Debug "Completed staging.ps1"