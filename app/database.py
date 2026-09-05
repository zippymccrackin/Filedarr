"""Short, explicitly closed SQLite transactions shared by every database user."""
from contextlib import contextmanager
import sqlite3
import threading

# Keep contention bounded below the importer's HTTP timeout. SQLite's busy
# handler retries external locks; the mutex queues this process's own writers.
BUSY_TIMEOUT_SECONDS = 2.0
_writer_lock = threading.RLock()


class DatabaseBusy(Exception):
    pass


@contextmanager
def connection(path, *, write=False, initialize=False):
    acquired = False
    raw = None
    try:
        if write:
            acquired = _writer_lock.acquire(timeout=BUSY_TIMEOUT_SECONDS)
            if not acquired:
                raise DatabaseBusy('The transfer database is busy. Please try again shortly.')
        raw = sqlite3.connect(path, timeout=BUSY_TIMEOUT_SECONDS)
        with raw as conn:
            if initialize:
                # Set once during startup, outside a transaction. WAL lets the
                # dashboard read while status updates are being committed.
                conn.execute('PRAGMA journal_mode=WAL')
            if write:
                # Acquire the write reservation before any read/modify/write work.
                conn.execute('BEGIN IMMEDIATE')
            yield conn
    except sqlite3.OperationalError as exc:
        code = getattr(exc, 'sqlite_errorcode', 0) & 0xff
        if code in (sqlite3.SQLITE_BUSY, sqlite3.SQLITE_LOCKED) or 'locked' in str(exc).lower():
            raise DatabaseBusy('The transfer database is busy. Please try again shortly.') from exc
        raise
    finally:
        try:
            if raw is not None:
                # sqlite3's context manager commits/rolls back but DOES NOT close.
                raw.close()
        finally:
            if acquired:
                _writer_lock.release()
