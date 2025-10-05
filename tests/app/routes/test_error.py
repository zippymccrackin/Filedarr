import pytest
from quart import Quart
from app.routes.error import error_bp
import asyncio

@pytest.mark.asyncio
async def test_error_route(monkeypatch):
    # Create a fake async queue
    class FakeQueue:
        def __init__(self):
            self.items = []

        def put_nowait(self, item):
            # append item synchronously; no coroutine
            self.items.append(item)

    fake_client = FakeQueue()

    # Patch the global clients list
    monkeypatch.setattr("app.routes.error.clients", [fake_client])

    # Create Quart test app
    app = Quart(__name__)
    app.register_blueprint(error_bp)

    test_client = app.test_client()

    # Send POST request
    response = await test_client.post("/error", json={"message": "test error"})

    assert response.status_code == 200
    data = await response.get_json()
    assert data == {"status": "ok"}

    # Make sure the fake client got the message
    assert len(fake_client.items) == 1
    assert fake_client.items[0]["data"]["message"] == "test error"
