$utilPath = Join-Path $PSScriptRoot '..\core\util.ps1' | Resolve-Path
. $utilPath

if ( -not (Module-Enabled 'notify_server') ) {
    Write-Debug "notify_server module is disabled, skipping inclusion"
    return
}

$script:NotifyServerIncluded = $script:NotifyServerIncluded -or $false
if ($script:NotifyServerIncluded) { return }
$script:NotifyServerIncluded = $true

$Script:variables = Get-Module-Variables 'notify_server'
$Script:url = $Script:variables.url
Write-Debug "Notify server URL: $Script:url"

$Script:sequence = 0

Write-Debug "Init notify_server.ps1"

Write-Debug "    Adding to ChunkTransferredListeners (Length $($ChunkTransferredListeners.Length))"
$Global:ChunkTransferredListeners += {
    param($status)

    $status['message'] = "File transfer in progress..."

    SendStatusToServer -status $status
}
Write-Debug "    Done adding to ChunkTransferredListeners (Length $($ChunkTransferredListeners.Length))"

Write-Debug "    Adding to TransferCompleteListeners (Length $($TransferCompleteListeners.Length))"
$Global:TransferCompleteListeners += {
    param($status)

    $status['message'] = "File transfer complete"

    SendStatusToServer -status $status -WaitForJob $True
}
Write-Debug "    Done adding to TransferCompleteListeners (Length $($TransferCompleteListeners.Length))"

function SendStatusToServer {
    param(
        $status,
        [bool]$WaitForJob = $false
    )

    $status['sequence'] = $Script:sequence
    $Script:sequence++

    $id = $status['id']
    $webhookUrl = "$Script:url/transfer/$id"
    $json = $status | ConvertTo-Json -Depth 3

    Write-Debug "Sending status to $webhookUrl : $json"
    $job = Start-Job -ScriptBlock {
        param($webhookUrl, $json)
        try {
            $utf8 = [System.Text.Encoding]::UTF8.GetBytes($json)

            Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $utf8 -ContentType "application/json"
        } catch {
            $exceptionMessage = $_.Exception.Message
            Report-Error "Failed to send update: $exceptionMessage"
        }
    } -ArgumentList $webhookUrl, $json

    if( $WaitForJob ) {
        Wait-Job $job
    }
}

Write-Debug "Completed notify_server.ps1"