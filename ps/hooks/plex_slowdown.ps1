Write-Debug "plex_slowdown.ps1"

$utilPath = Join-Path $PSScriptRoot '..\core\util.ps1' | Resolve-Path
. $utilPath

if ( -not ( Module-Enabled 'plex_slowdown' ) ) {
    Write-Debug "plex_slowdown module is disabled, skipping inclusion"
    return
}

$Script:variables = Get-Module-Variables 'plex_slowdown'
$Script:variables.chunkSize = Convert-ToBytes $Script:variables.chunkSize

# Plex Setup
$Script:plexToken = $Script:variables.plex_token
$Script:plexUrl = $Script:variables.plex_url
$Script:plexUrl = "$Script:plexUrl/status/sessions?X-Plex-Token=$plexToken"
$Script:IntervalCheckSeconds = $Script:variables.intervalCheckSeconds

$Script:plexStreaming = $False

Write-Debug "    Adding to ChunkSizeListeners (Length $($ChunkSizeListeners.Length))"
$Global:ChunkSizeListeners += {
    param($chunkSize)

    Update-PlexStreamingStatus

    if ($Script:plexStreaming) {
        $chunkSize = $Script:variables.chunkSize
    }

    return $chunkSize
}
Write-Debug "    Done adding to ChunkSizeListeners (Length $($ChunkSizeListeners.Length))"

Write-Debug "    Adding to DelayMsListeners (Length $($DelayMsListeners.Length))"
$Global:DelayMsListeners += {
    param($delayMs)

    Update-PlexStreamingStatus

    if ($Script:plexStreaming) {
        $delayMs = $Script:variables.delayMs
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