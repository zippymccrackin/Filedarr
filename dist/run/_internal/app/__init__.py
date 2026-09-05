from quart import Quart
from quart_cors import cors
from app.db_service import init_db, start_background_tasks
from app.assets import assets_bp
from app.routes.events import events_bp
from app.routes.dashboard import dashboard_bp
from app.routes.transfer import transfer_bp
from app.routes.error import error_bp
from app.error_handler import errorhandler_bp
import os

def create_app():
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    app = Quart(
        __name__, 
        template_folder=os.path.join(project_root, "templates"), 
        static_folder=os.path.join(project_root, "static")
    )
    app = cors(app)
    app.debug = True

    app.before_serving(start_background_tasks)
        
    init_db()

    app.register_blueprint(assets_bp)
    app.register_blueprint(events_bp)
    app.register_blueprint(dashboard_bp)
    app.register_blueprint(transfer_bp)
    app.register_blueprint(error_bp)
    app.register_blueprint(errorhandler_bp)
    
    return app