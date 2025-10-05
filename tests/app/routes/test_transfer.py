import pytest
from unittest.mock import patch, MagicMock
from quart import Quart
from app.routes import transfer

@pytest.mark.asyncio
async def test_delete_transfer_success(monkeypatch):
    # Mock DB and clients
    monkeypatch.setattr(transfer, "clients", [MagicMock()])
    with patch("sqlite3.connect") as mock_connect:
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_cursor.rowcount = 1
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value.__enter__.return_value = mock_conn

        app = Quart(__name__)
        app.register_blueprint(transfer.transfer_bp)
        test_client = app.test_client()

        response = await test_client.delete("/transfer/123")
        data = await response.get_json()
        assert data["removed"] is True
        
@pytest.mark.asyncio
async def clients_informed_of_removal(monkeypatch):
    mock_client = MagicMock()
    monkeypatch.setattr(transfer, "clients", [mock_client])
    with patch("sqlite3.connect") as mock_connect:
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_cursor.rowcount = 1
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value.__enter__.return_value = mock_conn

        app = Quart(__name__)
        app.register_blueprint(transfer.transfer_bp)
        test_client = app.test_client()

        response = await test_client.delete("/transfer/123")
        data = await response.get_json()
        assert data["removed"] is True
        mock_client.put_nowait.assert_called_with({"action": "remove", "data": {"id": "123"}})

@pytest.mark.asyncio
async def test_delete_transfer_not_found(monkeypatch):
    monkeypatch.setattr(transfer, "clients", [MagicMock()])
    with patch("sqlite3.connect") as mock_connect:
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_cursor.rowcount = 0
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value.__enter__.return_value = mock_conn

        app = Quart(__name__)
        app.register_blueprint(transfer.transfer_bp)
        test_client = app.test_client()

        response = await test_client.delete("/transfer/999")
        data = await response.get_json()
        assert data["removed"] is False

@pytest.mark.asyncio
async def test_delete_all(monkeypatch):
    monkeypatch.setattr(transfer, "clients", [MagicMock()])
    with patch("sqlite3.connect") as mock_connect:
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_cursor.rowcount = 2
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value.__enter__.return_value = mock_conn

        app = Quart(__name__)
        app.register_blueprint(transfer.transfer_bp)
        test_client = app.test_client()

        response = await test_client.delete("/transfer/all")
        data = await response.get_json()
        assert data["removed"] is True
        
@pytest.mark.asyncio
async def test_delete_all_no_removals(monkeypatch):
    monkeypatch.setattr(transfer, "clients", [MagicMock()])
    with patch("sqlite3.connect") as mock_connect:
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_cursor.rowcount = 0
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value.__enter__.return_value = mock_conn

        app = Quart(__name__)
        app.register_blueprint(transfer.transfer_bp)
        test_client = app.test_client()

        response = await test_client.delete("/transfer/all")
        data = await response.get_json()
        assert data["removed"] is False
        
@pytest.mark.asyncio
async def test_delete_all_clients_informed(monkeypatch):
    mock_client = MagicMock()
    monkeypatch.setattr(transfer, "clients", [mock_client])
    with patch("sqlite3.connect") as mock_connect:
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_cursor.rowcount = 3
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value.__enter__.return_value = mock_conn

        app = Quart(__name__)
        app.register_blueprint(transfer.transfer_bp)
        test_client = app.test_client()

        response = await test_client.delete("/transfer/all")
        data = await response.get_json()
        assert data["removed"] is True
        mock_client.put_nowait.assert_called_with({"action": "removeAll", "data": {}})

@pytest.mark.asyncio
async def test_receive_status(monkeypatch):
    # Patch all external dependencies
    monkeypatch.setattr(transfer, "clients", [MagicMock()])
    monkeypatch.setattr("app.meta_lookup.tmdb.lookup_tmdb_info", lambda tmdbid, key: {"title": "Test Movie"})
    monkeypatch.setattr("app.meta_lookup.tvdb.lookup_tvdb_info", lambda tvdbid, key: {"name": "Test Show"})
    monkeypatch.setattr("app.db_service.save_transfer", lambda *a, **kw: None)
    monkeypatch.setattr("app.db_service.INCOMPLETE_STATUS", "incomplete")
    monkeypatch.setattr("app.db_service.COMPLETE_STATUS", "complete")

    app = Quart(__name__)
    app.register_blueprint(transfer.transfer_bp)
    test_client = app.test_client()

    payload = {
        "percent_complete": "100%",
        "meta": {"tmdbid": 123, "tvdbid": 456}
    }
    response = await test_client.post("/transfer/abc", json=payload)
    data = await response.get_json()
    assert data["status"] == "ok"
    
@pytest.mark.asyncio
async def test_receive_status_clients_informed(monkeypatch):
    mock_client = MagicMock()
    monkeypatch.setattr(transfer, "clients", [mock_client])
    monkeypatch.setattr("app.meta_lookup.tmdb.lookup_tmdb_info", lambda tmdbid, key: {"title": "Test Movie"})
    monkeypatch.setattr("app.meta_lookup.tvdb.lookup_tvdb_info", lambda tvdbid, key: {"name": "Test Show"})
    monkeypatch.setattr("app.db_service.save_transfer", lambda *a, **kw: None)
    monkeypatch.setattr("app.db_service.INCOMPLETE_STATUS", "incomplete")
    monkeypatch.setattr("app.db_service.COMPLETE_STATUS", "complete")

    app = Quart(__name__)
    app.register_blueprint(transfer.transfer_bp)
    test_client = app.test_client()

    payload = {
        "percent_complete": "50%",
        "meta": {"tmdbid": 123, "tvdbid": 456}
    }
    response = await test_client.post("/transfer/def", json=payload)
    data = await response.get_json()
    assert data["status"] == "ok"
    mock_client.put_nowait.assert_called()

    args, kwargs = mock_client.put_nowait.call_args

    sent_data = args[0]

    assert sent_data["action"] == "update"
    assert sent_data["data"]["status"] == "incomplete"
    assert sent_data["data"]["meta"]["tmdbid"] == 123
    assert sent_data["data"]["meta"]["tvdbid"] == 456
    assert sent_data["data"]["tmdb"]["title"] == "Test Movie"
    assert sent_data["data"]["tvdb"]["name"] == "Test Show"
    
@pytest.mark.asyncio
async def test_receive_status_clients_informed_complete(monkeypatch):
    mock_client = MagicMock()
    monkeypatch.setattr(transfer, "clients", [mock_client])
    monkeypatch.setattr("app.meta_lookup.tmdb.lookup_tmdb_info", lambda tmdbid, key: {"title": "Test Movie"})
    monkeypatch.setattr("app.meta_lookup.tvdb.lookup_tvdb_info", lambda tvdbid, key: {"name": "Test Show"})
    monkeypatch.setattr("app.db_service.save_transfer", lambda *a, **kw: None)
    monkeypatch.setattr("app.db_service.INCOMPLETE_STATUS", "incomplete")
    monkeypatch.setattr("app.db_service.COMPLETE_STATUS", "complete")

    app = Quart(__name__)
    app.register_blueprint(transfer.transfer_bp)
    test_client = app.test_client()

    payload = {
        "percent_complete": "100%",
        "meta": {"tmdbid": 123, "tvdbid": 456}
    }
    response = await test_client.post("/transfer/def", json=payload)
    data = await response.get_json()
    assert data["status"] == "ok"
    mock_client.put_nowait.assert_called()

    args, kwargs = mock_client.put_nowait.call_args

    sent_data = args[0]

    assert sent_data["action"] == "update"
    assert sent_data["data"]["status"] == "complete"
    assert sent_data["data"]["meta"]["tmdbid"] == 123
    assert sent_data["data"]["meta"]["tvdbid"] == 456
    assert sent_data["data"]["tmdb"]["title"] == "Test Movie"
    assert sent_data["data"]["tvdb"]["name"] == "Test Show"