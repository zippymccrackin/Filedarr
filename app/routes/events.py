from quart import Blueprint, Response
import asyncio
import json
from app.db_service import load_all_transfers
from app.state import clients

events_bp = Blueprint("events", __name__)
KEEPALIVE_TIMEOUT = 5


@events_bp.route('/events')
async def events():
    async def event_stream():
        q = asyncio.Queue(maxsize=128)
        clients.append(q)
        try:
            transfers = await asyncio.to_thread(load_all_transfers)
            yield f'data: {json.dumps({"action": "init", "data": transfers})}\n\n'
            while True:
                try:
                    msg = await asyncio.wait_for(q.get(), timeout=KEEPALIVE_TIMEOUT)
                    if msg is None:
                        return
                    yield f"data: {json.dumps(msg)}\n\n"
                except asyncio.TimeoutError:
                    yield ": keep-alive\n\n"
        finally:
            clients.remove(q)

    response = Response(event_stream(), headers={
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "X-Accel-Buffering": "no",
    })
    response.timeout = None
    return response
