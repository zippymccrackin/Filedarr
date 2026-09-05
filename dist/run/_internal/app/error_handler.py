from quart import Blueprint, jsonify

errorhandler_bp = Blueprint("errorhandler", __name__)

@errorhandler_bp.errorhandler(400)
async def bad_request(e):
    print(str(e))
    return jsonify(error=str(e)), 400