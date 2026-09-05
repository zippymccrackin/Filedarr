$utilPath = Join-Path $PSScriptRoot '..\core\util.ps1' | Resolve-Path
. $utilPath

if ( -not (Module-Enabled 'notify_server') ) {
    Write-Debug "notify_server module is disabled, skipping inclusion"
    return
}

$script:NotifyServerIncluded = $script:NotifyServerIncluded -or $false
if ($script:NotifyServerIncluded) { return }
$script:NotifyServerIncluded = $true

$Script:notify_serverVariables = Get-Module-Variables 'notify_server'
$Script:notify_serverUrl = $Script:notify_serverVariables.url
Write-Debug "Notify server URL: $Script:notify_serverUrl"

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

    # Reuse one HTTP client and allow at most one request in flight.
    if (-not $Script:statusHttpClient) {
        Add-Type -AssemblyName System.Net.Http
        $Script:statusHttpClient = [System.Net.Http.HttpClient]::new()
        $Script:statusHttpClient.Timeout = [TimeSpan]::FromSeconds(5)
    }
    if ($Script:statusTask) {
        if (-not $Script:statusTask.IsCompleted -and -not $WaitForJob) { return }
        try {
            $response = $Script:statusTask.GetAwaiter().GetResult()
            $response.EnsureSuccessStatusCode() | Out-Null
        } catch {
            Write-Warning "Failed to send progress update: $($_.Exception.Message)"
        } finally {
            if ($response) { $response.Dispose(); $response = $null }
            $Script:statusContent.Dispose()
            $Script:statusTask = $null
        }
    }
    $webhookUrl = "$Script:notify_serverUrl/transfer/$($status['id'])"
    $json = $status | ConvertTo-Json -Depth 5 -Compress
    $attempts = if ($WaitForJob) { 3 } else { 1 }
    for ($attempt = 0; $attempt -lt $attempts; $attempt++) {
        $Script:statusContent = [System.Net.Http.StringContent]::new($json, [System.Text.Encoding]::UTF8, 'application/json')
        $Script:statusTask = $Script:statusHttpClient.PostAsync($webhookUrl, $Script:statusContent)
        if (-not $WaitForJob) { return }
        try {
            $response = $Script:statusTask.GetAwaiter().GetResult()
            $response.EnsureSuccessStatusCode() | Out-Null
            return
        } catch {
            if ($attempt -eq $attempts - 1) {
                Write-Warning "Transfer finished, but final status could not be delivered: $($_.Exception.Message)"
            } else {
                Start-Sleep -Milliseconds 250
            }
        } finally {
            if ($response) { $response.Dispose(); $response = $null }
            $Script:statusContent.Dispose()
            $Script:statusTask = $null
        }
    }
}
