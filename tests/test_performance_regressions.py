import asyncio
import json
import os
from pathlib import Path
import shutil
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest
from quart import Quart
from app import db_service
from app.routes.transfer import transfer_bp
from app.routes.dashboard import dashboard_bp
from app.state import broadcast


@pytest.mark.asyncio
async def test_slow_metadata_does_not_block_dashboard(tmp_path, monkeypatch):
    monkeypatch.setattr(db_service, 'DB_FILE', str(tmp_path / 'transfers.db'))
    db_service.init_db()
    entered, release = threading.Event(), threading.Event()
    def lookup(*args):
        entered.set()
        assert release.wait(5)
        return {'title': 'Test'}
    monkeypatch.setenv('TMDB_API_KEY', 'test')
    monkeypatch.setattr('app.meta_lookup.tmdb.lookup_tmdb_info', lookup)
    app = Quart(__name__, template_folder=str(Path(__file__).resolve().parents[1] / 'templates'))
    app.register_blueprint(transfer_bp)
    app.register_blueprint(dashboard_bp)
    client = app.test_client()
    pending = asyncio.create_task(client.post('/transfer/slow', json={
        'percent_complete': '10%', 'sequence': 1, 'meta': {'tmdbid': 1}}))
    try:
        assert await asyncio.to_thread(entered.wait, 2)
        response = await asyncio.wait_for(client.get('/'), .5)
        assert response.status_code == 200
    finally:
        release.set()
        assert (await pending).status_code == 200
    # Later updates reuse metadata and old sequences cannot regress the transfer.
    monkeypatch.setattr('app.meta_lookup.tmdb.lookup_tmdb_info', lambda *args: pytest.fail('lookup repeated'))
    await client.post('/transfer/slow', json={'percent_complete': '100%', 'sequence': 3, 'meta': {'tmdbid': 1}})
    response = await client.post('/transfer/slow', json={'percent_complete': '20%', 'sequence': 2})
    assert (await response.get_json())['status'] == 'ignore'
    assert db_service.load_transfer('slow')['status'] == 'complete'


def test_slow_event_consumer_is_bounded():
    slow, healthy = asyncio.Queue(maxsize=2), asyncio.Queue()
    for number in range(3):
        broadcast({'number': number}, [slow, healthy])
    assert slow.qsize() == 1
    assert slow.get_nowait() is None
    assert healthy.qsize() == 3


@pytest.fixture
def importer(tmp_path):
    root = Path(__file__).resolve().parents[1]
    shutil.copy(root / 'Filedarr-Importer.ps1', tmp_path)
    shutil.copytree(root / 'ps', tmp_path / 'ps')
    (tmp_path / 'config.yml').write_text('config:\n  - defaultChunkSize: 4.1MB\n  - defaultDelayMs: 0\nmodules: []\n')
    return tmp_path


def run_importer(importer, source, destination):
    env = {k: v for k, v in os.environ.items() if not k.lower().startswith(('sonarr_', 'radarr_'))}
    env.update(Radarr_SourcePath=str(source), Radarr_DestinationPath=str(destination), Radarr_Download_Client_Type='SabNZBD')
    # Simulate a service account that cannot see user-installed YAML modules.
    env['PSModulePath'] = str(Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/Modules')
    return subprocess.run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(importer / 'Filedarr-Importer.ps1')],
                          env=env, capture_output=True, text=True, timeout=30)


def test_copy_exact_bytes_and_protect_existing_destination(importer):
    source, dest = importer / 'source.bin', importer / 'dest.bin'
    content = bytes(range(256)) * 40000
    source.write_bytes(content)
    result = run_importer(importer, source, dest)
    assert result.returncode == 0, result.stdout + result.stderr
    assert dest.read_bytes() == content
    assert not source.exists()
    source.write_bytes(b'retry source')
    result = run_importer(importer, source, dest)
    assert result.returncode != 0
    assert source.read_bytes() == b'retry source'
    assert dest.read_bytes() == content


def test_finalization_failure_keeps_source(importer):
    (importer / 'ps/hooks/zz_failure.ps1').write_text('$Global:TransferWrapupListeners += { throw "Simulated finalization failure" }')
    source, dest = importer / 'source.bin', importer / 'dest.bin'
    source.write_bytes(b'keep this')
    result = run_importer(importer, source, dest)
    assert result.returncode != 0
    assert 'Simulated finalization failure' in result.stdout + result.stderr
    assert source.read_bytes() == b'keep this'


def test_progress_http_is_bounded_and_final_status_retries(importer):
    received = []
    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            payload = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
            received.append(payload)
            self.send_response(503 if payload['sequence'] == 20 and sum(p['sequence'] == 20 for p in received) < 3 else 200)
            self.send_header('Content-Length', '0')
            self.end_headers()
        def log_message(self, *args):
            pass
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    script = importer / 'notify-test.ps1'
    script.write_text('''. "$PSScriptRoot/ps/core/util.ps1"
. "$PSScriptRoot/ps/core/listeners.ps1"
$Global:Config = @{ modules = @(@{ module_name = 'notify_server'; variables = @(@{ url = 'http://127.0.0.1:PORT' }) }) }
. "$PSScriptRoot/ps/hooks/notify_server.ps1"
for ($i=0; $i -lt 20; $i++) { SendStatusToServer @{id='test'; message='progress'} }
SendStatusToServer @{id='test'; message='complete'} -WaitForJob $true
if (@(Get-Job).Count -ne 0) { throw 'Progress spawned jobs' }
'''.replace('PORT', str(server.server_port)))
    try:
        result = subprocess.run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(script)], capture_output=True, text=True, timeout=30)
        assert result.returncode == 0, result.stdout + result.stderr
        assert received[-1]['message'] == 'complete'
        assert sum(p['sequence'] == 20 for p in received) == 3
        assert len(received) <= 23
    finally:
        server.shutdown()
        server.server_close()


@pytest.mark.asyncio
async def test_assets_work_from_another_working_directory(tmp_path, monkeypatch):
    import importlib
    import app.assets as assets
    monkeypatch.chdir(tmp_path)
    importlib.reload(assets)
    app = Quart(__name__)
    app.register_blueprint(assets.assets_bp)
    client = app.test_client()
    for path in ('/style.css', '/favicon-32x32.png', '/site.webmanifest'):
        assert (await client.get(path)).status_code == 200

@pytest.mark.asyncio
async def test_failure_status_and_diagnostics_survive_server_roundtrip(tmp_path, monkeypatch):
    monkeypatch.setattr(db_service, 'DB_FILE', str(tmp_path / 'failures.db'))
    db_service.init_db()
    app = Quart(__name__)
    app.register_blueprint(transfer_bp)
    client = app.test_client()
    diagnostics = {'phase': 'failed', 'summary': 'Destination write failed', 'write_pending_sec': 8.2}
    response = await client.post('/transfer/broken', json={
        'percent_complete': '50%', 'sequence': 1, 'status': 'failed', 'diagnostics': diagnostics})
    assert response.status_code == 200
    saved = db_service.load_transfer('broken')
    assert saved['status'] == 'failed'
    assert saved['diagnostics'] == diagnostics
    assert (await (await client.delete('/transfer/all')).get_json())['removed'] is True
    assert db_service.load_transfer('broken') is None


def test_importer_sends_live_diagnostics_and_network_counters(importer):
    received = []
    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            received.append(json.loads(self.rfile.read(int(self.headers['Content-Length']))))
            self.send_response(200)
            self.send_header('Content-Length', '0')
            self.end_headers()
        def log_message(self, *args):
            pass
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    (importer / 'config.yml').write_text(f'''config:
  - defaultChunkSize: 1MB
  - defaultDelayMs: 500
modules:
  - module_name: notify_server
    variables:
      - url: http://127.0.0.1:{server.server_port}
  - module_name: speed_report
    variables:
      - intervalCheckSeconds: 5
''')
    source, dest = importer / 'source.bin', importer / 'dest.bin'
    source.write_bytes(bytes(range(256)) * 16384)
    try:
        result = run_importer(importer, source, dest)
        assert result.returncode == 0, result.stdout + result.stderr
        assert len(received) >= 3
        assert received[-1]['status'] == 'complete'
        copying = [p for p in received if p.get('diagnostics', {}).get('phase') in ('copying', 'throttling')]
        assert copying
        assert any(p.get('speed_mb_s', 0) > 0 for p in copying if p.get('speed_mb_s') is not None)
        assert any(p['diagnostics']['throttle_limit_mb_s'] == 2 for p in copying)
        for p in received:
            assert isinstance(p['diagnostics']['network'], list)
            assert all(isinstance(a, dict) for a in p['diagnostics']['network'])
        assert dest.stat().st_size == 4 * 1024 * 1024
    finally:
        server.shutdown()
        server.server_close()


@pytest.mark.parametrize("shell", ["powershell", "pwsh"])
def test_bundled_yaml_loads_without_user_module_paths(importer, shell):
    executable = shutil.which(shell)
    if not executable:
        pytest.skip(f"{shell} is not installed")
    env = os.environ.copy()
    env['PSModulePath'] = str(Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/Modules')
    script = importer / 'yaml-check.ps1'
    script.write_text('''$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/ps/core/util.ps1"
$module = Get-Module powershell-yaml
if (-not $module.ModuleBase.StartsWith($PSScriptRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Loaded a module outside the importer' }
if ((Convert-ToBytes $Global:Config.config.defaultChunkSize) -ne [long](4.1MB)) { throw 'Configuration parsing failed' }
# Repeated includes must remain safe for the hooks.
. "$PSScriptRoot/ps/core/util.ps1"
Write-Output 'Bundled YAML OK'
''')
    result = subprocess.run([executable, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(script)],
                            env=env, capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stdout + result.stderr
    assert 'Bundled YAML OK' in result.stdout
