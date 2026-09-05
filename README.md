# Filedarr

File transfer monitor and importer for Sonarr and Radarr.

## Run the optimized Windows build

1. Extract `dist/optimized/Filedarr-optimized.zip` to a local folder on the other PC.
2. Keep that PC's `.env` and `config.yml` settings. The archive contains a sample config; do not overwrite your configured copy without reviewing it.
3. Stop the old Filedarr server, then double-click `Start-Filedarr.cmd` (it sets the working directory before launching the executable). Open `http://localhost:3565` (or `http://<PC-address>:3565` from another PC).
4. Point Sonarr/Radarr at the updated `Filedarr-Importer.ps1`. Update the entire `ps` folder too; replacing only the executable does not update the copy engine.

The importer needs PowerShell and the `powershell-yaml` module. The executable includes the Python server and dashboard assets. The archive also includes Python sources if you prefer `python run.py`. The server reads `.env` and stores `transfers.db` in its working directory. Keep this directory on a local disk. If preserving history, copy the old database after stopping the old server.

The sample hooks send status to `http://localhost:3565`. If the importer and dashboard run on different PCs, set both notification URLs in `config.yml` to the server's address. TMDB/TVDB API keys are optional; missing keys do not prevent transfers or dashboard updates.

## Live transfer troubleshooting

The importer now runs a compiled .NET copy worker with two reusable buffers. Source reads and destination writes overlap, while PowerShell reports snapshots independently of pending I/O. Flush completion and byte counts are verified before finalization. Keep `ps/core/CopyWorker.cs` with the importer; it is compiled locally by `Add-Type` when an import starts.

Expand **Transfer diagnostics** on a transfer to see:

- Whether it is queued, opening a file, copying, deliberately throttled, flushing, or failed.
- Current source-read and destination-write wait durations, time since the last completed write, cumulative operation times, and longest operations.
- The configured throttle ceiling, plus recent speed and the overall copy average.
- Active adapters' negotiated link speeds, send/receive rates, and new packet errors/discards. Counters refresh every five seconds and cover all traffic on this PC.

A wait of five seconds triggers a specific source/destination stall message. This is a diagnostic threshold, not an I/O cancellation timeout. If importer heartbeats stop for ten seconds, the dashboard shows that speed is unknown rather than displaying a frozen rate. Unknown ETA is no longer shown as `00:00:00`. Slow samples retain a preceding baseline, fixing the false zero-speed result when one chunk takes longer than the averaging window.

For a direct Ethernet share, first check the negotiated speed of the adapter carrying that connection, then whether the measured wait is on source reads or destination writes. The panel flags low Ethernet link speeds and new packet errors. It does not infer which adapter carries a share, nor claim that a file API wait proves a bad disk or cable. Network file I/O includes remote disk, SMB, and link latency; inspecting the other machine may still be necessary.

The following entries belong in the existing `config:` list (retain your other settings):

```yaml
config:
  - defaultChunkSize: 4.1MB
  - defaultDelayMs: 0
  - maxConcurrentTransfers: 1
  - stallWarningSeconds: 5
```

One copy per destination drive/share root is the default to reduce contention. Set `maxConcurrentTransfers` to `2` to permit two. Imports beyond the limit show as queued. Coordination uses Windows named mutexes in the same session, with consistent settings and access to those objects; different sessions, mapped aliases and UNC aliases are not unified. This limit coordinates Filedarr copies, not other programs using the disk or share.

Restart the Python server (`python run.py`) or replace the executable, and replace the **entire** importer `ps` folder. Existing running imports keep their old worker; new imports use these changes. Preserve your `.env` and configuration. No hardware throughput is guaranteed by these software changes.

## Performance and reliability changes

- Metadata and SQLite operations run outside the web event loop. External metadata calls have timeouts; repeated progress updates reuse metadata and back off failed lookups.
- Progress reporting reuses one HTTP client, allows one outstanding request, skips redundant intermediate updates, and retries the final update up to three times. Each request has a five-second timeout.
- The copy worker reuses two buffers, overlaps reads and writes, refreshes throttle settings from the reporting loop, and delays only when throttling is enabled. Configured chunk sizes are converted to bytes correctly.
- Each hook has separate configuration variables. Plex throttling still applies when enabled; the sample streaming setting deliberately limits speed to roughly 1 MB per 150 ms before disk/network overhead.
- The dashboard uses local assets and renders only five completed transfers at a time. Page buttons work on desktop and mobile; the former swipe carousel is replaced by pagination.
- Slow event consumers have bounded queues and reconnect to refresh their state. Long-lived event streams are exempt from the normal response timeout.
- Existing destination files are never truncated. Copy size is checked, streams are disposed on failure, and SABnzbd sources are deleted only after finalization succeeds. Torrent sources remain available for seeding.

An interrupted copy retains its source and may leave a partial destination. Automatic resume is not implemented: inspect and move/remove that partial file before retrying. Final notification failure produces a warning and does not undo a successful copy. Hardware, antivirus scanning, Wi-Fi/SMB performance, and Plex throttling can still limit actual throughput; local tests do not establish speeds on another PC.

## Run or build from source

```powershell
python -m pip install -r requirements.txt
python run.py
```

```powershell
python -m PyInstaller --noconfirm --distpath dist/optimized --workpath build/optimized FiledarrImporter.spec
```

The server uses one process with development reload/debug disabled. Keep a single server process because live event subscribers are held in process memory.

## Verification

```powershell
python -m pytest tests -q -p no:cacheprovider
node tests/ui/diagnostics.test.cjs
$testConfig = New-PesterConfiguration
$testConfig.TestRegistry.Enabled = $false
$testConfig.Run.Path = 'tests/ps'
Invoke-Pester -Configuration $testConfig
```

Tests require pytest, pytest-asyncio, Node.js and Pester 5. Worker tests deliberately block reads and writes, verify overlap and recovery, and exercise destination queuing. UI logic tests cover heartbeat loss, recovery and network warnings. Windows integration tests exercise real PowerShell copying, finalization failure, destination protection, and HTTP retries against a local test server. They use a process-only execution-policy override for the temporary test scripts.
