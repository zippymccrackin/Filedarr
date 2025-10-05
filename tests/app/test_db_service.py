import asyncio
import json
import sqlite3
import time
import pytest
import sys
from pathlib import Path

import app.db_service  as db_service


@pytest.fixture(autouse=True)
def temp_db(monkeypatch, tmp_path):
    """Use a temporary SQLite DB for all tests."""
    db_file = tmp_path / "test.db"
    monkeypatch.setattr(db_service, "DB_FILE", str(db_file))
    yield
    # No teardown needed: tmp_path is cleaned automatically

def get_all_rows(table):
    with sqlite3.connect(db_service.DB_FILE) as conn:
        return list(conn.execute(f"SELECT * FROM {table}"))

def test_init_db_creates_tables():
    db_service.init_db()
    with sqlite3.connect(db_service.DB_FILE) as conn:
        cur = conn.cursor()
        cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = {row[0] for row in cur.fetchall()}
    assert {"transfers", "tvdb_cache", "tmdb_cache"}.issubset(tables)


def test_save_and_load_transfers_round_trip():
    db_service.init_db()
    sample = {"id": "123", "timestamp": time.time(), "foo": "bar"}
    db_service.save_transfer("123", db_service.INCOMPLETE_STATUS, sample)

    rows = get_all_rows("transfers")
    assert len(rows) == 1
    db_id, status, data_json = rows[0]
    assert db_id == "123"
    assert status == db_service.INCOMPLETE_STATUS
    assert json.loads(data_json)["foo"] == "bar"

    loaded = db_service.load_all_transfers()
    assert loaded == [dict(sample, status=db_service.INCOMPLETE_STATUS)]


@pytest.mark.asyncio
async def test_remove_stale_transfers_marks_and_notifies(monkeypatch):
    db_service.init_db()
    # Insert one fresh and one stale transfer
    fresh = {"id": "f1", "timestamp": time.time()}
    stale = {"id": "s1", "timestamp": time.time() - 100}
    db_service.save_transfer("f1", db_service.INCOMPLETE_STATUS, fresh)
    db_service.save_transfer("s1", db_service.INCOMPLETE_STATUS, stale)

    # Mock clients to capture notifications
    class DummyClient:
        def __init__(self):
            self.messages = []
        def put_nowait(self, msg):
            self.messages.append(msg)

    c1, c2 = DummyClient(), DummyClient()
    monkeypatch.setattr(db_service, "clients", [c1, c2])

    # Patch asyncio.sleep to exit loop after first iteration
    called = asyncio.Event()
    async def fake_sleep(_):
        called.set()
        raise asyncio.CancelledError
    monkeypatch.setattr(asyncio, "sleep", fake_sleep)

    # Run remove_stale_transfers once
    task = asyncio.create_task(db_service.remove_stale_transfers())
    await called.wait()
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task

    # Only the stale transfer should be updated
    rows = get_all_rows("transfers")
    statuses = {row[0]: row[1] for row in rows}
    assert statuses["s1"] == db_service.STALE_STATUS
    assert statuses["f1"] == db_service.INCOMPLETE_STATUS

    # Clients should receive an update for the stale one
    for client in (c1, c2):
        assert client.messages
        msg = client.messages[0]
        assert msg["action"] == "update"
        assert msg["data"]["status"] == db_service.STALE_STATUS


@pytest.mark.asyncio
async def test_remove_stale_transfers_handles_exceptions(monkeypatch):
    # Force an exception inside loop to hit the except block
    monkeypatch.setattr(db_service, "DB_FILE", "/non/existent/path.db")
    called = asyncio.Event()

    async def fake_sleep(_):
        called.set()
        raise asyncio.CancelledError
    monkeypatch.setattr(asyncio, "sleep", fake_sleep)

    task = asyncio.create_task(db_service.remove_stale_transfers())
    await called.wait()
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task
    # Nothing to assert except that it didn't crash

@pytest.mark.asyncio
async def test_start_background_tasks_adds_task(monkeypatch):
    added = {}

    class DummyApp:
        def add_background_task(self, func):
            added["func"] = func

    # Patch the symbol in the *quart* module,
    # because that's where start_background_tasks imports from
    monkeypatch.setitem(sys.modules, "quart", 
                        type("FakeQuart", (), {"current_app": DummyApp()}))

    # Patch remove_stale_transfers so it doesn't start a real loop
    monkeypatch.setattr(db_service, "remove_stale_transfers", lambda: None)

    await db_service.start_background_tasks()

    assert "func" in added
    assert added["func"] is not None