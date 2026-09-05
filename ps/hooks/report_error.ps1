$utilPath = Join-Path $PSScriptRoot '..\core\util.ps1' | Resolve-Path
. $utilPath

if ( -not (Module-Enabled 'report_error') ) {
    Write-Debug "report_error module is disabled, skipping inclusion"
    return
}

$Script:report_errorVariables = Get-Module-Variables 'report_error'
$Script:report_errorUrl = $Script:report_errorVariables.url

Write-Debug "Init report_error.ps1"

Write-Debug "    Adding to ReportErrorListeners (Length $($ReportErrorListeners.Length))"
$Global:ReportErrorListeners += {
    param($msg)

    SendErrorToServer $msg
}
Write-Debug "    Done adding to ReportErrorListeners (Length $($ReportErrorListeners.Length))"

function SendErrorToServer {
    param($msg)

    $webhookUrl = "$Script:report_errorUrl/error"

    $json = @{
        message = $msg
        callStack = (Get-PSCallStack | Out-String)
    } | ConvertTo-Json -Depth 3
    $utf8 = [System.Text.Encoding]::UTF8.GetBytes($json)

    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $utf8 -ContentType "application/json" -TimeoutSec 5
    } catch {
        $exceptionMessage = $_.Exception.Message
        Report-Error "Failed to send error: $exceptionMessage" -NotifyListeners $False
    }
}

Write-Debug "Completed report_error.ps1"