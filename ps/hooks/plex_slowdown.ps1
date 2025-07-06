Write-Debug "plex_slowdown.ps1"

# Plex Setup
$script:plexToken = "Uw2D4x6pX3Ue7CDF6Zan"
$script:plexUrl = "http://localhost:32400/status/sessions?X-Plex-Token=$plexToken"
$script:IntervalCheckSeconds = 5

$script:plexStreaming = $false

Write-Debug "    Adding to ChunkSizeListeners (Length $($ChunkSizeListeners.Length))"
$ChunkSizeListeners += {
    param($chunkSize)

    Update-PlexStreamingStatus

    if ($script:plexStreaming) {
        $chunkSize = 1MB
    }

    return $chunkSize
}
Write-Debug "    Done adding to ChunkSizeListeners (Length $($ChunkSizeListeners.Length))"

Write-Debug "    Adding to DelayMsListeners (Length $($DelayMsListeners.Length))"
$DelayMsListeners += {
    param($delayMs)

    Update-PlexStreamingStatus

    if ($script:plexStreaming) {
        $delayMs = 150
    }

    return $delayMs
}
Write-Debug "    Done adding to DelayMsListeners (Length $($DelayMsListeners.Length))"

function Update-PlexStreamingStatus {
    if (-not $script:lastPlexUpdate) {
        $script:lastPlexUpdate = Get-Date
    }

    if ((New-TimeSpan $script:lastPlexUpdate (Get-Date)).TotalSeconds -ge $script:IntervalCheckSeconds) {
        try {
            $response = Invoke-WebRequest -Uri $script:plexUrl -UseBasicParsing -TimeoutSec 2
            $script:plexStreaming = $response.Content -match "<Video "
        } catch {
            Write-Warning "Failed to reach Plex. Assuming not streaming."
            $script:plexStreaming = $false
        }

        $script:lastPlexUpdate = Get-Date
    }
}

Write-Debug "Completed plex_slowdown.ps1"