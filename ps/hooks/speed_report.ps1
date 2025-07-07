Write-Debug "Init speed_report.ps1"

$script:recentStats = @()  # list of @{time=..., bytes=...}

Write-Debug "    Adding to SetStatusInformationListeners (Length $($SetStatusInformationListeners.Length))"
$SetStatusInformationListeners += {
    param($status)

    $now = $status['timestamp']
    $totalRead = $status['transferred']
    $totalSize = $status['total']

    $script:recentStats += [PSCustomObject]@{ time = $now; bytes = $totalRead }

    # Remove entries older than 5 seconds
    $script:recentStats = @( 
        if ($script:recentStats -is [System.Collections.IEnumerable]) {
            $script:recentStats | Where-Object { $_ -and ($now - $_.time).TotalSeconds -le 5 }
        } elseif ($script:recentStats) {
            if (($now - $script:recentStats.time).TotalSeconds -le 5) { $script:recentStats }
        }
    )

    # Calculate speed based on the first and last entries
    $recentSpeed = 0
    if ($script:recentStats.Count -ge 2) {
        $oldest = $script:recentStats[0]
        $newest = $script:recentStats[-1]

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