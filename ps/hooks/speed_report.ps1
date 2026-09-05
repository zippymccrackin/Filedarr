$utilPath = Join-Path $PSScriptRoot '..\core\util.ps1' | Resolve-Path
. $utilPath
if (-not (Module-Enabled 'speed_report')) { return }
$Script:speed_reportVariables = Get-Module-Variables 'speed_report'
$Script:recentStats = @()

$Global:SetStatusInformationListeners += {
    param($status)
    $now = $status.timestamp
    $Script:recentStats = @($Script:recentStats | Where-Object { $_ })
    $Script:recentStats += [PSCustomObject]@{ time = $now; bytes = $status.transferred }
    $window = [double]$Script:speed_reportVariables.intervalCheckSeconds
    if ($window -le 0) { $window = 5 }
    $cutoff = $now.AddSeconds(-$window)
    # Keep one baseline at or before the window. A slow chunk must not erase
    # every earlier sample and falsely report zero after making progress.
    while ($Script:recentStats.Count -gt 2 -and $Script:recentStats[1].time -le $cutoff) {
        $Script:recentStats = @($Script:recentStats | Select-Object -Skip 1)
    }
    $speed = $null
    if ($Script:recentStats.Count -ge 2) {
        $first = $Script:recentStats[0]
        $seconds = ($now - $first.time).TotalSeconds
        if ($seconds -gt 0) { $speed = [math]::Max(0, ($status.transferred - $first.bytes) / $seconds) }
    } elseif ($status.elapsed_sec -gt 0) {
        $speed = $status.transferred / $status.elapsed_sec
    }
    $status['speed_mb_s'] = if ($null -ne $speed) { [math]::Round($speed / 1MB, 2) } else { $null }
    $status['eta'] = $null
    $remaining = $status.total - $status.transferred
    if ($remaining -gt 0 -and $speed -gt 0) {
        $etaSeconds = [math]::Min(315360000, [math]::Ceiling($remaining / $speed))
        $span = [TimeSpan]::FromSeconds($etaSeconds)
        $status['eta'] = '{0:00}:{1:00}:{2:00}' -f [math]::Floor($span.TotalHours), $span.Minutes, $span.Seconds
    }
    if ($status.diagnostics.phase -eq 'queued') {
        $status['speed_mb_s'] = $null
        $status['eta'] = $null
    }
    return $status
}
