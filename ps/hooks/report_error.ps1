Write-Debug "Init report_error.ps1"

Write-Debug "    Adding to ReportErrorListeners (Length $($ReportErrorListeners.Length))"
$ReportErrorListeners += {
    param($err)

    SendErrorToServer $err
}
Write-Debug "    Done adding to ReportErrorListeners (Length $($ReportErrorListeners.Length))"

function SendErrorToServer {
    param($err)

    $webhookUrl = "http://localhost:3565/error"

    $json = @{
        message = $err
        callStack = (Get-PSCallStack | Out-String)
    } | ConvertTo-Json -Depth 3
    $utf8 = [System.Text.Encoding]::UTF8.GetBytes($json)

    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $utf8 -ContentType "application/json"
    } catch {
        Report-Error "Failed to send error: $_" -NotifyListeners $false
    }
}

Write-Debug "Completed report_error.ps1"