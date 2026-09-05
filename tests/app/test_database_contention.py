import asyncio
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
import sqlite3
import time

import pytest
from app import create_app, database, db_service
from app.routes.transfer import _delete


@pytest.fixture
def initialized_db(tmp_path, monkeypatch):
    path = str(tmp_path / 'contention.db')
    monkeypatch.setattr(db_service, 'DB_FILE', path)
    db_service.init_db()
    return path


def test_wal_reader_does_not_block_delete(initialized_db):
    db_service.save_transfer('done', 'complete', {'id': 'done'})
    with closing(sqlite3.connect(initialized_db)) as reader:
        assert reader.execute('PRAGMA journal_mode').fetchone()[0] == 'wal'
        reader.execute('BEGIN')
        assert reader.execute('SELECT COUNT(*) FROM transfers').fetchone()[0] == 1
        assert _delete() is True
        # Reader keeps its snapshot; a new reader sees the committed deletion.
        assert reader.execute('SELECT COUNT(*) FROM transfers').fetchone()[0] == 1
        assert db_service.load_transfer('done') is None
        reader.rollback()


def test_connection_closed_and_rolled_back_after_failure(initialized_db):
    with pytest.raises(ValueError):
        with database.connection(initialized_db, write=True) as conn:
            conn.execute("INSERT INTO transfers VALUES ('rollback', 'complete', '{}')")
            raise ValueError('simulated failure')
    with pytest.raises(sqlite3.ProgrammingError, match='closed'):
        conn.execute('SELECT 1')
    assert db_service.load_transfer('rollback') is None
    # The writer mutex is released too, including to another thread.
    with ThreadPoolExecutor() as pool:
        pool.submit(db_service.save_transfer, 'after', 'complete', {}).result(timeout=3)


def test_delete_waits_for_transient_external_writer(initialized_db):
    db_service.save_transfer('done', 'complete', {'id': 'done'})
    with closing(sqlite3.connect(initialized_db)) as external, ThreadPoolExecutor() as pool:
        external.execute('BEGIN IMMEDIATE')
        pending = pool.submit(_delete)
        try:
            time.sleep(.1)
            assert not pending.done()
        finally:
            external.rollback()
        assert pending.result(timeout=3) is True


@pytest.mark.asyncio
async def test_persistent_lock_is_retryable_and_dashboard_stays_responsive(initialized_db, monkeypatch):
    app = create_app()
    client = app.test_client()
    monkeypatch.setattr(database, 'BUSY_TIMEOUT_SECONDS', .2)
    db_service.save_transfer('done', 'complete', {'id': 'done'})
    with closing(sqlite3.connect(initialized_db)) as external:
        external.execute('BEGIN IMMEDIATE')
        pending = asyncio.create_task(client.delete('/transfer/all'))
        assert (await asyncio.wait_for(client.get('/'), .5)).status_code == 200
        response = await pending
        assert response.status_code == 503
        assert response.headers['Retry-After'] == '1'
        assert (await response.get_json())['retryable'] is True
        external.rollback()
    assert (await (await client.delete('/transfer/all')).get_json())['removed'] is True


def test_concurrent_updates_cache_writes_cleanup_and_deletion(initialized_db, monkeypatch):
    from app.meta_lookup import tmdb, tvdb
    monkeypatch.setattr(tmdb, 'DB_FILE', initialized_db)
    monkeypatch.setattr(tvdb, 'DB_FILE', initialized_db)

    def update(worker):
        for sequence in range(25):
            db_service.save_transfer(str(worker), 'incomplete', {
                'id': str(worker), 'sequence': sequence, 'timestamp': time.time()})
            db_service.load_all_transfers()
        return True

    def cleanup():
        for i in range(25):
            db_service.save_transfer('done-' + str(i), 'complete', {'id': 'done-' + str(i)})
            _delete()
            db_service.mark_stale_transfers()
        return True

    def cache():
        for i in range(25):
            tmdb.cache_tmdb_info(i, {'title': str(i)})
            tvdb.cache_tvdb_info(i, {'name': str(i)})
        return True

    with ThreadPoolExecutor(max_workers=6) as pool:
        futures = [pool.submit(update, i) for i in range(4)] + [pool.submit(cleanup), pool.submit(cache)]
        assert all(future.result(timeout=20) for future in futures)
    for i in range(4):
        assert db_service.load_transfer(str(i))['sequence'] == 24
    with closing(sqlite3.connect(initialized_db)) as conn:
        assert conn.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
