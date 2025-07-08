Write-Debug "Init report_error.ps1"

Write-Debug "    Adding to ReportErrorListeners (Length $($ReportErrorListeners.Length))"
$ReportErrorListeners += {
    param($error)

    SendErrorToServer $error
}
Write-Debug "    Done adding to ReportErrorListeners (Length $($ReportErrorListeners.Length))"

function SendErrorToServer {
    param($error)

    $webhookUrl = "http://localhost:3565/error"

    $json = @{
        message: $error
    } | ConvertTo-Json -Depth 3
    $utf8 = [System.Text.Encoding]::UTF8.GetBytes($json)

    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $utf8 -ContentType "application/json"
    } catch {
        Report-Error "Failed to send error: $_" -NotifyListeners $false
    }
}

Write-Debug "Completed report_error.ps1"