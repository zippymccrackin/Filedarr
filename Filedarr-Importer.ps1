# Info required for script
$sourceFile = ""
$destFile = ""
$meta = @{}

# pull info if Sonarr
if( $env:Sonarr_SourcePath ) {
    $sourceFile = $env:Sonarr_SourcePath
    $destFile = $env:Sonarr_DestinationPath

    # all the info available from Sonarr env variables
    $meta["instanceName"] = $env:Sonarr_InstanceName
    $meta["name"] = $env:Sonarr_Series_Title
    $meta["titleSlug"] = $env:Sonarr_Series_TitleSlug
    $meta["seriesPath"] = $env:Sonarr_Series_Path
    $meta["tvdbid"] = $env:Sonarr_Series_TvdbId
    $meta["tvMazeId"] = $env:Sonarr_Series_TvMazeId
    $meta["tmdbId"] = $env:Sonarr_Series_TmdbId
    $meta["imdbId"] = $env:Sonarr_Series_ImdbId
    $meta["seriesType"] = $env:Sonarr_Series_Type
    $meta["originalLanguage"] = $env:Sonarr_Series_OriginalLanguage
    $meta["genres"] = $env:Sonarr_Series_Genres
    $meta["tags"] = $env:Sonarr_Series_Tags

    $meta["episodeCount"] = $env:Sonarr_EpisodeFile_EpisodeCount
    $meta["episodeIds"] = $env:Sonarr_EpisodeFile_EpisodeIds
    $meta["seasonNumber"] = $env:Sonarr_EpisodeFile_SeasonNumber
    $meta["episodeNumber"] = $env:Sonarr_EpisodeFile_EpisodeNumbers
    $meta["airDates"] = $env:Sonarr_EpisodeFile_EpisodeAirDates
    $meta["airDatesUtc"] = $env:Sonarr_EpisodeFile_EpisodeAirDatesUtc
    $meta["episodeTitles"] = $env:Sonarr_EpisodeFile_EpisodeTitles
    $meta["episodeOverviews"] = $env:Sonarr_EpisodeFile_EpisodeOverviews
    $meta["quality"] = $env:Sonarr_EpisodeFile_Quality
    $meta["qualityVersion"] = $env:Sonarr_EpisodeFile_QualityVersion
    $meta["releaseGroup"] = $env:Sonarr_EpisodeFile_ReleaseGroup
    $meta["sceneName"] = $env:Sonarr_EpisodeFile_SceneName

    $meta["downloadClient"] = $env:Sonarr_Download_Client
    $meta["downloadClientType"] = $env:Sonarr_Download_Client_Type
    $meta["downloadId"] = $env:Sonarr_Download_Id

    $meta["audioChannels"] = $env:Sonarr_EpisodeFile_MediaInfo_AudioChannels
    $meta["audioCodec"] = $env:Sonarr_EpisodeFile_MediaInfo_AudioCodec
    $meta["audioLanguages"] = $env:Sonarr_EpisodeFile_MediaInfo_AudioLanguages
    $meta["languages"] = $env:Sonarr_EpisodeFile_MediaInfo_Languages
    $meta["height"] = $env:Sonarr_EpisodeFile_MediaInfo_Height
    $meta["width"] = $env:Sonarr_EpisodeFile_MediaInfo_Width
    $meta["subtitles"] = $env:Sonarr_EpisodeFile_MediaInfo_Subtitles
    $meta["videoCodec"] = $env:Sonarr_EpisodeFile_MediaInfo_VideoCodec
    $meta["videoDynamicRangeType"] = $env:Sonarr_EpisodeFile_MediaInfo_VideoDynamicRangeType

    $meta["customFormat"] = $env:Sonarr_EpisodeFile_CustomFormat
    $meta["customFormatScore"] = $env:Sonarr_EpisodeFile_CustomFormatScore

    $meta["seriesId"] = $env:Sonarr_Series_Id
    $meta["applicationUrl"] = $env:Sonarr_ApplicationUrl
    $meta["transferMode"] = $env:Sonarr_TransferMode

    # Optional: deleted file metadata
    $meta["deletedRelativePaths"] = $env:Sonarr_DeletedRelativePaths
    $meta["deletedPaths"] = $env:Sonarr_DeletedPaths
    $meta["deletedDateAdded"] = $env:Sonarr_DeletedDateAdded
    $meta["deletedRecycleBinPaths"] = $env:Sonarr_DeletedRecycleBinPaths
} elseif( $env:Radarr_SourcePath ) {
    $sourceFile = $env:Radarr_SourcePath
    $destFile = $env:Radarr_DestinationPath

    $meta["instanceName"]             = $env:Radarr_InstanceName
    $meta["applicationUrl"]           = $env:Radarr_ApplicationUrl
    $meta["transferMode"]             = $env:Radarr_TransferMode

    $meta["movieId"]                  = $env:Radarr_Movie_Id
    $meta["name"]                     = $env:Radarr_Movie_Title
    $meta["year"]                     = $env:Radarr_Movie_Year
    $meta["tmdbid"]                   = $env:Radarr_Movie_TmdbId
    $meta["imdbid"]                   = $env:Radarr_Movie_ImdbId
    $meta["originalLanguage"]         = $env:Radarr_Movie_OriginalLanguage
    $meta["genres"]                   = $env:Radarr_Movie_Genres
    $meta["tags"]                     = $env:Radarr_Movie_Tags
    $meta["inCinemas"]                = $env:Radarr_Movie_In_Cinemas_Date
    $meta["physicalRelease"]          = $env:Radarr_Movie_Physical_Release_Date
    $meta["overview"]                 = $env:Radarr_Movie_Overview

    $meta["movieFileId"]              = $env:Radarr_MovieFile_Id
    $meta["relativePath"]             = $env:Radarr_MovieFile_RelativePath
    $meta["quality"]                  = $env:Radarr_MovieFile_Quality
    $meta["qualityVersion"]           = $env:Radarr_MovieFile_QualityVersion
    $meta["releaseGroup"]             = $env:Radarr_MovieFile_ReleaseGroup
    $meta["sceneName"]                = $env:Radarr_MovieFile_SceneName

    $meta["downloadClient"]           = $env:Radarr_Download_Client
    $meta["downloadClientType"]       = $env:Radarr_Download_Client_Type
    $meta["downloadId"]               = $env:Radarr_Download_Id

    $meta["audioChannels"]            = $env:Radarr_MovieFile_MediaInfo_AudioChannels
    $meta["audioCodec"]               = $env:Radarr_MovieFile_MediaInfo_AudioCodec
    $meta["audioLanguages"]           = $env:Radarr_MovieFile_MediaInfo_AudioLanguages
    $meta["languages"]                = $env:Radarr_MovieFile_MediaInfo_Languages
    $meta["videoHeight"]              = $env:Radarr_MovieFile_MediaInfo_Height
    $meta["videoWidth"]               = $env:Radarr_MovieFile_MediaInfo_Width
    $meta["subtitles"]                = $env:Radarr_MovieFile_MediaInfo_Subtitles
    $meta["videoCodec"]               = $env:Radarr_MovieFile_MediaInfo_VideoCodec
    $meta["videoDynamicRange"]        = $env:Radarr_MovieFile_MediaInfo_VideoDynamicRangeType

    $meta["customFormats"]            = $env:Radarr_MovieFile_CustomFormat
    $meta["customFormatScore"]        = $env:Radarr_MovieFile_CustomFormatScore

    $meta["moviePath"]                = $env:Radarr_Movie_Path
    $meta["fullMovieFilePath"]        = $env:Radarr_MovieFile_Path

    # Optional: Deleted file paths if applicable
    $meta["deletedRelativePaths"]     = $env:Radarr_DeletedRelativePaths
    $meta["deletedPaths"]             = $env:Radarr_DeletedPaths
    $meta["deletedDateAdded"]         = $env:Radarr_DeletedDateAdded
}

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
                meta = $meta
            }
            $json = $status | ConvertTo-Json -Depth 3
            $utf8 = [System.Text.Encoding]::UTF8.GetBytes($json)

            try {
                Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $utf8 -ContentType "application/json"
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
    $status = @{
        id = $uuid
        time = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        message = "Moving file from staging"
        percent_complete = "100%"
        transferred_mb = [math]::Round($totalSize / 1MB, 2)
        total_mb = [math]::Round($totalSize / 1MB, 2)
        eta = "00:00:00"
        source = $sourceFile
        destination = $destFile
        speed_mb_s = $speed_mbps
        meta = $meta
    }
    $json = $status | ConvertTo-Json -Depth 3
    $utf8 = [System.Text.Encoding]::UTF8.GetBytes($json)
    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $utf8 -ContentType "application/json"

    Move-Item -LiteralPath $staging -Destination $destFile

    # Final status
    $status = @{
        id = $uuid
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
        meta = $meta
    }
    $json = $status | ConvertTo-Json -Depth 3
    $utf8 = [System.Text.Encoding]::UTF8.GetBytes($json)
    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $utf8 -ContentType "application/json"

    exit 0

} catch {
    Write-Host "Error during copy: $_"
    $sourceStream.Close()
    $destStream.Close()

    exit 1
}