import requests
import json
import sqlite3
from datetime import datetime
from app.db_service import DB_FILE

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
            if datetime.now().timestamp() - cached_time < 86400:
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

        cache_tvdb_info(tvdbid, info)
        return info
    except Exception as e:
        print(f"[TVDB Lookup Error] {e}")
        return None
