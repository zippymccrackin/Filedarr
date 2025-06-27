# Plex Setup
$script:plexToken = "Uw2D4x6pX3Ue7CDF6Zan"
$script:plexUrl = "http://localhost:32400/status/sessions?X-Plex-Token=$plexToken"
$script:IntervalCheckSeconds = 5

$script:plexStreaming = $false

$ChunkSizeListeners += {
    param($chunkSize)

    Update-PlexStreamingStatus

    if ($script:plexStreaming) {
        $chunkSize = 1MB
    }

    return $chunkSize
}

$DelayMsListeners += {
    param($delayMs)

    Update-PlexStreamingStatus

    if ($script:plexStreaming) {
        $delayMs = 150
    }

    return $delayMs
}

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