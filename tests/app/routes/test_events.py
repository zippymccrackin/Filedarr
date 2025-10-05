import pytest
import asyncio
from unittest.mock import patch
from app.routes import events

class FakeQueue:
    callCount = 0
    
    def __init__(self, countUntilCancel=2, exceptionToRaise=None):
        self.countUntilCancel = countUntilCancel
        self.exceptionToRaise = exceptionToRaise
        self._items = []

    async def get(self):
        self.callCount += 1
        if self.callCount > self.countUntilCancel:
            raise asyncio.CancelledError
        
        if self.exceptionToRaise:
            raise self.exceptionToRaise
        
        return {"type": "http.request", "body": b"", "more_body": False}

    async def put(self, value):
        self._items.append(value)

    def empty(self):
        return len(self._items) == 0

    def task_done(self):
        pass

@pytest.mark.asyncio
async def test_events_route(monkeypatch):
    with patch("app.routes.events.asyncio.Queue", return_value=FakeQueue(0)):
        monkeypatch.setattr(events, "load_all_transfers", lambda: [{"id": "test", "status": "complete"}])

        from quart import Quart
        app = Quart(__name__)
        app.register_blueprint(events.events_bp)
        test_client = app.test_client()

        with pytest.raises(asyncio.CancelledError):
            await test_client.get("/events")
            
@pytest.mark.asyncio
async def test_events_route_data(monkeypatch):
    with patch("app.routes.events.asyncio.Queue", return_value=FakeQueue(1)):
        monkeypatch.setattr(events, "load_all_transfers", lambda: [{"id": "test", "status": "complete"}])

        from quart import Quart
        app = Quart(__name__)
        app.register_blueprint(events.events_bp)
        test_client = app.test_client()

        with pytest.raises(asyncio.CancelledError):
            response = await test_client.get("/events")
            chunks = []
            async for chunk in response.response:
                chunks.append(chunk.decode())
            body = b"".join(chunks).decode()
            assert "data: {\"action\": \"init\", \"data\": [{\"id\": \"test\", \"status\": \"complete\"}]}\n\n" in body
            
@pytest.mark.asyncio
async def test_events_route_keepalive(monkeypatch):
    monkeypatch.setattr(events, "KEEPALIVE_TIMEOUT", 0.01)
    monkeypatch.setattr(events, "load_all_transfers", lambda: [{"id": "test", "status": "complete"}])

    from quart import Quart
    app = Quart(__name__)
    app.register_blueprint(events.events_bp)
    test_client = app.test_client()
    
    async with test_client.request(method="GET", path="/events") as connection:
        for i in range(3):
            data = await connection.receive()
            print(f"Received data: {data!r}")
            assert connection.status_code == 200
            assert connection.headers.get("Content-Type") == "text/event-stream"
            
            if i == 0:
                continue  # skip init message
            # subsequent messages should be keep-alive
            assert data == b": keep-alive\n\n"
        
        await connection.disconnect()