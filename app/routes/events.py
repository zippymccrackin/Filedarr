from quart import Blueprint, Response, request
import asyncio
import json

# You may need to import or pass in these from your app structure
from app.db_service import load_all_transfers
from app.state import clients

events_bp = Blueprint("events", __name__)

@events_bp.route('/events')
async def events():
    q = asyncio.Queue()
    clients.append(q)
    await q.put({"action": "init", "data": load_all_transfers()})
    client_ip = request.remote_addr
    print(f"[Client connected] {client_ip}")

    async def event_stream():
        try:
            while True:
                try:
                    msg = await asyncio.wait_for(q.get(), timeout=5)
                    yield f"data: {json.dumps(msg)}\n\n"
                except asyncio.TimeoutError:
                    # keep alive
                    yield ": keep-alive\n\n"
        except asyncio.CancelledError:
            print(f"[Client disconnected] {client_ip}")
            clients.remove(q)

    return Response(event_stream(), headers={
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        "Transfer-Encoding": "chunked"
    })
