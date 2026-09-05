$Script:networkPrevious = @{}
$Script:networkReport = @()
$Script:networkCheckedAt = [datetime]::MinValue

function Get-TransferNetworkDiagnostics {
    $now = [datetime]::UtcNow
    if (($now - $Script:networkCheckedAt).TotalSeconds -lt 5) { return $Script:networkReport }
    $Script:networkCheckedAt = $now
    $report = @()
    try {
        foreach ($adapter in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
            if ($adapter.OperationalStatus -ne 'Up' -or $adapter.NetworkInterfaceType -eq 'Loopback') { continue }
            $stats = $adapter.GetIPv4Statistics()
            $previous = $Script:networkPrevious[$adapter.Id]
            $rx = $null; $tx = $null; $errors = $null; $discards = $null
            if ($previous) {
                $seconds = ($now - $previous.time).TotalSeconds
                if ($seconds -gt 0) {
                    $rx = [math]::Round([math]::Max(0, $stats.BytesReceived - $previous.received) / $seconds / 1MB, 2)
                    $tx = [math]::Round([math]::Max(0, $stats.BytesSent - $previous.sent) / $seconds / 1MB, 2)
                    $errors = [math]::Max(0, $stats.IncomingPacketsWithErrors + $stats.OutgoingPacketsWithErrors - $previous.errors)
                    $discards = [math]::Max(0, $stats.IncomingPacketsDiscarded + $stats.OutgoingPacketsDiscarded - $previous.discards)
                }
            }
            $Script:networkPrevious[$adapter.Id] = @{
                time = $now; received = $stats.BytesReceived; sent = $stats.BytesSent
                errors = $stats.IncomingPacketsWithErrors + $stats.OutgoingPacketsWithErrors
                discards = $stats.IncomingPacketsDiscarded + $stats.OutgoingPacketsDiscarded
            }
            $report += @{
                name = $adapter.Name; type = $adapter.NetworkInterfaceType.ToString()
                link_mbps = [math]::Round($adapter.Speed / 1000000, 0)
                receive_mb_s = $rx; send_mb_s = $tx; errors_delta = $errors; discards_delta = $discards
            }
        }
    } catch {
        # Diagnostics must never fail a copy when Windows counters are unavailable.
        $report = @(@{ name = 'Network counters unavailable'; error = $_.Exception.Message })
    }
    $Script:networkReport = $report
    return $report
}

function Get-CopyDiagnostics {
    param($snapshot, [double]$stallSeconds = 5)
    $phase = $snapshot.Phase
    $summary = 'Copying with overlapping reads and writes'
    $advice = ''
    if ($phase -eq 'queued') {
        $summary = 'Queued: another Filedarr transfer is using this destination volume'
        $advice = 'The per-destination transfer limit reduces disk and share contention.'
    } elseif ($phase -eq 'flushing') {
        $summary = 'Waiting for the destination to flush buffered data'
        $advice = 'The copy is not complete until the destination acknowledges the flush. Check destination disk load and, for a share, the remote machine.'
    } elseif ($phase -eq 'opening_source') {
        $summary = 'Opening source file'
        $advice = 'If this persists, check access to the source path and the source machine.'
    } elseif ($phase -eq 'opening_destination') {
        $summary = 'Opening destination file'
        $advice = 'If this persists, check destination share access and remote disk availability.'
    } elseif ($phase -eq 'failed') {
        $summary = 'Copy failed: ' + $snapshot.Error
        $advice = 'The source has been retained. Inspect the destination before retrying.'
    } elseif ($phase -eq 'copied') {
        $summary = 'Copy and flush verified; finalizing import'
    } elseif ($snapshot.WritePendingSeconds -ge $stallSeconds -and $snapshot.ReadPendingSeconds -ge $stallSeconds) {
        $summary = 'Stalled: both source read and destination write are waiting'
        $advice = 'Check both paths. For network paths, inspect adapter errors, link speed, and disk activity on the other machine.'
    } elseif ($snapshot.WritePendingSeconds -ge $stallSeconds) {
        $summary = 'Stalled: waiting for destination write'
        $advice = 'The destination is not acknowledging writes. Check its disk load, free space and, for a share, the network and remote machine.'
    } elseif ($snapshot.ReadPendingSeconds -ge $stallSeconds) {
        $summary = 'Stalled: waiting for source read'
        $advice = 'The source is not supplying data. Check its disk load and, for a share, the network and remote machine.'
    } elseif ($snapshot.DelayMs -gt 0) {
        $summary = 'Deliberate transfer throttling is enabled'
        $advice = 'Check defaultDelayMs and plex_slowdown in config.yml. The limit shown excludes disk and network overhead.'
    } elseif ($snapshot.ActiveSeconds -ge 5) {
        if ($snapshot.ReadSeconds -gt 2 * $snapshot.WriteSeconds) {
            $summary = 'Source reads are taking longer than destination writes'
            $advice = 'Measured at the file API; a network read includes the network and remote disk. Check the source side first.'
        } elseif ($snapshot.WriteSeconds -gt 2 * $snapshot.ReadSeconds) {
            $summary = 'Destination writes are taking longer than source reads'
            $advice = 'Measured at the file API; a network write includes the network and remote disk. Check the destination side first.'
        }
    }
    $limit = $null
    if ($snapshot.DelayMs -gt 0) { $limit = [math]::Round($snapshot.ChunkSize / 1MB * 1000 / $snapshot.DelayMs, 2) }
    return @{
        phase = $phase; summary = $summary; advice = $advice
        phase_sec = [math]::Round($snapshot.PhaseSeconds, 1)
        idle_sec = [math]::Round($snapshot.IdleSeconds, 1)
        read_pending_sec = [math]::Round($snapshot.ReadPendingSeconds, 2)
        write_pending_sec = [math]::Round($snapshot.WritePendingSeconds, 2)
        read_sec = [math]::Round($snapshot.ReadSeconds, 2)
        write_sec = [math]::Round($snapshot.WriteSeconds, 2)
        throttle_sec = [math]::Round($snapshot.ThrottleSeconds, 2)
        max_read_sec = [math]::Round($snapshot.MaxReadSeconds, 2)
        max_write_sec = [math]::Round($snapshot.MaxWriteSeconds, 2)
        read_operations = $snapshot.ReadOperations; write_operations = $snapshot.WriteOperations
        throttle_limit_mb_s = $limit
        network = @(Get-TransferNetworkDiagnostics)
    }
}
