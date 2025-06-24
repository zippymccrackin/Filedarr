from quart import Quart, request, jsonify, render_template, Response, send_from_directory
from quart_cors import cors
import sqlite3
import json
import os
import requests
import asyncio
from dotenv import load_dotenv
from datetime import datetime

load_dotenv()

app = Quart(__name__, template_folder="templates", static_folder="static")
app = cors(app)
app.debug = True

DB_FILE = "transfers.db"
clients = []

INCOMPLETE_STATUS = "incomplete"
COMPLETE_STATUS = "complete"
STALE_STATUS = "stale"

# --- Background Tasks ---
@app.before_serving
async def start_background_tasks():
    app.add_background_task(remove_stale_transfers)
    
async def remove_stale_transfers():
    while True:
        try:
            threshold = datetime.now().timestamp() - 30
            stale_datas = []

            with sqlite3.connect(DB_FILE) as conn:
                c = conn.cursor()
                c.execute('''
                    SELECT id, data FROM transfers WHERE status = ?
                ''', (INCOMPLETE_STATUS,))
                rows = c.fetchall()
                for id, data_str in rows:
                    data = json.loads(data_str)
                    last_updated = data.get("timestamp", 0)
                    if last_updated < threshold:
                        c.execute('UPDATE transfers SET status = ? WHERE id = ?', (STALE_STATUS, id))
                        print(f"[Background Task] Updated ID {id} to Stale status")
                        stale_datas.append(data)

            if stale_datas:
                for client in clients:
                    for stale_data in stale_datas:
                        client.put_nowait({"action": "update", "data": stale_data})
        except Exception as e:
            print(f"[Stale cleanup error] {e}")

        await asyncio.sleep(10)


# --- DB Setup ---
def init_db():
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('''
            CREATE TABLE IF NOT EXISTS transfers (
                id TEXT PRIMARY KEY,
                status TEXT,
                data TEXT
            )
        ''')
        c.execute('''
            CREATE TABLE IF NOT EXISTS tvdb_cache (
                tvdbid INTEGER PRIMARY KEY,
                data TEXT,
                timestamp REAL
            )
        ''')
        c.execute('''
            CREATE TABLE IF NOT EXISTS tmdb_cache (
                tmdbid INTEGER PRIMARY KEY,
                data TEXT,
                timestamp REAL
            )
        ''')
        conn.commit()

def save_transfer(id, status, data):
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('''
            REPLACE INTO transfers (id, status, data)
            VALUES (?, ?, ?)
        ''', (id, status, json.dumps(data)))
        conn.commit()

def load_all_transfers():
    transfers = []
    
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('SELECT data, status FROM transfers')
        for row in c.fetchall():
            data = json.loads(row[0])
            data['status'] = row[1]
            transfers.append(data)
    return transfers

# --- Helpers ---

def get_tvdb_token(api_key):
    url = "https://api4.thetvdb.com/v4/login"
    response = requests.post(url, json={"apikey": api_key})
    response.raise_for_status()
    return response.json().get("data", {}).get("token")

def get_cached_tvdb_info(tvdbid):
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('SELECT data, timestamp FROM tvdb_cache WHERE tvdbid = ?', (tvdbid,))
        row = c.fetchone()
        if row:
            cached_data, cached_time = row
            if datetime.now().timestamp() - cached_time < 86400:  # 24 hours
                return json.loads(cached_data)
    return None

def cache_tvdb_info(tvdbid, data):
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('''
            INSERT OR REPLACE INTO tvdb_cache (tvdbid, data, timestamp)
            VALUES (?, ?, ?)
        ''', (tvdbid, json.dumps(data), datetime.now().timestamp()))
        conn.commit()

def lookup_tvdb_info(tvdbid, api_key):
    # Check cache first
    cached = get_cached_tvdb_info(tvdbid)
    if cached:
        return cached

    try:
        token = get_tvdb_token(api_key)
        headers = {"Authorization": f"Bearer {token}"}
        url = f"https://api4.thetvdb.com/v4/series/{tvdbid}"
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        series = response.json().get("data", {})

        info = {
            "name": series.get("name"),
            "overview": series.get("overview"),
            "firstAired": series.get("firstAired"),
            "tvdb_id": series.get("id"),
            "image": series.get("image"),
            "slug": series.get("slug"),
            "url": f"https://thetvdb.com/series/{series.get('slug')}"
        }

        # Cache the result
        cache_tvdb_info(tvdbid, info)
        return info

    except Exception as e:
        print(f"[TVDB Lookup Error] {e}")
        return None

def get_cached_tmdb_info(tmdbid):
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('SELECT data, timestamp FROM tmdb_cache WHERE tmdbid = ?', (tmdbid,))
        row = c.fetchone()
        if row:
            cached_data, cached_time = row
            if datetime.now().timestamp() - cached_time < 86400:  # 24 hours
                return json.loads(cached_data)
    return None

def cache_tmdb_info(tmdbid, data):
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('''
            INSERT OR REPLACE INTO tmdb_cache (tmdbid, data, timestamp)
            VALUES (?, ?, ?)
        ''', (tmdbid, json.dumps(data), datetime.now().timestamp()))
        conn.commit()

def lookup_tmdb_info(tmdbid, api_key):
    cached = get_cached_tmdb_info(tmdbid)
    if cached:
        return cached

    try:
        url = f"https://api.themoviedb.org/3/movie/{tmdbid}?api_key={api_key}"
        response = requests.get(url)
        response.raise_for_status()
        movie = response.json()

        info = {
            "title": movie.get("title"),
            "overview": movie.get("overview"),
            "release_date": movie.get("release_date"),
            "tmdb_id": movie.get("id"),
            "poster_path": movie.get("poster_path"),
            "url": f"https://www.themoviedb.org/movie/{movie.get('id')}"
        }

        cache_tmdb_info(tmdbid, info)
        return info

    except Exception as e:
        print(f"[TMDB Lookup Error] {e}")
        return None

# --- Routes ---
@app.route('/')
async def dashboard():
    return await render_template("dashboard.html")

@app.route('/', methods=['POST'])
async def receive_status():
    data = await request.get_json()
    data["timestamp"] = datetime.now().timestamp()
    id = data["id"]
    status = INCOMPLETE_STATUS if data["percent_complete"] != "100%" else COMPLETE_STATUS

    tvdbid = data.get("meta", {}).get("tvdbid")
    if tvdbid:
        info = lookup_tvdb_info(tvdbid, os.environ["TVDB_API_KEY"])
        if info:
            data["tvdb"] = info

    tmdbid = data.get("meta", {}).get("tmdbid")
    if tmdbid:
        info = lookup_tmdb_info(tmdbid, os.environ["TMDB_API_KEY"])
        if info:
            data["tmdb"] = info

    save_transfer(id, status, data)
    
    data["staus"] = status
    for client in clients:
        client.put_nowait({"action": "update", "data": data})

    return jsonify({"status": "ok"})

@app.route('/events')
async def events():
    from asyncio import Queue
    q = Queue()
    clients.append(q)
    client_ip = request.remote_addr
    print(f"[Client connected] IP: {client_ip}")
    
    await q.put({"action": "init", "data": load_all_transfers()})
    
    async def event_stream():
        try:
            while True:
                try:
                    msg = await asyncio.wait_for(q.get(), timeout=15)
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
        "Connection": "keep-alive"
    })

@app.route("/transfer/<transfer_id>", methods=["DELETE"])
async def delete_transfer(transfer_id):
    client_ip = request.remote_addr
    print(f"[Client request] Delete request from IP: {client_ip}: {transfer_id}")

    removed = False
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('''
            DELETE FROM transfers WHERE id = ?
        ''', (transfer_id,))
        conn.commit()
        removed = c.rowcount > 0
    if removed:
        # notify clients
        for client in clients:
            client.put_nowait({"action": "remove", "data": {"id": transfer_id}})

    return jsonify({"removed": removed}), 200

@app.route("/transfer/all", methods=["DELETE"])
async def delete_transfer_all():
    client_ip = request.remote_addr
    print(f"[Client request] Delete all request from IP: {client_ip}")

    removed = False
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('''
            DELETE FROM transfers WHERE status = ?
        ''', (COMPLETE_STATUS,))
        conn.commit()
        removed = c.rowcount > 0
    if removed:
        # notify clients
        for client in clients:
            client.put_nowait({"action": "removeAll", "data": {}})

    return jsonify({"removed": removed}), 200

@app.errorhandler(400)
def bad_request(e):
    print(str(e))
    return jsonify(error=str(e)), 400

# Favicons
@app.route('/favicon.ico')
async def favicon():
    return await send_from_directory(os.path.join(app.root_path, 'static'), 'images/favicon.ico', mimetype='image/x-icon')
@app.route('/favicon.svg')
async def faviconsvg():
    return await send_from_directory(os.path.join(app.root_path, 'static'), 'images/favicon.svg', mimetype='image/x-icon')
@app.route('/apple-touch-icon.png')
async def apple_touch_icon():
    return await send_from_directory(os.path.join(app.root_path, 'static'), 'images/apple-touch-icon.png', mimetype='image/png')
@app.route('/favicon-96x96.png')
async def png_icon_9696():
    return await send_from_directory(os.path.join(app.root_path, 'static'), 'images/favicon-96x96.png', mimetype='image/png')
@app.route('/favicon-32x32.png')
async def png_icon_3232():
    return await send_from_directory(os.path.join(app.root_path, 'static'), 'images/favicon-32x32.png', mimetype='image/png')
@app.route('/favicon-16x16.png')
async def png_icon_1616():
    return await send_from_directory(os.path.join(app.root_path, 'static'), 'images/favicon-16x16.png', mimetype='image/png')
@app.route('/web-app-manifest-192x192.png')
async def png_icon_192192():
    return await send_from_directory(os.path.join(app.root_path, 'static'), 'images/web-app-manifest-192x192.png', mimetype='image/png')
@app.route('/web-app-manifest-512x512.png')
async def png_icon_512512():
    return await send_from_directory(os.path.join(app.root_path, 'static'), 'images/web-app-manifest-512x512.png', mimetype='image/png')
@app.route('/site.webmanifest')
async def site_manifest():
    return await send_from_directory(os.path.join(app.root_path, 'static'), 'site.webmanifest', mimetype='application/manifest+json')

# --- Entry Point ---
if __name__ == '__main__':
    os.makedirs("templates", exist_ok=True)
    os.makedirs("static", exist_ok=True)
    init_db()
    
    import uvicorn
    uvicorn.run(app, host='0.0.0.0', port=3565)