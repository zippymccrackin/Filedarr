# Load Listeners
. "$PSScriptRoot\ps\core\listeners.ps1"

# Load all hooks
Get-ChildItem "$PSScriptRoot\ps\hooks\*.ps1" | ForEach-Object { . $_.FullName }

# Load services
. "$PSScriptRoot\ps\core\services.ps1"

# Load all service scripts
Get-ChildItem "$PSScriptRoot\ps\services\*.ps1" | ForEach-Object { . $_.FullName }

$data = @{
    sourceFile = ""
    destinationFile = ""
    meta = @{}
}

# Fill the data from the services
foreach ($listener in $Services) {
    $data = & $listener $data
}

$sourceFile = $data['sourceFile']
$destFile = $data['destinationFile']
$meta = $data['meta']

if (
    [string]::IsNullOrWhiteSpace($sourceFile) -or
    [string]::IsNullOrWhiteSpace($destFile) -or
    -not (Test-Path -LiteralPath $sourceFile)
) {
    Write-Host "Error: source or destination is missing or source file does not exist.\n\tSource: $sourceFile\n\tDestination: $destFile"
    exit 1
}

# Generate a tracking ID
$uuid = New-Guid

# Get some information
$totalSize = (Get-Item -LiteralPath $sourceFile).Length
if( $totalSize -eq 0 ) {
    Write-Error "$sourceFile file size is 0"
    exit 1
}
# TODO Modularize this so that the destination file name can be customized
$filename = [System.IO.Path]::getFileName($destFile)
$drive = [System.IO.Path]::getPathRoot($destFile)
# TODO Modularize this so that staging can be 1) optional 2) customized
$staging = $drive + "tmp\staging\" + $filename

# Create staging directory if needed
if (!(Test-Path $drive+"tmp\staging\")) {
    New-Item -ItemType Directory -LiteralPath $drive="tmp\staging\" | Out-Null
}
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

# TODO Modularize the speed calculator
$speed = 0
$recentStats = @()  # list of @{time=..., bytes=...}

$defaultChunkSize = 4MB
$defaultDelayMs = 0

$chunkSize = $defaultChunkSize
foreach ($listener in $ChunkSizeListeners) {
    $chunkSize = & $listener $chunkSize
}

$buffer = New-Object byte[] $chunkSize  # Resize buffer to match new chunk size

try {
    while (($read = $sourceStream.Read($buffer, 0, $chunkSize)) -gt 0) {
        $destStream.Write($buffer, 0, $read)
        $totalRead += $read

        $delayMs = $defaultDelayMs
        foreach ($listener in $DelayMsListeners) {
            $delayMs = & $listener $delayMs
        }
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
            $remaining = $totalSize - $totalRead
            $etaSeconds = if ($recentSpeed -gt 0) { [math]::Round($remaining / $recentSpeed) } else { 0 }
            $eta = [TimeSpan]::FromSeconds($etaSeconds).ToString("hh\:mm\:ss")

            $percent = [math]::Round(($totalRead / $totalSize) * 100, 1)

            $status = @{
                id = $uuid
                time = $now.ToString("yyyy-MM-dd HH:mm:ss")
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

            # Notify chunk transferred listeners
            foreach ($listener in $ChunkTransferredListeners) {
                & $listener $status
            }

            $lastUpdate = $now
        }

        $chunkSize = $defaultChunkSize
        foreach ($listener in $ChunkSizeListeners) {
            $chunkSize = & $listener $chunkSize
        }

        $buffer = New-Object byte[] $chunkSize  # Resize buffer to match new chunk size
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
        percent_complete = "100%"
        transferred_mb = [math]::Round($totalSize / 1MB, 2)
        total_mb = [math]::Round($totalSize / 1MB, 2)
        eta = "00:00:00"
        source = $sourceFile
        destination = $destFile
        speed_mb_s = $speed_mbps
        meta = $meta
    }
    foreach ($listener in $StagingStartingListeners) {
        & $listener $status
    }

    Move-Item -LiteralPath $staging -Destination $destFile

    # Final status
    $status = @{
        id = $uuid
        time = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
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
    foreach ($listener in $TransferCompleteListeners) {
        & $listener $status
    }

    exit 0

} catch {
    Write-Host "Error during copy: $_"
    $sourceStream.Close()
    $destStream.Close()

    exit 1
}