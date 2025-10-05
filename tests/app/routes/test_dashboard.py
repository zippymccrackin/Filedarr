import pytest
from quart import Quart
from unittest.mock import patch
from app.routes.dashboard import dashboard_bp

@pytest.mark.asyncio
async def test_dashboard_route_renders_template_mocked():
    app = Quart(__name__)
    app.register_blueprint(dashboard_bp)

    async def fake_render_template(template_name):
        return "mocked html"

    with patch("app.routes.dashboard.render_template", side_effect=fake_render_template):
        test_client = app.test_client()
        response = await test_client.get("/")
        assert response.status_code == 200
        html = await response.get_data(as_text=True)
        assert html == "mocked html"
