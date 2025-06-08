# CONFIGURATION
$sourceFile = $env:Sonarr_SourcePath
$destFile = $env:Sonarr_DestinationPath
$name = $env:Sonarr_Series_Title
$dbid = $env:Sonarr_Series_TvdbId
$seasonNumber = $env:Sonarr_EpisodeFile_SeasonNumber
$episodeNumber = $env:Sonarr_EpisodeFile_EpisodeNumbers
$downloadClientType = $env:Sonarr_Download_Client_Type
$downloadClient = $env:Sonarr_Download_Client
$transferMode = $env:Sonarr_TransferMode

$webhookUrl = "http://localhost:3565"

$chunkSize_streaming = 1MB
$chunkSize_notStreaming = 4MB
$delayMs_streaming = 150
$delayMs_notStreaming = 0

$chunkSize = $chunkSize_streaming
$delayMs = $delayMs_streaming

$totalSize = (Get-Item -LiteralPath $sourceFile).Length
if( $totalSize -eq 0 ) {
    Write-Error "$sourceFile file size is 0"
    exit 1
}
$uuid = New-Guid
$filename = [System.IO.Path]::getFileName($destFile)
$drive = [System.IO.Path]::getPathRoot($destFile)
$staging = $drive + "tmp\staging\" + $filename

# Plex
$plexToken = "Uw2D4x6pX3Ue7CDF6Zan"
$plexUrl = "http://localhost:32400/status/sessions?X-Plex-Token=$plexToken"

# Create destination directory if needed
$destDir = Split-Path -LiteralPath $destFile
if (!(Test-Path $destDir)) {
    New-Item -ItemType Directory -LiteralPath $destDir | Out-Null
}

# Open streams
$sourceStream = [System.IO.File]::OpenRead($sourceFile)
$destStream = [System.IO.File]::Create($staging)
$totalRead = 0
$startTime = Get-Date
$lastUpdate = $startTime
$lastPlexUpdate = $startTime

# See if Plex is streaming
$response = Invoke-WebRequest -Uri $plexUrl -UseBasicParsing
$isStreaming = $response.Content -match "<Video "

$speed = 0
$recentStats = @()  # list of @{time=..., bytes=...}

if ($isStreaming) {
	$chunkSize = $chunkSize_streaming
	$delayMs = $delayMs_streaming
} else {
	$chunkSize = $chunkSize_notStreaming
	$delayMs = $delayMs_notStreaming
}
$buffer = New-Object byte[] $chunkSize  # Resize buffer to match new chunk size

try {
    while (($read = $sourceStream.Read($buffer, 0, $chunkSize)) -gt 0) {
        $destStream.Write($buffer, 0, $read)
        $totalRead += $read

        Start-Sleep -Milliseconds $delayMs

        # Send status update every second
        if ((New-TimeSpan $lastUpdate (Get-Date)).TotalSeconds -ge 1) {
            $now = Get-Date
            $recentStats += [PSCustomObject]@{ time = $now; bytes = $totalRead }

            # Remove entries older than 5 seconds
            $recentStats = @( 
                if ($recentStats -is [System.Collections.IEnumerable]) {
                    $recentStats | Where-Object { $_ -and ($now - $_.time).TotalSeconds -le 5 }
                } elseif ($recentStats) {
                    if (($now - $recentStats.time).TotalSeconds -le 5) { $recentStats }
                }
            )

            # Calculate speed based on the first and last entries
            $recentSpeed = 0
            if ($recentStats.Count -ge 2) {
                $oldest = $recentStats[0]
                $newest = $recentStats[-1]

                $deltaBytes = $newest.bytes - $oldest.bytes
                $deltaTime = ($newest.time - $oldest.time).TotalSeconds

                $recentSpeed = if ($deltaTime -gt 0) { $deltaBytes / $deltaTime } else { 0 }
            }
            $recentSpeed = [math]::Round($recentSpeed / 1MB, 2)

            $elapsed = ($now - $startTime).TotalSeconds
            $speed = if ($elapsed -gt 0) { $totalRead / $elapsed } else { 0 }  # bytes/sec
            $remaining = $totalSize - $totalRead
            $etaSeconds = if ($speed -gt 0) { [math]::Round($remaining / $speed) } else { 0 }
            $eta = [TimeSpan]::FromSeconds($etaSeconds).ToString("hh\:mm\:ss")

            $percent = [math]::Round(($totalRead / $totalSize) * 100, 1)

            $status = @{
                id = $uuid
                type = "TV"
                time = $now.ToString("yyyy-MM-dd HH:mm:ss")
                message = "File transfer in progress..."
                percent_complete = "$percent%"
                transferred_mb = [math]::Round($totalRead / 1MB, 2)
                total_mb = [math]::Round($totalSize / 1MB, 2)
                eta = $eta
                source = $sourceFile
                destination = $destFile
		        streaming = $isStreaming
                speed_mb_s = $recentSpeed
                chunk_size = $chunkSize
                delay_ms = $delayMs
                name = $name
                dbid = $dbid
                seasonNumber = $seasonNumber
                episodeNumber = $episodeNumber
                downloadClientType = $downloadClientType
                downloadClient = $downloadClient
                transferMode = $transferMode
            }

            try {
                Invoke-RestMethod -Uri $webhookUrl -Method Post -Body ($status | ConvertTo-Json -Depth 3) -ContentType "application/json"
            } catch {
                Write-Host "Failed to send update: $_"
            }

            $lastUpdate = $now
        }

        # Recheck if Plex is streaming every 5 seconds
        if ((New-TimeSpan $lastPlexUpdate (Get-Date)).TotalSeconds -ge 5) {
            # See if Plex is streaming
            $response = Invoke-WebRequest -Uri $plexUrl -UseBasicParsing
            $isStreaming = $response.Content -match "<Video "

            if ($isStreaming) {
                $chunkSize = $chunkSize_streaming
                $delayMs = $delayMs_streaming
            } else {
                $chunkSize = $chunkSize_notStreaming
                $delayMs = $delayMs_notStreaming
            }

            $buffer = New-Object byte[] $chunkSize  # Resize buffer to match new chunk size

            $lastPlexUpdate = Get-Date;
	    }
    }

    # Final flush & close
    $destStream.Flush()
    $sourceStream.Close()
    $destStream.Close()

    # Delete original if not torrenting, for seeding
    if ($downloadClientType -ieq "SabNZBD") {
        Remove-Item -LiteralPath $sourceFile
    }

    $speed_mbps = [math]::Round($speed / 1MB, 2)
    # Staging status
    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body (@{
        id = $uuid
        type = "TV"
        time = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        message = "Moving file from staging"
        percent_complete = "100%"
        transferred_mb = [math]::Round($totalSize / 1MB, 2)
        total_mb = [math]::Round($totalSize / 1MB, 2)
        eta = "00:00:00"
        source = $sourceFile
        destination = $destFile
        speed_mb_s = $speed_mbps
        name = $name
        dbid = $dbid
        seasonNumber = $seasonNumber
        episodeNumber = $episodeNumber
        downloadClientType = $downloadClientType
        downloadClient = $downloadClient
        transferMode = $transferMode
    } | ConvertTo-Json -Depth 3) -ContentType "application/json"

    Move-Item -LiteralPath $staging -Destination $destFile

    # Final status
    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body (@{
        id = $uuid
        type = "TV"
        time = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        message = "File transfer complete"
        percent_complete = "100%"
        transferred_mb = [math]::Round($totalSize / 1MB, 2)
        total_mb = [math]::Round($totalSize / 1MB, 2)
        eta = "00:00:00"
        source = $sourceFile
        destination = $destFile
        speed_mb_s = $speed_mbps
	    status = "complete"
        name = $name
        dbid = $dbid
        seasonNumber = $seasonNumber
        episodeNumber = $episodeNumber
        downloadClientType = $downloadClientType
        downloadClient = $downloadClient
        transferMode = $transferMode
    } | ConvertTo-Json -Depth 3) -ContentType "application/json"

    exit 0

} catch {
    Write-Host "Error during copy: $_"
    $sourceStream.Close()
    $destStream.Close()

    exit 1
}