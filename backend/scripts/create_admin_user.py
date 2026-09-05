#!/usr/bin/env python3
"""Admin user bootstrap script for VoltShare.

Creates or updates an admin user in Supabase Auth and ensures the profiles
table has the correct admin role.

Usage:
    export SUPABASE_URL=https://your-project.supabase.co
    export SUPABASE_SERVICE_ROLE_KEY=eyJ...
    export ADMIN_EMAIL=admin@example.com
    export ADMIN_PASSWORD=<secure-password>
    python scripts/create_admin_user.py

Requirements:
    pip install httpx

Idempotent: safe to run multiple times.
Does not print passwords or expose the service-role key in output.
"""

import os
import sys

import httpx

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
ADMIN_EMAIL = os.environ.get("ADMIN_EMAIL", "admin@example.com")
ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD", "")


def main() -> None:
    if not SUPABASE_URL or not SERVICE_ROLE_KEY:
        print("FATAL: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set.", file=sys.stderr)
        sys.exit(1)

    if not ADMIN_PASSWORD:
        print("FATAL: ADMIN_PASSWORD must be set.", file=sys.stderr)
        sys.exit(1)

    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json",
    }

    auth_url = f"{SUPABASE_URL}/auth/v1/admin/users"
    rest_url = f"{SUPABASE_URL}/rest/v1/profiles"

    # STEP 1: Check if admin user already exists
    print(f"Checking for existing admin user: {ADMIN_EMAIL}")
    resp = httpx.get(
        f"{auth_url}?email={ADMIN_EMAIL}",
        headers=headers,
        timeout=10,
    )

    user_id: str | None = None

    if resp.status_code == 200:
        users = resp.json()
        if isinstance(users, list) and len(users) > 0:
            user_id = users[0]["id"]
            print(f"Admin user already exists (ID: {user_id})")
        else:
            print("Admin user not found; creating...")
    else:
        print(f"User lookup returned {resp.status_code}; creating user...")

    if not user_id:
        # STEP 2: Create admin user via Supabase Admin API
        create_resp = httpx.post(
            auth_url,
            headers=headers,
            json={
                "email": ADMIN_EMAIL,
                "password": ADMIN_PASSWORD,
                "email_confirm": True,
                "user_metadata": {"full_name": "VoltShare Admin"},
            },
            timeout=10,
        )

        if create_resp.status_code not in (200, 201):
            print(f"FATAL: Failed to create admin user: {create_resp.status_code}", file=sys.stderr)
            print(create_resp.text, file=sys.stderr)
            sys.exit(1)

        user_id = create_resp.json()["id"]
        print(f"Admin user created (ID: {user_id})")

    # STEP 3: Upsert profile with admin role
    print("Upserting admin profile...")
    profile_resp = httpx.post(
        rest_url,
        headers={
            **headers,
            "Prefer": "resolution=merge-duplicates",
        },
        json={
            "id": user_id,
            "email": ADMIN_EMAIL,
            "full_name": "VoltShare Admin",
            "role": "admin",
            "is_active": True,
            "email_verified": True,
        },
        timeout=10,
    )

    if profile_resp.status_code not in (200, 201, 204):
        print(f"WARNING: Profile upsert returned {profile_resp.status_code}")
        print(profile_resp.text)

    print("Admin bootstrap complete.")
    print(f"Sign in with email: {ADMIN_EMAIL}")
    print("Admin password is configured via environment variable.")


if __name__ == "__main__":
    main()
