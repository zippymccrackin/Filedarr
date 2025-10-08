import sqlite3
import json
from datetime import datetime
import asyncio
from app.state import clients

DB_FILE = "transfers.db"

INCOMPLETE_STATUS = "incomplete"
COMPLETE_STATUS = "complete"
STALE_STATUS = "stale"

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

def load_transfer(id):
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('SELECT data, status FROM transfers WHERE id = ?', (id,))
        row = c.fetchone()
        if row:
            data = json.loads(row[0])
            data['status'] = row[1]
            return data
    return None

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

async def remove_stale_transfers():
    while True:
        try:
            threshold = datetime.now().timestamp() - 30
            stale_datas = []

            with sqlite3.connect(DB_FILE) as conn:
                c = conn.cursor()
                c.execute('SELECT id, data FROM transfers WHERE status = ?', (INCOMPLETE_STATUS,))
                rows = c.fetchall()
                for id, data_str in rows:
                    data = json.loads(data_str)
                    if data.get("timestamp", 0) < threshold:
                        c.execute('UPDATE transfers SET status = ? WHERE id = ?', (STALE_STATUS, id))
                        data["status"] = STALE_STATUS
                        stale_datas.append(data)

            for client in clients:
                for data in stale_datas:
                    client.put_nowait({"action": "update", "data": data})
        except Exception as e:
            print(f"[Stale cleanup error] {e}")

        await asyncio.sleep(10)

async def start_background_tasks():
    from quart import current_app
    current_app.add_background_task(remove_stale_transfers)
