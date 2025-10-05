import pytest
from unittest import mock
from quart import Quart
from app.assets import assets_bp

@pytest.fixture
def app():
    """Create a Quart app with the assets blueprint."""
    app = Quart(__name__)
    app.register_blueprint(assets_bp)
    return app

@pytest.mark.asyncio
async def test_routes_return_files(app):
    test_client = app.test_client()

    # Mock send_from_directory to just return the filename for testing
    async def fake_send_from_directory(directory, filename, mimetype=None):
        from quart import Response
        return Response(f"{directory}/{filename}", mimetype=mimetype)

    with mock.patch("app.assets.send_from_directory", side_effect=fake_send_from_directory):
        routes = [
            ("/favicon.ico", "image/x-icon"),
            ("/favicon.svg", "image/svg+xml"),
            ("/apple-touch-icon.png", "image/png"),
            ("/favicon-96x96.png", "image/png"),
            ("/favicon-32x32.png", "image/png"),
            ("/favicon-16x16.png", "image/png"),
            ("/web-app-manifest-192x192.png", "image/png"),
            ("/web-app-manifest-512x512.png", "image/png"),
            ("/site.webmanifest", "application/manifest+json"),
            ("/style.css", "text/css"),
        ]

        for route, expected_type in routes:
            response = await test_client.get(route)
            assert response.status_code == 200
            assert expected_type in response.content_type, f"Expected '{expected_type}' to be in '{response.content_type}'"
