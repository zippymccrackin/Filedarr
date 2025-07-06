Write-Debug "Init notify_server.ps1"

Write-Debug "    Adding to ChunkTransferredListeners (Length $($ChunkTransferredListeners.Length))"
$ChunkTransferredListeners += {
    param($status)

    $status['message'] = "File transfer in progress..."

    SendStatusToServer -status $status
}
Write-Debug "    Done adding to ChunkTransferredListeners (Length $($ChunkTransferredListeners.Length))"

Write-Debug "    Adding to TransferCompleteListeners (Length $($TransferCompleteListeners.Length))"
$TransferCompleteListeners += {
    param($status)

    $status['message'] = "File transfer complete"

    SendStatusToServer -status $status
}
Write-Debug "    Done adding to TransferCompleteListeners (Length $($TransferCompleteListeners.Length))"

function SendStatusToServer {
    param($status)

    $id = $status['id']

    $webhookUrl = "http://localhost:3565/transfer/$id"

    $json = $status | ConvertTo-Json -Depth 3
    $utf8 = [System.Text.Encoding]::UTF8.GetBytes($json)

    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $utf8 -ContentType "application/json"
    } catch {
        Write-Error "Failed to send update: $_"
    }
}

Write-Debug "Completed notify_server.ps1"