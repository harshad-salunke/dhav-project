"""
Create the DHAV super-admin user.

What this does:
  1. Creates a Firebase Auth account (email + password)
  2. Inserts a row in the users table with role = 'admin'
  3. Inserts a row in the admin_users table

Run once from the backend/ folder:
    python scripts/create_admin.py

You will be prompted for the admin password.
"""

import asyncio
import os
import sys
import getpass

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from dotenv import load_dotenv
load_dotenv()

ADMIN_EMAIL = "dhav-admin@dhav.com"
ADMIN_NAME  = "DHAV Admin"


async def main():
    import asyncpg
    from urllib.parse import urlparse, unquote
    import firebase_admin
    from firebase_admin import credentials, auth as firebase_auth

    # ── 1. Init Firebase ───────────────────────────────────────────────────────
    sa_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
    sa_file = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "firebase-service-account.json")
    if sa_json:
        import json, tempfile
        tmp = tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False)
        tmp.write(sa_json); tmp.close()
        cred = credentials.Certificate(tmp.name)
    else:
        cred = credentials.Certificate(sa_file)

    firebase_admin.initialize_app(cred, {
        "projectId": os.environ.get("FIREBASE_PROJECT_ID", "dhav-quick-commerce")
    })

    # ── 2. Connect to PostgreSQL ───────────────────────────────────────────────
    raw_url = os.environ.get("DATABASE_URL", "")
    if not raw_url:
        print("ERROR: DATABASE_URL not set in .env"); return

    p = urlparse(raw_url)
    conn = await asyncpg.connect(
        host=p.hostname, port=p.port or 5432,
        user=unquote(p.username or ""),
        password=unquote(p.password or ""),
        database=(p.path or "/postgres").lstrip("/") or "postgres",
        statement_cache_size=0,
    )

    # ── 3. Check if admin already exists in PostgreSQL ─────────────────────────
    existing = await conn.fetchrow(
        "SELECT uid, role FROM users WHERE email = $1", ADMIN_EMAIL
    )
    if existing:
        print(f"\nUser {ADMIN_EMAIL} already exists in the database.")
        print(f"  UID  : {existing['uid']}")
        print(f"  Role : {existing['role']}")
        if existing["role"] != "admin":
            await conn.execute(
                "UPDATE users SET role='admin' WHERE email=$1", ADMIN_EMAIL
            )
            await conn.execute(
                "INSERT INTO admin_users (uid, role, created_at) VALUES ($1,'admin',0) ON CONFLICT (uid) DO NOTHING",
                existing["uid"],
            )
            print("  → Role updated to admin.")
        else:
            print("  → Already admin. Nothing to do.")
        await conn.close()
        return

    # ── 4. Get password from user ──────────────────────────────────────────────
    print(f"\nCreating admin account for: {ADMIN_EMAIL}")
    password = getpass.getpass("Enter admin password (min 8 chars): ")
    if len(password) < 8:
        print("ERROR: Password must be at least 8 characters."); await conn.close(); return

    # ── 5. Create Firebase Auth user ───────────────────────────────────────────
    try:
        user_record = firebase_auth.create_user(
            email=ADMIN_EMAIL,
            password=password,
            display_name=ADMIN_NAME,
        )
        uid = user_record.uid
        print(f"  ✓ Firebase Auth user created  (UID: {uid})")
    except firebase_auth.EmailAlreadyExistsError:
        # Already in Firebase — look up the UID
        user_record = firebase_auth.get_user_by_email(ADMIN_EMAIL)
        uid = user_record.uid
        print(f"  ℹ Firebase user already exists (UID: {uid})")
    except Exception as e:
        print(f"  ✗ Firebase error: {e}"); await conn.close(); return

    # ── 6. Insert into PostgreSQL users + admin_users ──────────────────────────
    from utils.helpers import now_ms
    try:
        await conn.execute("""
            INSERT INTO users (uid, email, name, role, is_active, created_at)
            VALUES ($1, $2, $3, 'admin', true, $4)
            ON CONFLICT (uid) DO UPDATE SET role = 'admin', is_active = true
        """, uid, ADMIN_EMAIL, ADMIN_NAME, now_ms())

        await conn.execute("""
            INSERT INTO admin_users (uid, role, created_at)
            VALUES ($1, 'admin', $2)
            ON CONFLICT (uid) DO NOTHING
        """, uid, now_ms())

        print(f"  ✓ Admin user inserted into PostgreSQL")
        print(f"\n{'─'*50}")
        print(f"  Admin account ready!")
        print(f"  Email   : {ADMIN_EMAIL}")
        print(f"  UID     : {uid}")
        print(f"  Role    : admin")
        print(f"{'─'*50}\n")
    except Exception as e:
        print(f"  ✗ PostgreSQL error: {e}")

    await conn.close()


if __name__ == "__main__":
    asyncio.run(main())
