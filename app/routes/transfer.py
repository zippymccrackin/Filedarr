from quart import Blueprint, jsonify
from app.state import clients
from dotenv import load_dotenv
load_dotenv()
 
transfer_bp = Blueprint("transfer", __name__)
 
@transfer_bp.route('/transfer/<transfer_id>', methods=["DELETE"])
async def delete_transfer(transfer_id):
    import sqlite3
    from app.db_service import DB_FILE
    removed = False
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('DELETE FROM transfers WHERE id = ?', (transfer_id,))
        conn.commit()
        removed = c.rowcount > 0

    if removed:
        for client in clients:
            client.put_nowait({"action": "remove", "data": {"id": transfer_id}})

    return jsonify({"removed": removed})

@transfer_bp.route('/transfer/all', methods=["DELETE"])
async def delete_all():
    import sqlite3
    from app.db_service import DB_FILE, COMPLETE_STATUS, STALE_STATUS
    removed = False
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('DELETE FROM transfers WHERE status = ? OR status = ?', (COMPLETE_STATUS, STALE_STATUS))
        conn.commit()
        removed = c.rowcount > 0

    if removed:
        for client in clients:
            client.put_nowait({"action": "removeAll", "data": {}})

    return jsonify({"removed": removed})

@transfer_bp.route('/transfer/<transfer_id>', methods=['POST'])
async def receive_status(transfer_id):
    from app.meta_lookup.tmdb import lookup_tmdb_info
    from app.meta_lookup.tvdb import lookup_tvdb_info
    from app.db_service import INCOMPLETE_STATUS, COMPLETE_STATUS, save_transfer
    from datetime import datetime
    from quart import request
    import os
    
    data = await request.get_json()
    data["timestamp"] = datetime.now().timestamp()
    status = INCOMPLETE_STATUS if data["percent_complete"] != "100%" else COMPLETE_STATUS

    if (tvdbid := data.get("meta", {}).get("tvdbid")):
        info = lookup_tvdb_info(tvdbid, os.environ["TVDB_API_KEY"])
        if info:
            data["tvdb"] = info

    if (tmdbid := data.get("meta", {}).get("tmdbid")):
        info = lookup_tmdb_info(tmdbid, os.environ["TMDB_API_KEY"])
        if info:
            data["tmdb"] = info

    save_transfer(transfer_id, status, data)

    data["status"] = status
    for client in clients:
        client.put_nowait({"action": "update", "data": data})

    return jsonify({"status": "ok"})