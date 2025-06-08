from flask import Flask, request, jsonify, render_template, Response
from flask_cors import CORS
from threading import Lock
import sqlite3
import json
import time
import os
import requests
from dotenv import load_dotenv
import time

load_dotenv()

app = Flask(__name__, template_folder="templates", static_folder="static")
app.config["TEMPLATES_AUTO_RELOAD"] = True
CORS(app)

DB_FILE = "transfers.db"
clients = []
lock = Lock()

# --- DB Setup ---
def init_db():
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('''
            CREATE TABLE IF NOT EXISTS transfers (
                id TEXT PRIMARY KEY,
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
        conn.commit()

def save_transfer(id, data):
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('''
            REPLACE INTO transfers (id, data)
            VALUES (?, ?)
        ''', (id, json.dumps(data)))
        conn.commit()

def load_all_transfers():
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('SELECT data FROM transfers')
        rows = c.fetchall()
        return [json.loads(row[0]) for row in rows]

# --- Helpers ---
def get_transfers():
    transfers = []
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('SELECT data FROM transfers')
        for row in c.fetchall():
            transfers.append(json.loads(row[0]))
    return transfers

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
            if time.time() - cached_time < 86400:  # 24 hours
                return json.loads(cached_data)
    return None

def cache_tvdb_info(tvdbid, data):
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('''
            INSERT OR REPLACE INTO tvdb_cache (tvdbid, data, timestamp)
            VALUES (?, ?, ?)
        ''', (tvdbid, json.dumps(data), time.time()))
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

# --- Routes ---
@app.route('/')
def dashboard():
    return render_template("dashboard.html")

@app.route('/', methods=['POST'])
def receive_status():
    data = request.get_json()
    data["timestamp"] = time.time()
    id = data["id"]

    tvdbid = data.get("tvdbid")
    if tvdbid:
        info = lookup_tvdb_info(tvdbid, os.environ["TVDB_API_KEY"])
        if info:
            data["tvdb"] = info

    with lock:
        save_transfer(id, data)
        for client in clients:
            client.append({"action": "update", "data": data})

    return jsonify({"status": "ok"})

@app.route('/events')
def events():
    def event_stream():
        messages = []
        queue_index = 0
        clients.append(messages)

        try:
            messages.append({"action": "init", "data": get_transfers()})
            while True:
                while queue_index < len(messages):
                    yield f"data: {json.dumps(messages[queue_index])}\n\n"
                    queue_index += 1
                time.sleep(1)
        except GeneratorExit:
            clients.remove(messages)

    return Response(event_stream(), mimetype='text/event-stream')

@app.route("/transfer/<transfer_id>", methods=["DELETE"])
def delete_transfer(transfer_id):
    removed = False
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('''
            DELETE FROM transfers WHERE id = ?
        ''', (transfer_id))
        conn.commit()
        removed = c.rowcount > 0
    if removed:
        # notify clients
        for client in clients:
            client.append(jsonify({"action": "remove", "data": {"id": transfer_id}}))

    return jsonify({"removed": removed}), 200

# --- Entry Point ---
if __name__ == '__main__':
    os.makedirs("templates", exist_ok=True)
    os.makedirs("static", exist_ok=True)
    init_db()
    #print("Loaded saved transfers:", load_all_transfers())
    app.run(host='0.0.0.0', port=3565, threaded=True)
