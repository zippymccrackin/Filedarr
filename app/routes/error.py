from quart import Blueprint, jsonify
from app.state import clients, broadcast
from colorama import Fore, Style

error_bp = Blueprint("error", __name__)

@error_bp.route("/error", methods=["POST"])
async def error():
    from quart import request
    
    data = await request.get_json()
    
    print(data)
    print(Fore.RED + data["message"] + Style.RESET_ALL)
    
    broadcast({"action": "error", "data": {"message": data["message"]}}, clients)
        
    return jsonify({"status": "ok"})