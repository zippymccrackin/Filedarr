from quart import Blueprint, jsonify

errorhandler_bp = Blueprint("errorhandler", __name__)

@errorhandler_bp.errorhandler(400)
async def bad_request(e):
    print(str(e))
    return jsonify(error=str(e)), 400

from app.database import DatabaseBusy


@errorhandler_bp.app_errorhandler(DatabaseBusy)
async def database_busy(error):
    from quart import current_app
    current_app.logger.warning("Database contention: %s", error)
    return jsonify(error=str(error), retryable=True), 503, {"Retry-After": "1"}
