$ChunkSizeListeners += {
    param($status)

    $status['message'] = "File transfer in progress..."

    SendStatusToServer -status $status
}

$StagingStartingListeners += {
    param($status)

    $status['message'] = "Moving file from staging"

    SendStatusToServer -status $status
}

$TransferCompleteListeners += {
    param($status)

    $status['message'] = "File transfer complete"

    SendStatusToServer -status $status
}

function SendStatusToServer {
    param($status)

    $id = $status['id']

    $webhookUrl = "http://localhost:3565/transfer/$id"

    $json = $status | ConvertTo-Json -Depth 3
    $utf8 = [System.Text.Encoding]::UTF8.GetBytes($json)

    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $utf8 -ContentType "application/json"
    } catch {
        Write-Host "Failed to send update: $_"
    }
}