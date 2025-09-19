Write-Debug "Init speed_report.ps1"

$Script:recentStats = @()  # list of @{time=..., bytes=...}

Write-Debug "    Adding to SetStatusInformationListeners (Length $($SetStatusInformationListeners.Length))"
$Global:SetStatusInformationListeners += {
    param($status)

    $now = $status['timestamp']
    $totalRead = $status['transferred']
    $totalSize = $status['total']

    $Script:recentStats += [PSCustomObject]@{ time = $now; bytes = $totalRead }

    # Remove entries older than 5 seconds
    $Script:recentStats = @( 
        if ($Script:recentStats -is [System.Collections.IEnumerable]) {
            $Script:recentStats | Where-Object { $_ -and ($now - $_.time).TotalSeconds -le 5 }
        } elseif ($Script:recentStats) {
            if (($now - $Script:recentStats.time).TotalSeconds -le 5) { $Script:recentStats }
        }
    )

    # Calculate speed based on the first and last entries
    $recentSpeed = 0
    if ($Script:recentStats.Count -ge 2) {
        $oldest = $Script:recentStats[0]
        $newest = $Script:recentStats[-1]

        $deltaBytes = $newest.bytes - $oldest.bytes
        $deltaTime = ($newest.time - $oldest.time).TotalSeconds

        $recentSpeed = if ($deltaTime -gt 0) { $deltaBytes / $deltaTime } else { 0 }
    }
    
    $remaining = $totalSize - $totalRead
    
    $etaSeconds = if ($recentSpeed -gt 0) { [math]::Round($remaining / $recentSpeed) } else { 0 }
    $eta = [TimeSpan]::FromSeconds($etaSeconds).ToString("hh\:mm\:ss")

    $status['eta'] = $eta
    $status['speed_mb_s'] = [math]::Round($recentSpeed / 1MB, 2)

    return $status
}
Write-Debug "    Done adding to SetStatusInformationListeners (Length $($SetStatusInformationListeners.Length))"

Write-Debug "Completed speed_report.ps1"