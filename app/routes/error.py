from quart import Blueprint, jsonify
from app.state import clients

error_bp = Blueprint("error", __name__)

@error_bp.route("/error", methods=["POST"])
async def error():
    from quart import request
    
    data = await request.get_json()
    
    for client in clients:
        client.put_nowait({"action": "error", "data": {"message": data["message"]}})
        
    return jsonify({"status": "ok"})