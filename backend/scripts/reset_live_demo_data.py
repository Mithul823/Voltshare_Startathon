"""Reset VoltShare demo data — deletes only demo-owned records.

Usage:
    python scripts/reset_live_demo_data.py          # confirm required
    python scripts/reset_live_demo_data.py --yes     # skip confirmation
    python scripts/reset_live_demo_data.py --dry-run # show counts only

Safety:
    - Only deletes records belonging to @voltshare-demo.local users.
    - Requires SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in environment.
    - Dry-run mode shows what would be deleted without deleting.
"""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from typing import Any

DEMO_EMAIL_DOMAIN = "@voltshare-demo.local"
DEMO_MARKER = "voltshare_demo_v1"


# ── Supabase client (same pattern as seed script) ─────────────────────


class SupabaseClient:
    def __init__(self, url: str, key: str) -> None:
        self._url = url.rstrip("/")
        self._headers = {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Prefer": "return=representation",
        }

    def _request(self, method: str, path: str, json_body: Any = None) -> Any:
        import urllib.request
        import urllib.error

        data = json.dumps(json_body).encode("utf-8") if json_body is not None else None
        req = urllib.request.Request(f"{self._url}{path}", data=data, method=method,
                                     headers=self._headers)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                body = resp.read().decode("utf-8")
                if body.strip():
                    return json.loads(body)
                return []
        except urllib.error.HTTPError as e:
            error_body = e.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"API error {e.code}: {error_body}") from e

    def rest(self, table: str) -> "_Table":
        return _Table(self, table)

    def admin_delete_user(self, user_id: str) -> None:
        self._request("DELETE", f"/auth/v1/admin/users/{user_id}")


class _Table:
    def __init__(self, client: SupabaseClient, table: str) -> None:
        self._client = client
        self._table = table
        self._filters: list[str] = []

    def _path(self) -> str:
        return f"/rest/v1/{self._table}"

    def select(self, columns: str = "*") -> list[dict[str, Any]]:
        url = f"{self._path()}?select={columns}"
        if self._filters:
            url = f"{url}&{'&'.join(self._filters)}"
        return self._client._request("GET", url)

    def eq(self, col: str, val: Any) -> "_Table":
        self._filters.append(f"{col}=eq.{val}")
        return self

    def delete(self) -> list[dict[str, Any]]:
        url = f"{self._path()}?{'&'.join(self._filters)}"
        return self._client._request("DELETE", url)


# ── Table delete order (reverse FK order) ──────────────────────────────

DELETE_ORDER = [
    "model_runs",
    "anomaly_events",
    "assistant_messages",
    "assistant_conversations",
    "sustainability_scores",
    "ai_recommendations",
    "ai_forecasts",
    "ai_insights",
    "idempotency_records",
    "audit_events",
    "login_events",
    "trusted_devices",
    "security_events",
    "trade_default_cases",
    "escrow_operations",
    "disputes",
    "transaction_audit",
    "refunds",
    "withdrawals",
    "deposits",
    "payment_methods",
    "settlements",
    "escrow_transactions",
    "escrow_accounts",
    "ledger_entries",
    "wallet_transactions",
    "wallets",
    "energy_purchase_orders",
    "energy_purchases",
    "energy_listings",
    "wallet_ledger_entries",
    "wallet_accounts",
    "energy_readings",
    "escrow_agreements",
    "profiles",
]


def get_demo_user_ids(client: SupabaseClient) -> dict[str, str]:
    """Return dict of demo email -> user_id from profiles."""
    all_profiles = client.rest("profiles").select("id,email")
    demo = {}
    for p in all_profiles:
        email = (p.get("email") or "").lower()
        if email.endswith(DEMO_EMAIL_DOMAIN):
            demo[email] = p["id"]
    return demo


def count_and_delete(client: SupabaseClient, table: str, demo_ids: set[str],
                     dry_run: bool) -> int:
    """Count and optionally delete demo-owned records for a table."""
    if table == "energy_listings":
        # Delete by seller_id being demo
        count = 0
        for uid in demo_ids:
            rows = client.rest(table).eq("seller_id", uid).select("id")
            if not dry_run and rows:
                client.rest(table).eq("seller_id", uid).delete()
            count += len(rows)
        return count

    if table == "energy_purchases":
        count = 0
        for uid in demo_ids:
            for col in ("buyer_id", "seller_id"):
                rows = client.rest(table).eq(col, uid).select("id")
                if not dry_run and rows:
                    client.rest(table).eq(col, uid).delete()
                count += len(rows)
        return count

    if table in ("energy_purchase_orders", "escrow_agreements", "escrow_operations"):
        # Cascade from purchases/escrows
        return 0

    if table == "energy_readings":
        count = 0
        for uid in demo_ids:
            rows = client.rest(table).eq("user_id", uid).select("id", count="exact")
            actual_count = len(rows)
            if not dry_run:
                client.rest(table).eq("user_id", uid).delete()
            count += actual_count
        return count

    if table == "escrow_accounts":
        count = 0
        for uid in demo_ids:
            for col in ("buyer_id", "seller_id"):
                rows = client.rest(table).eq(col, uid).select("escrow_account_id")
                if not dry_run and rows:
                    client.rest(table).eq(col, uid).delete()
                count += len(rows)
        return count

    if table == "profiles":
        count = len(demo_ids)
        if not dry_run:
            for uid in demo_ids:
                try:
                    client.rest(table).eq("id", uid).delete()
                except RuntimeError:
                    pass
        return count

    if table == "wallets":
        count = 0
        for uid in demo_ids:
            rows = client.rest(table).eq("user_id", uid).select("wallet_id")
            if not dry_run and rows:
                client.rest(table).eq("user_id", uid).delete()
            count += len(rows)
        return count

    # Generic: delete by user_id column
    for col in ("user_id", "actor_user_id", "raised_by"):
        count = 0
        for uid in demo_ids:
            try:
                rows = client.rest(table).eq(col, uid).select("id")
                if not dry_run and rows:
                    client.rest(table).eq(col, uid).delete()
                count += len(rows)
            except RuntimeError:
                pass
        if count > 0:
            return count

    return 0


def main() -> None:
    # ── Parse args ─────────────────────────────────────────────────
    dry_run = "--dry-run" in sys.argv
    auto_confirm = "--yes" in sys.argv

    if not auto_confirm and not dry_run:
        print("WARNING: This will delete ALL VoltShare demo data.")
        print(f"Demo records are identified by email domain: {DEMO_EMAIL_DOMAIN}")
        print(f"Run with --dry-run to preview or --yes to skip confirmation.\n")
        response = input("Type 'reset' to confirm: ").strip().lower()
        if response != "reset":
            print("Aborted.")
            sys.exit(1)

    # ── Connect ────────────────────────────────────────────────────
    url = os.environ.get("SUPABASE_URL", "")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        print("ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set.")
        sys.exit(1)

    client = SupabaseClient(url, key)
    demo_ids_map = get_demo_user_ids(client)

    if not demo_ids_map:
        print("No demo users found. Nothing to reset.")
        sys.exit(0)

    demo_emails = list(demo_ids_map.keys())
    demo_id_set = set(demo_ids_map.values())

    print(f"\nFound {len(demo_emails)} demo user(s):")
    for email in demo_emails:
        print(f"  {email} -> {demo_ids_map[email]}")
    print()

    if dry_run:
        print("DRY RUN — no records will be deleted\n")
    else:
        print("DELETING demo records...\n")

    total = 0
    for table in DELETE_ORDER:
        try:
            count = count_and_delete(client, table, demo_id_set, dry_run)
            if count > 0:
                status = "would delete" if dry_run else "deleted"
                print(f"  {status:15s} {count:5d} records from {table}")
                total += count
        except RuntimeError as e:
            print(f"  ⚠ Error deleting from {table}: {e}")

    # Auth users (delete via Admin API)
    auth_ids = set()
    all_profiles = client.rest("profiles").select("id,email")
    for p in all_profiles:
        email = (p.get("email") or "").lower()
        if email.endswith(DEMO_EMAIL_DOMAIN):
            auth_ids.add(p["id"])

    if not dry_run:
        for uid in auth_ids:
            try:
                client.admin_delete_user(uid)
            except RuntimeError:
                pass  # might already be deleted

    auth_status = "would delete" if dry_run else "deleted"
    print(f"  {auth_status:15s} {len(auth_ids):5d} Auth users (via Admin API)")

    print(f"\n{'DRY RUN - ' if dry_run else ''}Total records affected: {total + len(auth_ids)}")
    if dry_run:
        print("Run with --yes to delete.")


if __name__ == "__main__":
    main()
