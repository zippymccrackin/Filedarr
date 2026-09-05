import asyncio
from app.state import broadcast
from quart import Blueprint, jsonify
from app.state import clients
from dotenv import load_dotenv
load_dotenv()
 
transfer_bp = Blueprint("transfer", __name__)
 
def _delete(transfer_id=None):
    import sqlite3
    from app.db_service import DB_FILE, COMPLETE_STATUS, STALE_STATUS
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        if transfer_id is None:
            c.execute("DELETE FROM transfers WHERE status IN (?, ?, ?)", (COMPLETE_STATUS, STALE_STATUS, "failed"))
        else:
            c.execute('DELETE FROM transfers WHERE id = ?', (transfer_id,))
        conn.commit()
        return c.rowcount > 0


@transfer_bp.route('/transfer/<transfer_id>', methods=["DELETE"])
async def delete_transfer(transfer_id):
    removed = await asyncio.to_thread(_delete, transfer_id)
    if removed:
        broadcast({"action": "remove", "data": {"id": transfer_id}}, clients)
    return jsonify(removed=removed)


@transfer_bp.route('/transfer/all', methods=["DELETE"])
async def delete_all():
    removed = await asyncio.to_thread(_delete)
    if removed:
        broadcast({"action": "removeAll", "data": {}}, clients)
    return jsonify(removed=removed)


def _receive_status(transfer_id, data):
    from app.meta_lookup.tmdb import lookup_tmdb_info
    from app.meta_lookup.tvdb import lookup_tvdb_info
    from app.db_service import INCOMPLETE_STATUS, COMPLETE_STATUS, save_transfer, load_transfer
    from datetime import datetime
    import os

    existing = load_transfer(transfer_id)
    if existing and existing.get("sequence", -1) >= data.get("sequence", 0):
        return None
    data["id"] = transfer_id
    data["timestamp"] = datetime.now().timestamp()
    status = COMPLETE_STATUS if data["percent_complete"] == "100%" and data.get("status") != "wrapup" else INCOMPLETE_STATUS
    if data.get("status") == "failed":
        status = "failed"
    for provider, lookup in (("tvdb", lookup_tvdb_info), ("tmdb", lookup_tmdb_info)):
        meta_id = data.get("meta", {}).get(provider + "id")
        key = os.getenv(provider.upper() + "_API_KEY")
        if existing and existing.get("meta", {}).get(provider + "id") == meta_id:
            if provider in existing:
                data[provider] = existing[provider]
            # Back off failed optional lookups rather than retrying every second.
            last_attempt = existing.get(provider + "_attempt", 0)
            data[provider + "_attempt"] = last_attempt
            if provider in data or data["timestamp"] - last_attempt < 300:
                continue
        if meta_id and key:
            data[provider + "_attempt"] = data["timestamp"]
            info = lookup(meta_id, key)
            if info:
                data[provider] = info
    data["status"] = status
    save_transfer(transfer_id, status, data)
    return data


@transfer_bp.route('/transfer/<transfer_id>', methods=['POST'])
async def receive_status(transfer_id):
    from quart import request, current_app
    data = await request.get_json()
    if (not isinstance(data, dict) or not isinstance(data.get("percent_complete"), str)
            or not isinstance(data.get("meta", {}), dict)
            or not isinstance(data.get("sequence", 0), int)):
        return jsonify(error="Invalid transfer status"), 400
    # Fixed-size locks bound memory and preserve per-transfer ordering across awaits.
    if "transfer_locks" not in current_app.extensions:
        current_app.extensions["transfer_locks"] = [asyncio.Lock() for _ in range(64)]
    locks = current_app.extensions["transfer_locks"]
    async with locks[hash(transfer_id) % len(locks)]:
        data = await asyncio.to_thread(_receive_status, transfer_id, data)
        if data is None:
            return jsonify(status="ignore")
        broadcast({"action": "update", "data": data}, clients)
    return jsonify(status="ok")
