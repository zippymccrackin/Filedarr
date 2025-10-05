import pytest
from unittest import mock
import os
from app import create_app

@pytest.mark.asyncio
async def test_app_initialization(monkeypatch):
    # create mocks
    monkeypatch.setattr("app.db_service.init_db", lambda: None)
    monkeypatch.setattr("app.db_service.start_background_tasks", lambda: None)
    
    app = create_app()
    assert app.debug is True
    
@pytest.mark.asyncio
async def test_app_blueprints_registered(monkeypatch):
    # create mocks
    monkeypatch.setattr("app.db_service.init_db", lambda: None)
    monkeypatch.setattr("app.db_service.start_background_tasks", lambda: None)
    
    app = create_app()
    registered_blueprints = app.blueprints.keys()
    
    expected_blueprints = [
        "assets",
        "events",
        "dashboard",
        "transfer",
        "error",
        "errorhandler"
    ]
    
    for bp in expected_blueprints:
        assert bp in registered_blueprints

@pytest.mark.asyncio
async def test_app_static_and_template_folders(monkeypatch):
    # create mocks
    monkeypatch.setattr("app.db_service.init_db", lambda: None)
    monkeypatch.setattr("app.db_service.start_background_tasks", lambda: None)
    
    app = create_app()
    
    app_root = os.path.dirname(os.path.dirname(os.path.abspath("app/__init__.py")))
    expected_template_folder = os.path.join(app_root, "templates")
    expected_static_folder = os.path.join(app_root, "static")
    
    assert app.template_folder == expected_template_folder
    assert app.static_folder == expected_static_folder
    
@pytest.mark.asyncio
async def test_app_cors_enabled(monkeypatch):
    # create mocks
    monkeypatch.setattr("app.db_service.init_db", lambda: None)
    monkeypatch.setattr("app.db_service.start_background_tasks", lambda: None)
    
    app = create_app()
    # Check if CORS headers are set in the response of a test request
    test_client = app.test_client()
    response = await test_client.get('/', headers={"Origin": "http://example.com"})
    assert 'Access-Control-Allow-Origin' in response.headers

@pytest.mark.asyncio
async def test_app_before_serving():
    background_tasks_started = {"flag": False}

    async def mock_start_background_tasks():
        background_tasks_started["flag"] = True

    def mock_init_db():
        pass

    with mock.patch("app.db_service.start_background_tasks", mock_start_background_tasks), \
         mock.patch("app.db_service.init_db", mock_init_db):
        import importlib
        import app
        importlib.reload(app)  # ensure module top-level code runs with mocks

        app_instance = app.create_app()

        async with app_instance.app_context():
            await app_instance.before_serving_funcs[0]()

    assert background_tasks_started["flag"] is True

@pytest.mark.asyncio
async def test_app_init_db_called():
    init_db_called = {"flag": False}

    def mock_init_db():
        init_db_called["flag"] = True

    with mock.patch("app.db_service.init_db", mock_init_db), \
         mock.patch("app.db_service.start_background_tasks", lambda: None):
        import importlib
        import app
        importlib.reload(app)  # reload ensures top-level code uses the mocks
        app.create_app()        # call factory; this calls the mocked init_db

    assert init_db_called["flag"] is True