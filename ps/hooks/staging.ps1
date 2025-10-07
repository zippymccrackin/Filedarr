$utilPath = Join-Path $PSScriptRoot '..\core\util.ps1' | Resolve-Path
. $utilPath

if ( -not ( Module-Enabled 'staging' ) ) {
    Write-Debug "staging module is disabled, skipping inclusion"
    return
}

$Script:variables = Get-Module-Variables 'staging'

Write-Debug "Init staging.ps1"

$Script:destinationFilePath = ""
$Script:stagingPath = $Script:variables.stagingPath
Write-Debug "All staging variables: $( $Script:variables | ConvertTo-Json -Depth 5 )"
Write-Debug "Staging path variable set to: $Script:stagingPath"

Write-Debug "Require notify_server.ps1"
if ( Module-Enabled 'notify_server' ) {
    $notifyServerPath = Join-Path $PSScriptRoot 'notify_server.ps1' | Resolve-Path
    . $notifyServerPath
} else {
    Write-Debug "notify_server module is not enabled, skipping inclusion"
}

Write-Debug "    Adding to SetDestinationPathListeners (Length $($SetDestinationPathListeners.Length))"
$Global:SetDestinationPathListeners += {
    param($filepath)

    $Script:destinationFilePath = $filepath

    Write-Debug "Staging path variable: $Script:stagingPath"
    $drive = [System.IO.Path]::getPathRoot($filepath)
    $stagingPath = Join-Path $drive $Script:stagingPath

    Write-Debug "Staging path set to $stagingPath"

    # Create staging directory if needed
    if (!(Test-Path $stagingPath)) {
        New-Item -ItemType Directory $stagingPath | Out-Null
    }

    return $stagingPath
}
Write-Debug "    Done adding to SetDestinationPathListeners (Length $($SetDestinationPathListeners.Length))"

Write-Debug "    Adding to TransferWrapupListeners (Length $($TransferWrapupListeners.Length))"
$Global:TransferWrapupListeners += {
    param($status)

    $status['message'] = "Moving file from staging"

    if (Module-Enabled 'notify_server') {
        SendStatusToServer -status $status
    }

    $stagedFile = $status['destination']

    Write-Debug "Staged file: $stagedFile"

    $filename = [System.IO.Path]::getFileName($stagedFile)

    if (!(Test-Path $Script:destinationFilePath)) {
        New-Item -ItemType Directory $Script:destinationFilePath | Out-Null
    }

    $destination = Join-Path $Script:destinationFilePath $filename
    Write-Debug "Moving file $stagedFile to $destination"
    Move-Item -LiteralPath $stagedFile -Destination $destination
}
Write-Debug "    Done adding to TransferWrapupListeners (Length $($TransferWrapupListeners.Length))"

Write-Debug "Completed staging.ps1"