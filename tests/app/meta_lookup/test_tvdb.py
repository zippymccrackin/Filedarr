import json
import os
import sqlite3
import tempfile
import pytest
from datetime import datetime, timedelta

import app.meta_lookup.tvdb as tvdb_service

# --- FIXTURE: temp DB ---------------------------------------------------------
@pytest.fixture
def temp_db(monkeypatch, tmp_path):
    db_path = tmp_path / "tvdb_cache.db"
    monkeypatch.setattr(tvdb_service, "DB_FILE", str(db_path))

    # Create table schema
    with sqlite3.connect(db_path) as conn:
        c = conn.cursor()
        c.execute("""
            CREATE TABLE IF NOT EXISTS tvdb_cache (
                tvdbid INTEGER PRIMARY KEY,
                data TEXT,
                timestamp REAL
            )
        """)
        conn.commit()
    
    return str(db_path)

# --- Tests --------------------------------------------------------------------

def test_get_tvdb_token_success(monkeypatch):
    """Should return token from mocked POST response."""
    class DummyResponse:
        def raise_for_status(self): pass
        def json(self): return {"data": {"token": "FAKE-TOKEN"}}

    monkeypatch.setattr(tvdb_service.requests, "post", lambda *a, **k: DummyResponse())
    assert tvdb_service.get_tvdb_token("abc") == "FAKE-TOKEN"

def test_get_tvdb_token_http_error(monkeypatch):
    """Should propagate HTTP error from requests.post."""
    class DummyResponse:
        def raise_for_status(self): raise tvdb_service.requests.HTTPError("boom")

    monkeypatch.setattr(tvdb_service.requests, "post", lambda *a, **k: DummyResponse())
    with pytest.raises(tvdb_service.requests.HTTPError):
        tvdb_service.get_tvdb_token("abc")

def test_cache_and_get_tvdb_info(temp_db):
    """cache_tvdb_info should write and get_cached_tvdb_info should read."""
    sample = {"foo": "bar"}
    tvdb_service.cache_tvdb_info(123, sample)
    out = tvdb_service.get_cached_tvdb_info(123)
    assert out == sample

def test_get_cached_tvdb_info_expired(temp_db):
    """Expired cache should return None."""
    old_time = datetime.now() - timedelta(days=2)
    with sqlite3.connect(tvdb_service.DB_FILE) as conn:
        conn.execute(
            "INSERT INTO tvdb_cache (tvdbid, data, timestamp) VALUES (?,?,?)",
            (123, json.dumps({"x": "y"}), old_time.timestamp())
        )
        conn.commit()
    assert tvdb_service.get_cached_tvdb_info(123) is None

def test_lookup_tvdb_info_uses_cache(temp_db, monkeypatch):
    """If cache exists and is fresh, no network calls and cached data is returned."""
    cached = {"name": "Cached Show"}
    tvdb_service.cache_tvdb_info(99, cached)

    called = {"post": False, "get": False}
    monkeypatch.setattr(tvdb_service.requests, "post", lambda *a, **k: called.update(post=True))
    monkeypatch.setattr(tvdb_service.requests, "get", lambda *a, **k: called.update(get=True))

    result = tvdb_service.lookup_tvdb_info(99, "dummykey")
    assert result == cached
    # ensure network never called
    assert called["post"] is False and called["get"] is False

def test_lookup_tvdb_info_api_call(temp_db, monkeypatch):
    """If no cache, should fetch token + series info and cache it."""
    # mock token
    monkeypatch.setattr(tvdb_service, "get_tvdb_token", lambda k: "FAKE-TOKEN")

    # mock GET to TVDB
    class DummyGet:
        def raise_for_status(self): pass
        def json(self):
            return {"data": {
                "name": "My Show",
                "overview": "A show",
                "firstAired": "2024-01-01",
                "id": 456,
                "image": "/poster.jpg",
                "slug": "my-show"
            }}
    monkeypatch.setattr(tvdb_service.requests, "get", lambda *a, **k: DummyGet())

    result = tvdb_service.lookup_tvdb_info(456, "dummykey")
    assert result["name"] == "My Show"
    assert result["url"] == "https://thetvdb.com/series/my-show"

    # Verify it was cached
    with sqlite3.connect(tvdb_service.DB_FILE) as conn:
        c = conn.execute("SELECT data FROM tvdb_cache WHERE tvdbid=?", (456,))
        row = c.fetchone()
        assert row and json.loads(row[0])["name"] == "My Show"

@pytest.mark.asyncio
async def test_lookup_tvdb_info_exception(temp_db, monkeypatch):
    # Patch get_tvdb_token to raise an exception
    def raise_exception(api_key):
        raise RuntimeError("forced error")
    
    monkeypatch.setattr(tvdb_service, "get_tvdb_token", raise_exception)

    # Should return None and not raise
    result = tvdb_service.lookup_tvdb_info(tvdbid=123, api_key="fakekey")
    assert result is None