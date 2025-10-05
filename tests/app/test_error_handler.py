import pytest
from quart import Quart
from app.error_handler import bad_request

@pytest.mark.asyncio
async def test_bad_request_handler_direct():
    app = Quart(__name__)

    # Push an app context so jsonify() works
    async with app.app_context():
        response, status = await bad_request("Bad input!")

        # response is a Quart Response object
        data = await response.get_json()
        assert status == 400
        assert data is not None
        assert "error" in data
        assert data["error"] == "Bad input!"
