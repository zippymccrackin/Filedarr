import requests
import json
import sqlite3
from datetime import datetime
from db_service import DB_FILE

def get_tvdb_token(api_key):
    url = "https://api4.thetvdb.com/v4/login"
    response = requests.post(url, json={"apikey": api_key})
    response.raise_for_status()
    return response.json().get("data", {}).get("token")

def get_cached_tmdb_info(tmdbid):
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('SELECT data, timestamp FROM tmdb_cache WHERE tmdbid = ?', (tmdbid,))
        row = c.fetchone()
        if row:
            cached_data, cached_time = row
            if datetime.now().timestamp() - cached_time < 86400:
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
