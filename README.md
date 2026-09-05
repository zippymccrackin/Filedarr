# Filedarr

File transfer monitor and importer for Sonarr and Radarr.

## Run the optimized Windows build

1. Extract `dist/optimized/Filedarr-optimized.zip` to a local folder on the other PC.
2. Keep that PC's `.env` and `config.yml` settings. The archive contains a sample config; do not overwrite your configured copy without reviewing it.
3. Stop the old Filedarr server, then double-click `Start-Filedarr.cmd` (it sets the working directory before launching the executable). Open `http://localhost:3565` (or `http://<PC-address>:3565` from another PC).
4. Point Sonarr/Radarr at the updated `Filedarr-Importer.ps1`. Update the entire `ps` folder too; replacing only the executable does not update the copy engine.

The importer needs PowerShell and the `powershell-yaml` module. The executable includes the Python server and dashboard assets. The server reads `.env` and stores `transfers.db` in its working directory. Keep this directory on a local disk. If preserving history, copy the old database after stopping the old server.

The sample hooks send status to `http://localhost:3565`. If the importer and dashboard run on different PCs, set both notification URLs in `config.yml` to the server's address. TMDB/TVDB API keys are optional; missing keys do not prevent transfers or dashboard updates.

## Performance and reliability changes

- Metadata and SQLite operations run outside the web event loop. External metadata calls have timeouts; repeated progress updates reuse metadata and back off failed lookups.
- Progress reporting reuses one HTTP client, allows one outstanding request, skips redundant intermediate updates, and retries the final update up to three times. Each request has a five-second timeout.
- The copy loop reuses its buffer, refreshes throttle settings once per second, and sleeps only when throttling is enabled. Configured chunk sizes are converted to bytes correctly.
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
$testConfig = New-PesterConfiguration
$testConfig.TestRegistry.Enabled = $false
$testConfig.Run.Path = 'tests/ps'
Invoke-Pester -Configuration $testConfig
```

Tests require pytest, pytest-asyncio and Pester 5. Windows integration tests exercise real PowerShell copying, finalization failure, destination protection, and HTTP retries against a local test server. They use a process-only execution-policy override for the temporary test scripts.
