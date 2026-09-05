# Set ProgressPreference to silently continue to avoid progress bars in output
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

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
$filepath = Notify-Listeners $SetDestinationPathListeners -Return (Split-Path -LiteralPath $destFile)
if ([string]::IsNullOrWhiteSpace($filepath) -or [string]::IsNullOrWhiteSpace($filename)) {
    throw "A destination hook returned an empty path or filename. Check staging and destination hooks."
}

$destFile = Join-Path $filepath $filename

Write-Host "Destination File: $destFile"

# Create destination directory if needed
$destDir = Split-Path -LiteralPath $destFile
if (!(Test-Path -LiteralPath $destDir)) {
    New-Item -ItemType Directory $destDir | Out-Null
}

# The compiled worker owns file I/O; this thread remains available for heartbeats.
. "$importerScriptDir\ps\core\diagnostics.ps1"
. "$importerScriptDir\ps\core\load_copy_worker.ps1"
$maxConcurrent = $Global:Config.config.maxConcurrentTransfers
if (-not $maxConcurrent) { $maxConcurrent = 1 }
$stallSeconds = $Global:Config.config.stallWarningSeconds
if (-not $stallSeconds) { $stallSeconds = 5 }
$worker = [Filedarr.CopyWorker]::new()
$startTime = Get-Date
$status = $null

try {
    $chunkSize = Notify-Listeners $ChunkSizeListeners -Return $defaultChunkSize
    $delayMs = Notify-Listeners $DelayMsListeners -Return $defaultDelayMs
    $worker.Start($sourceFile, $destFile, $totalSize, $chunkSize, $delayMs, [int]$maxConcurrent)
    do {
        $snapshot = $worker.Snapshot()
        $totalRead = $snapshot.Bytes
        $now = Get-Date
        $status = @{
            id = $uuid; timestamp = $now; time = $now.ToString("yyyy-MM-dd HH:mm:ss")
            elapsed_sec = $snapshot.ActiveSeconds
            percent_complete = "$([math]::Min(99.9, [math]::Round(($totalRead / $totalSize) * 100, 1)))%"
            transferred = $totalRead; transferred_mb = [math]::Round($totalRead / 1MB, 2)
            total = $totalSize; total_mb = [math]::Round($totalSize / 1MB, 2)
            source = $sourceFile; destination = $destFile
            chunk_size = $snapshot.ChunkSize; delay_ms = $snapshot.DelayMs; meta = $meta
            diagnostics = Get-CopyDiagnostics $snapshot $stallSeconds
        }
        $status = Notify-Listeners $SetStatusInformationListeners -Return $status
        Notify-Listeners $ChunkTransferredListeners $status
        if ($snapshot.Done) { break }
        Start-Sleep -Milliseconds 1000
        $chunkSize = Notify-Listeners $ChunkSizeListeners -Return $defaultChunkSize
        $delayMs = Notify-Listeners $DelayMsListeners -Return $defaultDelayMs
        $worker.SetControls($chunkSize, $delayMs)
    } while ($true)
    if ($snapshot.Error) { throw $snapshot.Error }

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
        eta = $null
        source = $sourceFile
        destination = $destFile
        status = "wrapup"
        meta = $meta
        diagnostics = $status.diagnostics
    }

    Write-Debug "Notify-Listeners call on TransferWrapupListeners (Length of $($TransferWrapupListeners.Length))"
    Notify-Listeners $TransferWrapupListeners $status
    $destFile = $status['destination']

    # Keep the source until all finalization hooks have succeeded.
    if ($meta['downloadClientType'] -ieq "SabNZBD") {
        Remove-Item -LiteralPath $sourceFile -ErrorAction Stop
    }

    $status.diagnostics.phase = "complete"
    $status.diagnostics.summary = "Copy, flush and import finalization completed"

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
        diagnostics = $status.diagnostics
    }
    Write-Debug "Notify-Listeners call on TransferCompleteListeners (Length of $($TransferCompleteListeners.Length))"
    Notify-Listeners $TransferCompleteListeners $status

    exit 0

} catch {
    $copyError = $_.Exception.Message
    if ($status) {
        $status['status'] = 'failed'
        $status['message'] = $copyError
        $status.diagnostics.phase = 'failed'
        $status.diagnostics.summary = "Transfer failed: $copyError"
        $status.diagnostics.advice = 'Inspect source and destination before retrying.'
        if (Module-Enabled 'notify_server') { SendStatusToServer $status -WaitForJob $true }
    }
    Report-Error "Error during copy: $_"
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Script:  $($_.InvocationInfo.ScriptName)"
    Write-Host "Line:    $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host "Code:    $($_.InvocationInfo.Line.Trim())"
    Write-Host "Position: $($_.InvocationInfo.PositionMessage)"
    exit 1
} finally {
    $worker.Cancel()
}
