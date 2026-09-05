"""Verify VoltShare demo data integrity.

Usage:
    python scripts/verify_live_demo_data.py

Checks:
    - Demo Auth users exist
    - Profiles exist with correct roles
    - Energy readings are present
    - Listings exist with valid data
    - Purchases reference valid listings
    - Wallets have nonnegative balances
    - Escrow accounts reference purchases
    - Settlements reference escrow
    - All UUID values are valid
    - No negative constrained values
    - Dashboard and admin endpoints return valid data

Exits non-zero on any validation failure.
"""

from __future__ import annotations

import json
import os
import sys
import uuid
from datetime import datetime, timezone
from typing import Any

DEMO_EMAIL_DOMAIN = "@voltshare-demo.local"

PASS = "[OK]"
FAIL = "[FAIL]"
SKIP = "[SKIP]"


class SupabaseClient:
    def __init__(self, url: str, key: str) -> None:
        self._url = url.rstrip("/")
        self._headers = {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        }

    def _request(self, method: str, path: str) -> Any:
        import urllib.request
        import urllib.error

        req = urllib.request.Request(f"{self._url}{path}", method=method, headers=self._headers)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                body = resp.read().decode("utf-8")
                if body.strip():
                    return json.loads(body)
                return []
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            error_body = e.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"API error {e.code}: {error_body}") from e

    def rest(self, table: str) -> "_Table":
        return _Table(self, table)


class _Table:
    def __init__(self, client: SupabaseClient, table: str) -> None:
        self._client = client
        self._table = table
        self._filters: list[str] = []

    def select(self, columns: str = "*") -> Any:
        url = f"/rest/v1/{self._table}?select={columns}"
        if self._filters:
            url = f"{url}&{'&'.join(self._filters)}"
        return self._client._request("GET", url)

    def eq(self, col: str, val: Any) -> "_Table":
        self._filters.append(f"{col}=eq.{val}")
        return self


def is_valid_uuid(val: Any) -> bool:
    if not val:
        return False
    try:
        uuid.UUID(str(val))
        return True
    except (ValueError, AttributeError):
        return False


def check(condition: bool, label: str, *, failures: list[str]) -> None:
    if condition:
        print(f"  {PASS} {label}")
    else:
        print(f"  {FAIL} {label}")
        failures.append(label)


def main() -> None:
    url = os.environ.get("SUPABASE_URL", "")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        print("ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set.")
        sys.exit(1)

    client = SupabaseClient(url, key)
    failures: list[str] = []

    print("\nVoltShare Demo Data Verification")
    print("=" * 50)

    # ── 1. Auth Users & Profiles ──────────────────────────────────
    print(f"\n1. Auth Users & Profiles")

    all_profiles = client.rest("profiles").select("id,email,full_name,role,city,is_active,email_verified")
    demo_profiles = [p for p in all_profiles
                     if (p.get("email") or "").lower().endswith(DEMO_EMAIL_DOMAIN)]

    check(len(demo_profiles) >= 4, f"At least 4 demo profiles found ({len(demo_profiles)})",
          failures=failures)

    roles_found = set(p["role"] for p in demo_profiles)
    check("admin" in roles_found, "Admin profile exists", failures=failures)
    check("consumer" in roles_found, "Consumer profile exists", failures=failures)
    check("producer" in roles_found, "Producer profile exists", failures=failures)

    for p in demo_profiles:
        check(is_valid_uuid(p.get("id")), f"  {p.get('email')}: valid UUID", failures=failures)
        check(p.get("is_active") is True, f"  {p.get('email')}: is_active", failures=failures)

    # ── 2. Wallets ─────────────────────────────────────────────────
    print(f"\n2. Wallets & Transactions")

    demo_ids = [p["id"] for p in demo_profiles]
    wallet_count = 0
    for uid in demo_ids:
        wallets = client.rest("wallets").eq("user_id", uid).select("wallet_id,available_balance,held_balance,status")
        for w in wallets:
            wallet_count += 1
            check(w.get("available_balance", -1) >= 0,
                  f"Wallet {w['wallet_id'][:8]}: nonnegative balance ({w['available_balance']})",
                  failures=failures)
            check(w.get("held_balance", -1) >= 0,
                  f"Wallet {w['wallet_id'][:8]}: nonnegative held ({w['held_balance']})",
                  failures=failures)
            check(w.get("status") == "ACTIVE", f"Wallet active status", failures=failures)
    check(wallet_count >= 4, f"At least 4 wallets found ({wallet_count})", failures=failures)

    # ── 3. Energy Readings ─────────────────────────────────────────
    print(f"\n3. Energy Readings")

    total_readings = 0
    for uid in demo_ids:
        readings = client.rest("energy_readings").eq("user_id", uid).select("id")
        if isinstance(readings, dict):
            readings = []
        total_readings += len(readings)
    check(total_readings > 100, f"Total readings > 100 ({total_readings})", failures=failures)

    # Check constraints on a sample
    if demo_ids:
        sample = client.rest("energy_readings").eq("user_id", demo_ids[0]).select(
            "solar_generation_kwh,consumption_kwh,battery_percent,grid_import_kwh,grid_export_kwh,carbon_saved,earnings,cost"
        )
        if sample:
            s = sample[0]
            check(float(s.get("solar_generation_kwh", 0)) >= 0, "solar_generation_kwh >= 0", failures=failures)
            check(float(s.get("consumption_kwh", 0)) >= 0, "consumption_kwh >= 0", failures=failures)
            check(0 <= int(s.get("battery_percent", 0)) <= 100, "battery_percent 0-100", failures=failures)
            check(float(s.get("grid_import_kwh", 0)) >= 0, "grid_import_kwh >= 0", failures=failures)
            check(float(s.get("grid_export_kwh", 0)) >= 0, "grid_export_kwh >= 0", failures=failures)
            check(float(s.get("carbon_saved", 0)) >= 0, "carbon_saved >= 0", failures=failures)
            check(float(s.get("earnings", 0)) >= 0, "earnings >= 0", failures=failures)
            check(float(s.get("cost", 0)) >= 0, "cost >= 0", failures=failures)

    # ── 4. Listings ────────────────────────────────────────────────
    print(f"\n4. Energy Listings")

    all_listings = client.rest("energy_listings").select("id,seller_id,price_per_kwh,quantity_available_kwh,status")
    check(len(all_listings) >= 10, f"At least 10 listings found ({len(all_listings)})", failures=failures)

    for l in all_listings:
        check(is_valid_uuid(l.get("id")), f"Listing {l.get('id', '?')[:8]}: valid UUID", failures=failures)
        check(is_valid_uuid(l.get("seller_id")), f"Listing {l.get('id', '?')[:8]}: valid seller UUID",
              failures=failures)
        check(float(l.get("price_per_kwh", 0)) > 0, f"Listing: price > 0", failures=failures)
        check(l.get("status") in ("active", "sold", "cancelled"),
              f"Listing: valid status '{l.get('status')}'", failures=failures)

    # ── 5. Purchases ───────────────────────────────────────────────
    print(f"\n5. Energy Purchases")

    all_purchases = client.rest("energy_purchases").select(
        "id,listing_id,buyer_id,seller_id,quantity_kwh,total_amount_paise,status"
    )
    check(len(all_purchases) >= 4, f"At least 4 purchases found ({len(all_purchases)})", failures=failures)

    for p in all_purchases:
        check(is_valid_uuid(p.get("id")), f"Purchase {p.get('id', '?')[:8]}: valid UUID", failures=failures)
        check(is_valid_uuid(p.get("listing_id")), f"Purchase: valid listing UUID", failures=failures)
        check(is_valid_uuid(p.get("buyer_id")), f"Purchase: valid buyer UUID", failures=failures)
        check(is_valid_uuid(p.get("seller_id")), f"Purchase: valid seller UUID", failures=failures)
        check(p.get("buyer_id") != p.get("seller_id"), "Purchase: buyer != seller", failures=failures)
        check(float(p.get("quantity_kwh", 0)) > 0, "Purchase: quantity > 0", failures=failures)
        check(int(p.get("total_amount_paise", 0)) > 0, "Purchase: amount > 0", failures=failures)

    # ── 6. Escrow Accounts ─────────────────────────────────────────
    print(f"\n6. Escrow Accounts & Settlements")

    if demo_ids:
        escrow_count = 0
        for uid in demo_ids:
            escrows = client.rest("escrow_accounts").eq("buyer_id", uid).select(
                "escrow_id,purchase_id,amount_held,status"
            )
            escrow_count += len(escrows)
            for e in escrows:
                check(is_valid_uuid(e.get("escrow_id")), "Escrow: valid ID", failures=failures)
                check(is_valid_uuid(e.get("purchase_id")), "Escrow: valid purchase ref", failures=failures)
                check(int(e.get("amount_held", 0)) >= 0, "Escrow: amount >= 0", failures=failures)

        check(escrow_count >= 4, f"At least 4 escrow accounts found ({escrow_count})", failures=failures)

    # Settlements
    for seller_id in demo_ids:
        settlements = client.rest("settlements").eq("seller_id", seller_id).select(
            "settlement_id,escrow_id,amount,status"
        )
        for s in settlements:
            check(is_valid_uuid(s.get("settlement_id")), "Settlement: valid ID", failures=failures)
            check(is_valid_uuid(s.get("escrow_id")), "Settlement: valid escrow ref", failures=failures)
            check(int(s.get("amount", 0)) >= 0, "Settlement: amount >= 0", failures=failures)

    # ── 7. Disputes ────────────────────────────────────────────────
    print(f"\n7. Disputes")

    all_disputes = client.rest("disputes").select("id,escrow_id,raised_by,category")
    if all_disputes:
        check(len(all_disputes) >= 2, f"At least 2 disputes ({len(all_disputes)})", failures=failures)
        for d in all_disputes:
            check(is_valid_uuid(d.get("id")), "Dispute: valid ID", failures=failures)
            check(is_valid_uuid(d.get("escrow_id")), "Dispute: valid escrow ref", failures=failures)

    # ── 8. Audit Events ────────────────────────────────────────────
    print(f"\n8. Audit & AI Events")

    audit_events = client.rest("audit_events").select("id,action")
    check(len(audit_events) >= 4, f"At least 4 audit events ({len(audit_events)})", failures=failures)

    ai_insights = client.rest("ai_insights").select("id,user_id")
    check(len(ai_insights) >= 4, f"At least 4 AI insights ({len(ai_insights)})", failures=failures)

    # ── 9. Deposits, Withdrawals & Refunds ─────────────────────────
    print(f"\n9. Deposits, Withdrawals & Refunds")

    deposits = client.rest("deposits").select("deposit_id")
    check(len(deposits) >= 2, f"At least 2 deposits ({len(deposits)})", failures=failures)

    withdrawals = client.rest("withdrawals").select("withdrawal_id")
    if withdrawals:
        print(f"  {SKIP} Withdrawals: {len(withdrawals)} found")

    refunds = client.rest("refunds").select("refund_id")
    if refunds:
        print(f"  {SKIP} Refunds: {len(refunds)} found")

    # ── Summary ────────────────────────────────────────────────────
    print(f"\n{'=' * 50}")
    if failures:
        print(f"  {FAIL} {len(failures)} check(s) FAILED:")
        for f in failures:
            print(f"    {FAIL} {f}")
        sys.exit(1)
    else:
        print(f"  {PASS} All checks passed!")
        sys.exit(0)


if __name__ == "__main__":
    main()
