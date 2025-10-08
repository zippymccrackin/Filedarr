# Set ProgressPreference to silently continue to avoid progress bars in output
$ProgressPreference = 'SilentlyContinue'

# Load environment variables from .env file
Get-Content .env | ForEach-Object {
    if ($_ -match '^(\\w+)=(.*)$') {
        $name = $matches[1]
        $value = $matches[2]
        $env:$name = $value
    }
}

$importerScriptPath = $MyInvocation.MyCommand.Path
$importerScriptDir = Split-Path -Parent $importerScriptPath

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
$defaultChunkSize = $Global:Config.defaultChunkSize
$defaultDelayMs = $Global:Config.defaultDelayMs

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

# Open streams
$sourceStream = [System.IO.File]::OpenRead($sourceFile)
$destStream = [System.IO.File]::Create($destFile)
$totalRead = 0
$startTime = Get-Date
$lastUpdate = $startTime

Write-Debug "Notify-Listeners call on ChunkSizeListeners (Length of $($ChunkSizeListeners.Length))"
$chunkSize = Notify-Listeners $ChunkSizeListeners -Return $defaultChunkSize

$buffer = New-Object byte[] $chunkSize  # Resize buffer to match new chunk size

try {
    while (($read = $sourceStream.Read($buffer, 0, $chunkSize)) -gt 0) {
        $destStream.Write($buffer, 0, $read)
        $totalRead += $read

        Write-Debug "Notify-Listeners call on DelayMsListeners (Length of $($DelayMsListeners.Length))"
        $delayMs = Notify-Listeners $DelayMsListeners -Return $defaultDelayMs
        Start-Sleep -Milliseconds $delayMs

        # Send status update every second
        if ((New-TimeSpan $lastUpdate (Get-Date)).TotalSeconds -ge 1) {
            $now = Get-Date

            $elapsed = ($now - $startTime).TotalSeconds

            $percent = [math]::Round(($totalRead / $totalSize) * 100, 1)

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
        }

        Write-Debug "Notify-Listeners call on ChunkSizeListeners (Length of $($ChunkSizeListeners.Length))"
        $chunkSize = Notify-Listeners $ChunkSizeListeners -Return $defaultChunkSize

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
    $sourceStream.Close()
    $destStream.Close()

    exit 1
}