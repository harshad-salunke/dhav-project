"""
PostgreSQL async data layer via asyncpg.

Replaces Firebase Realtime Database for all data storage.
Firebase Auth (phone OTP, verify_id_token) and FCM stay unchanged.

HOW IT WORKS
------------
asyncpg creates a connection pool at startup. Every router/service calls
`pool().acquire()` to borrow a connection for one operation, then returns it.
The pool is shared across the entire server process.

PgBouncer note: Supabase's transaction-mode pooler (port 6543) requires
statement_cache_size=0 — prepared statements don't survive across transactions
in PgBouncer's transaction mode. The `_clean_url` helper strips the
`?pgbouncer=true` Prisma param that asyncpg doesn't understand.

JSONB: JSON codecs are registered in `_setup_codecs` so JSONB columns come
back as Python dicts/lists automatically — no manual json.loads() needed.
"""
import json
import logging
import asyncpg
from urllib.parse import urlparse

log = logging.getLogger("db")
_pool: asyncpg.Pool | None = None


# ─── Pool lifecycle (called from main.py lifespan) ────────────────────────────

async def _setup_codecs(conn: asyncpg.Connection) -> None:
    """Register JSON/JSONB codecs so columns auto-deserialize to Python objects."""
    await conn.set_type_codec("json",  encoder=json.dumps, decoder=json.loads, schema="pg_catalog")
    await conn.set_type_codec("jsonb", encoder=json.dumps, decoder=json.loads, schema="pg_catalog")


def _parse_url(url: str) -> dict:
    """
    Parse a PostgreSQL URL into keyword args for asyncpg.create_pool().

    Passing credentials as separate kwargs instead of a URL string means
    special characters in the password (@, #, !, etc.) work without any
    manual URL-encoding by the developer.
    """
    from urllib.parse import unquote
    p = urlparse(url)
    # Strip trailing slash from path to get the database name
    database = (p.path or "/postgres").lstrip("/") or "postgres"
    return {
        "host":     p.hostname,
        "port":     p.port or 5432,
        "user":     unquote(p.username or ""),
        "password": unquote(p.password or ""),
        "database": database,
    }


async def init_pool(database_url: str) -> None:
    global _pool
    kwargs = _parse_url(database_url)
    _pool = await asyncpg.create_pool(
        **kwargs,
        min_size=2,
        max_size=10,
        statement_cache_size=0,  # required for PgBouncer transaction mode
        init=_setup_codecs,
    )
    log.info("PostgreSQL pool ready (Supabase)")


async def close_pool() -> None:
    global _pool
    if _pool:
        await _pool.close()
        _pool = None


def pool() -> asyncpg.Pool:
    """Return the live connection pool. Raises if init_pool() was not called."""
    if _pool is None:
        raise RuntimeError("DB pool not initialized — init_pool() must be called at startup")
    return _pool
