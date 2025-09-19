Write-Debug "plex_slowdown.ps1"

# Plex Setup
$Script:plexToken = "Uw2D4x6pX3Ue7CDF6Zan"
$Script:plexUrl = "http://localhost:32400/status/sessions?X-Plex-Token=$plexToken"
$Script:IntervalCheckSeconds = 5

$Script:plexStreaming = $False

Write-Debug "    Adding to ChunkSizeListeners (Length $($ChunkSizeListeners.Length))"
$Global:ChunkSizeListeners += {
    param($chunkSize)

    Update-PlexStreamingStatus

    if ($Script:plexStreaming) {
        $chunkSize = 1MB
    }

    return $chunkSize
}
Write-Debug "    Done adding to ChunkSizeListeners (Length $($ChunkSizeListeners.Length))"

Write-Debug "    Adding to DelayMsListeners (Length $($DelayMsListeners.Length))"
$Global:DelayMsListeners += {
    param($delayMs)

    Update-PlexStreamingStatus

    if ($Script:plexStreaming) {
        $delayMs = 150
    }

    return $delayMs
}
Write-Debug "    Done adding to DelayMsListeners (Length $($DelayMsListeners.Length))"

function Update-PlexStreamingStatus {
    if (-not $Script:lastPlexUpdate) {
        $Script:lastPlexUpdate = Get-Date
    }

    if ((New-TimeSpan $Script:lastPlexUpdate (Get-Date)).TotalSeconds -ge $Script:IntervalCheckSeconds) {
        try {
            $response = Invoke-WebRequest -Uri $Script:plexUrl -UseBasicParsing -TimeoutSec 2
            $Script:plexStreaming = $response.Content -match "<Video "
        } catch {
            Write-Warning "Failed to reach Plex. Assuming not streaming."
            $Script:plexStreaming = $False
        }
        $Script:lastPlexUpdate = Get-Date
    }
}

Write-Debug "Completed plex_slowdown.ps1"