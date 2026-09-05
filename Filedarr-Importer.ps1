# Set ProgressPreference to silently continue to avoid progress bars in output
$ProgressPreference = 'SilentlyContinue'

$importerScriptPath = $MyInvocation.MyCommand.Path
$importerScriptDir = Split-Path -Parent $importerScriptPath

# Resolve configuration relative to this script, including when launched by an arr.
$envFile = Join-Path $importerScriptDir '.env'
if (Test-Path -LiteralPath $envFile) {
    Get-Content -LiteralPath $envFile | ForEach-Object {
        if ($_ -match '^\s*(\w+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2].Trim().Trim('"').Trim("'"), 'Process')
        }
    }
}

# Load Utility Functions
. "$importerScriptDir\ps\core\util.ps1"

# Load Listeners
. "$importerScriptDir\ps\core\listeners.ps1"

# Load all hooks
Get-ChildItem "$importerScriptDir\ps\hooks\*.ps1" | ForEach-Object { . $_.FullName }

# Load services
. "$importerScriptDir\ps\core\services.ps1"

# Load all service scripts
Get-ChildItem "$importerScriptDir\ps\services\*.ps1" | ForEach-Object { . $_.FullName }

# Set defaults from config
$defaultChunkSize = Convert-ToBytes $Global:Config.config.defaultChunkSize
$defaultDelayMs = [int]$Global:Config.config.defaultDelayMs

# Fill the data from the services
Write-Debug "Notify-Listeners call on Services (Length of $($Services.Length))"
$data = Notify-Listeners $Services -Return @{
    sourceFile = ""
    destinationFile = ""
    meta = @{}
}

$sourceFile = $data['sourceFile']
$destFile = $data['destinationFile']
$meta = $data['meta']

if (
    [string]::IsNullOrWhiteSpace($sourceFile) -or
    [string]::IsNullOrWhiteSpace($destFile) -or
    -not (Test-Path -LiteralPath $sourceFile)
) {
    Report-Error "Error: source or destination is missing or source file does not exist.\n\tSource: $sourceFile\n\tDestination: $destFile"
    exit 1
}

# Generate a tracking ID
$uuid = New-Guid

# Get some information
$totalSize = (Get-Item -LiteralPath $sourceFile).Length
if( $totalSize -eq 0 ) {
    Report-Error "$sourceFile file size is 0"
    exit 1
}

Write-Debug "Notify-Listeners call on SetDestinationFilenameListeners (Length of $($SetDestinationFilenameListeners.Length))"
$filename = Notify-Listeners $SetDestinationFilenameListeners $destFile -Return $([System.IO.Path]::getFileName($destFile))
Write-Debug "Notify-Listeners call on SetDestinationPathListeners (Length of $($SetDestinationPathListeners.Length))"
$filepath = Notify-Listeners $SetDestinationPathListeners $(Split-Path -LiteralPath $destFile)

$destFile = Join-Path $filepath $filename

Write-Host "Destination File: $destFile"

# Create destination directory if needed
$destDir = Split-Path -LiteralPath $destFile
if (!(Test-Path $destDir)) {
    New-Item -ItemType Directory $destDir | Out-Null
}

# Streams are opened inside the protected block. Never truncate an existing file.
$sourceStream = $null
$destStream = $null
$totalRead = 0
$startTime = Get-Date
$lastUpdate = $startTime
$copyClock = [System.Diagnostics.Stopwatch]::StartNew()
$lastUpdateMs = 0

Write-Debug "Notify-Listeners call on ChunkSizeListeners (Length of $($ChunkSizeListeners.Length))"
$chunkSize = Notify-Listeners $ChunkSizeListeners -Return $defaultChunkSize

if ($chunkSize -le 0 -or $chunkSize -gt 64MB) { throw "Chunk size must be between 1 byte and 64 MB" }
$buffer = New-Object byte[] $chunkSize

try {
    $sourceStream = [System.IO.File]::OpenRead($sourceFile)
    $destStream = [System.IO.File]::Open($destFile, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    $delayMs = Notify-Listeners $DelayMsListeners -Return $defaultDelayMs
    while (($read = $sourceStream.Read($buffer, 0, $chunkSize)) -gt 0) {
        $destStream.Write($buffer, 0, $read)
        $totalRead += $read

        if ($delayMs -gt 0) { Start-Sleep -Milliseconds $delayMs }

        # Evaluate controls once a second, not for every buffer of data.
        if ($copyClock.ElapsedMilliseconds - $lastUpdateMs -ge 1000) {
            $now = Get-Date

            $elapsed = ($now - $startTime).TotalSeconds

            $percent = [math]::Min(99.9, [math]::Round(($totalRead / $totalSize) * 100, 1))

            $status = @{
                id = $uuid
                timestamp = $now
                time = $now.ToString("yyyy-MM-dd HH:mm:ss")
                elapsed_sec = $elapsed
                percent_complete = "$percent%"
                transferred = $totalRead
                transferred_mb = [math]::Round($totalRead / 1MB, 2)
                total = $totalSize
                total_mb = [math]::Round($totalSize / 1MB, 2)
                source = $sourceFile
                destination = $destFile
                chunk_size = $chunkSize
                delay_ms = $delayMs
                meta = $meta
            }

            Write-Debug "Notify-Listeners call on SetStatusInformationListeners (Length of $($SetStatusInformationListeners.Length))"
            $status = Notify-Listeners $SetStatusInformationListeners -Return $status

            # Notify chunk transferred listeners
            Write-Debug "Notify-Listeners call on ChunkTransferredListeners (Length of $($ChunkTransferredListeners.Length))"
            Notify-Listeners $ChunkTransferredListeners $status

            $lastUpdate = $now
            $lastUpdateMs = $copyClock.ElapsedMilliseconds
            $delayMs = Notify-Listeners $DelayMsListeners -Return $defaultDelayMs
            $nextChunkSize = Notify-Listeners $ChunkSizeListeners -Return $defaultChunkSize
            if ($nextChunkSize -le 0 -or $nextChunkSize -gt 64MB) { throw "Invalid chunk size: $nextChunkSize" }
            if ($nextChunkSize -ne $chunkSize) {
                $chunkSize = $nextChunkSize
                $buffer = New-Object byte[] $chunkSize
            }
        }
    }
    if ($totalRead -ne $totalSize) { throw "Source size changed or copy was incomplete" }

    # Final flush & close
    $destStream.Flush()
    $sourceStream.Close()
    $destStream.Close()

    # Wrapup status
    $status = @{
        id = $uuid
        timestamp = Get-Date
        time = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        percent_complete = "100%"
        transferred = $totalRead
        transferred_mb = [math]::Round($totalSize / 1MB, 2)
        total = $totalSize
        total_mb = [math]::Round($totalSize / 1MB, 2)
        eta = "00:00:00"
        source = $sourceFile
        destination = $destFile
        status = "wrapup"
        meta = $meta
    }

    Write-Debug "Notify-Listeners call on TransferWrapupListeners (Length of $($TransferWrapupListeners.Length))"
    Notify-Listeners $TransferWrapupListeners $status
    $destFile = $status['destination']

    # Keep the source until all finalization hooks have succeeded.
    if ($meta['downloadClientType'] -ieq "SabNZBD") {
        Remove-Item -LiteralPath $sourceFile -ErrorAction Stop
    }

    # Final status
    $status = @{
        id = $uuid
        timestamp = Get-Date
        time = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        percent_complete = "100%"
        transferred = $totalRead
        transferred_mb = [math]::Round($totalSize / 1MB, 2)
        total = $totalSize
        total_mb = [math]::Round($totalSize / 1MB, 2)
        eta = "00:00:00"
        source = $sourceFile
        destination = $destFile
	    status = "complete"
        meta = $meta
    }
    Write-Debug "Notify-Listeners call on TransferCompleteListeners (Length of $($TransferCompleteListeners.Length))"
    Notify-Listeners $TransferCompleteListeners $status

    exit 0

} catch {
    Report-Error "Error during copy: $_"
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Script:  $($_.InvocationInfo.ScriptName)"
    Write-Host "Line:    $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host "Code:    $($_.InvocationInfo.Line.Trim())"
    Write-Host "Position: $($_.InvocationInfo.PositionMessage)"
    exit 1
} finally {
    if ($sourceStream) { $sourceStream.Dispose() }
    if ($destStream) { $destStream.Dispose() }
}
