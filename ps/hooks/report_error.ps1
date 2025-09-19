$utilPath = Join-Path $PSScriptRoot '..\core\util.ps1' | Resolve-Path
. $utilPath

Write-Debug "Init report_error.ps1"

Write-Debug "    Adding to ReportErrorListeners (Length $($ReportErrorListeners.Length))"
$Global:ReportErrorListeners += {
    param($msg)

    SendErrorToServer $msg
}
Write-Debug "    Done adding to ReportErrorListeners (Length $($ReportErrorListeners.Length))"

function SendErrorToServer {
    param($msg)

    $webhookUrl = "http://localhost:3565/error"

    $json = @{
        message = $msg
    } | ConvertTo-Json -Depth 3
    $utf8 = [System.Text.Encoding]::UTF8.GetBytes($json)

    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $utf8 -ContentType "application/json"
    } catch {
        $exceptionMessage = $_.Exception.Message
        Report-Error "Failed to send error: $exceptionMessage" -NotifyListeners $False
    }
}

Write-Debug "Completed report_error.ps1"