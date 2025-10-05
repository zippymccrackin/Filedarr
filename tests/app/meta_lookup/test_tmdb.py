import json
import sqlite3
import pytest
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock

import app.meta_lookup.tmdb as tmdb_service


@pytest.fixture
def temp_db(monkeypatch, tmp_path):
    """
    Create a temporary SQLite database and patch DB_FILE to point to it.
    Uses tmp_path so pytest cleans up automatically (avoids Windows locking).
    """
    db_path = tmp_path / "tmdb_cache.db"
    monkeypatch.setattr(tmdb_service, "DB_FILE", str(db_path))

    with sqlite3.connect(db_path) as conn:
        conn.execute("""
            CREATE TABLE tmdb_cache (
                tmdbid INTEGER PRIMARY KEY,
                data TEXT,
                timestamp REAL
            )
        """)
        conn.commit()

    return str(db_path)


def test_get_tvdb_token_success(monkeypatch):
    """Ensure a token is extracted when API call succeeds."""
    fake_resp = MagicMock()
    fake_resp.json.return_value = {"data": {"token": "abc123"}}
    fake_resp.raise_for_status.return_value = None
    monkeypatch.setattr(tmdb_service.requests, "post", lambda url, json: fake_resp)

    token = tmdb_service.get_tvdb_token("fakekey")
    assert token == "abc123"


def test_get_tvdb_token_http_error(monkeypatch):
    """Ensure None or exception is raised if API call fails."""
    fake_resp = MagicMock()
    fake_resp.raise_for_status.side_effect = Exception("HTTP 500")
    monkeypatch.setattr(tmdb_service.requests, "post", lambda url, json: fake_resp)

    with pytest.raises(Exception):
        tmdb_service.get_tvdb_token("badkey")


def test_cache_and_get_tmdb_info(temp_db):
    """Insert and fetch a fresh cache entry."""
    data = {"title": "My Movie"}
    tmdb_service.cache_tmdb_info(1, data)

    fetched = tmdb_service.get_cached_tmdb_info(1)
    assert fetched == data


def test_get_cached_tmdb_info_expired(temp_db):
    """Return None when cache entry is older than 24 hours."""
    old_timestamp = (datetime.now() - timedelta(days=2)).timestamp()
    with sqlite3.connect(tmdb_service.DB_FILE) as conn:
        conn.execute(
            "INSERT INTO tmdb_cache (tmdbid, data, timestamp) VALUES (?, ?, ?)",
            (99, json.dumps({"title": "Old Movie"}), old_timestamp),
        )
        conn.commit()

    result = tmdb_service.get_cached_tmdb_info(99)
    assert result is None


def test_lookup_tmdb_info_uses_cache(temp_db, monkeypatch):
    """Should return cached data and skip API call."""
    cached = {"title": "Cached Movie"}
    tmdb_service.cache_tmdb_info(123, cached)

    # if API is called, raise error to prove it wasn't used
    monkeypatch.setattr(tmdb_service.requests, "get",
                        lambda url: (_ for _ in ()).throw(Exception("Should not call API")))

    result = tmdb_service.lookup_tmdb_info(123, "fakekey")
    assert result == cached


def test_lookup_tmdb_info_api_call(temp_db, monkeypatch):
    """Should fetch from API and cache it when not in cache."""
    fake_movie = {
        "title": "API Movie",
        "overview": "A movie from API",
        "release_date": "2024-01-01",
        "id": 456,
        "poster_path": "/poster.jpg",
    }

    fake_resp = MagicMock()
    fake_resp.raise_for_status.return_value = None
    fake_resp.json.return_value = fake_movie
    monkeypatch.setattr(tmdb_service.requests, "get", lambda url: fake_resp)

    result = tmdb_service.lookup_tmdb_info(456, "apikey123")
    assert result["title"] == "API Movie"
    assert result["tmdb_id"] == 456
    assert "url" in result

    # ensure it was cached
    with sqlite3.connect(tmdb_service.DB_FILE) as conn:
        row = conn.execute("SELECT data FROM tmdb_cache WHERE tmdbid=?", (456,)).fetchone()
        assert row is not None
        assert json.loads(row[0])["title"] == "API Movie"


def test_lookup_tmdb_info_api_error(temp_db, monkeypatch):
    """Return None if API call raises an exception."""
    monkeypatch.setattr(
        tmdb_service.requests, "get",
        lambda url: (_ for _ in ()).throw(Exception("network fail"))
    )

    result = tmdb_service.lookup_tmdb_info(999, "badkey")
    assert result is None
