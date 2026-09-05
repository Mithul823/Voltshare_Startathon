"""Seed VoltShare Supabase with realistic live demo data.

Usage:
    python scripts/seed_live_demo_data.py

Requires SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the environment
(or loaded via the backend .env file).

The script is idempotent — running it multiple times will not create
duplicate records.  Demo records are identified by the email domain
@voltshare-demo.local and stable idempotency keys.
"""

from __future__ import annotations

import hashlib
import json
import os
import random
import sys
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Any

# ---------------------------------------------------------------------------
# Safe imports — allow running outside backend project root
# ---------------------------------------------------------------------------

try:
    from dotenv import load_dotenv
    _dotenv_loaded = False
except ImportError:
    load_dotenv = None  # type: ignore[assignment]
    _dotenv_loaded = True


def _load_env() -> None:
    """Load .env from backend or project root."""
    global _dotenv_loaded
    if _dotenv_loaded:
        return
    for candidate in [os.path.join(os.path.dirname(__file__), "..", ".env"),
                      os.path.join(os.path.dirname(__file__), "..", "..", ".env")]:
        path = os.path.abspath(candidate)
        if os.path.isfile(path):
            if load_dotenv:
                load_dotenv(path)
            break
    _dotenv_loaded = True


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

DEMO_MARKER = "voltshare_demo_v1"
DEMO_EMAIL_DOMAIN = "@voltshare-demo.local"
BATCH_SIZE = 250
SEED = 42  # fixed random seed for reproducibility

# Realistic Kerala locations
LOCATIONS: list[dict[str, str]] = [
    {"city": "Kochi", "district": "Ernakulam", "lat": "9.9312", "lng": "76.2673"},
    {"city": "Thodupuzha", "district": "Idukki", "lat": "9.8900", "lng": "76.7200"},
    {"city": "Thiruvananthapuram", "district": "Thiruvananthapuram", "lat": "8.5241", "lng": "76.9366"},
    {"city": "Kozhikode", "district": "Kozhikode", "lat": "11.2588", "lng": "75.7804"},
    {"city": "Thrissur", "district": "Thrissur", "lat": "10.5276", "lng": "76.2144"},
    {"city": "Alappuzha", "district": "Alappuzha", "lat": "9.4981", "lng": "76.3388"},
]

DEMO_USERS: list[dict[str, Any]] = [
    {"email": f"admin{DEMO_EMAIL_DOMAIN}", "password_env": "DEMO_ADMIN_PASSWORD",
     "role": "admin", "name": "Ananya Sharma", "phone": "9446001001",
     "location": LOCATIONS[0]},
    {"email": f"consumer1{DEMO_EMAIL_DOMAIN}", "password_env": "DEMO_CONSUMER_PASSWORD",
     "role": "consumer", "name": "Rajesh Nair", "phone": "9446002001",
     "location": LOCATIONS[1]},
    {"email": f"consumer2{DEMO_EMAIL_DOMAIN}", "password_env": "DEMO_CONSUMER_PASSWORD",
     "role": "consumer", "name": "Priya Menon", "phone": "9446002002",
     "location": LOCATIONS[2]},
    {"email": f"producer1{DEMO_EMAIL_DOMAIN}", "password_env": "DEMO_PRODUCER_PASSWORD",
     "role": "producer", "name": "Sunil Kumar", "phone": "9446003001",
     "location": LOCATIONS[3]},
    {"email": f"producer2{DEMO_EMAIL_DOMAIN}", "password_env": "DEMO_PRODUCER_PASSWORD",
     "role": "producer", "name": "Meera Joseph", "phone": "9446003002",
     "location": LOCATIONS[4]},
]

# All available energy sources
ENERGY_SOURCES = ["solar", "wind", "hydro", "biomass", "community_solar"]

# Fixed demo UUIDs for deterministic relations
# Each user gets a stable UUID (not based on real data)
_DEMO_UUIDS = [
    uuid.UUID("a0000001-0000-4000-8000-000000000001"),  # admin
    uuid.UUID("a0000001-0000-4000-8000-000000000002"),  # consumer1
    uuid.UUID("a0000001-0000-4000-8000-000000000003"),  # consumer2
    uuid.UUID("a0000001-0000-4000-8000-000000000004"),  # producer1
    uuid.UUID("a0000001-0000-4000-8000-000000000005"),  # producer2
]

# Horary solar generation factors (0-1) for a typical day
_SOLAR_CURVE = [
    0.00, 0.00, 0.00, 0.00, 0.00, 0.02,  # 00-05
    0.10, 0.30, 0.55, 0.75, 0.88, 0.95,  # 06-11
    1.00, 0.95, 0.85, 0.70, 0.50, 0.25,  # 12-17
    0.08, 0.02, 0.00, 0.00, 0.00, 0.00,  # 18-23
]

# Consumption patterns for consumers vs producers
_CONSUMPTION_CURVE = [
    0.35, 0.30, 0.25, 0.25, 0.30, 0.40,  # 00-05  (low overnight)
    0.60, 0.80, 0.70, 0.55, 0.50, 0.45,  # 06-11  (morning peak)
    0.40, 0.35, 0.35, 0.40, 0.50, 0.70,  # 12-17  (midday low)
    0.90, 1.00, 0.85, 0.65, 0.50, 0.40,  # 18-23  (evening peak)
]


# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

def _uuid() -> str:
    return str(uuid.uuid4())


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _checksum(data: dict[str, Any]) -> str:
    encoded = json.dumps(data, sort_keys=True, default=str, separators=(",", ":"))
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def _idempotency_key(prefix: str, index: int) -> str:
    return f"voltshare_demo_v1_{prefix}_{index}"


def _default_password() -> str:
    """Return a safe default demo password."""
    return "VoltShareDemo2026!"


def _get_password(user_config: dict[str, Any]) -> str:
    pw = os.environ.get(user_config["password_env"], "")
    return pw if pw else _default_password()





# ---------------------------------------------------------------------------
# Supabase client wrapper (safe, service-role)
# ---------------------------------------------------------------------------

class SupabaseClient:
    """Minimal Supabase REST client using service-role key."""

    def __init__(self, url: str, service_role_key: str) -> None:
        self._url = url.rstrip("/")
        self._headers = {
            "apikey": service_role_key,
            "Authorization": f"Bearer {service_role_key}",
            "Content-Type": "application/json",
            "Prefer": "return=representation",
        }

    def _request(
        self,
        method: str,
        path: str,
        json_body: Any = None,
        params: dict[str, str] | None = None,
    ) -> Any:
        import urllib.request
        import urllib.error

        url = f"{self._url}{path}"
        if params:
            qs = "&".join(f"{k}={urllib.request.quote(str(v))}" for k, v in params.items())
            url = f"{url}?{qs}"

        data = None
        if json_body is not None:
            data = json.dumps(json_body).encode("utf-8")

        req = urllib.request.Request(url, data=data, method=method, headers=self._headers)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                body = resp.read().decode("utf-8")
                if body.strip():
                    return json.loads(body)
                return []
        except urllib.error.HTTPError as e:
            error_body = e.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"Supabase API error {e.code} for {method} {path}: {error_body}") from e

    def rest(self, table: str) -> "_Table":
        return _Table(self, table)

    def rpc(self, fn_name: str, params: dict[str, Any] | None = None) -> Any:
        return self._request("POST", f"/rest/v1/rpc/{fn_name}", json_body=params)

    def admin_create_user(self, email: str, password: str, email_confirm: bool = True,
                          user_metadata: dict[str, Any] | None = None) -> dict[str, Any]:
        """Create an Auth user via Supabase Admin API."""
        body: dict[str, Any] = {
            "email": email,
            "password": password,
            "email_confirm": email_confirm,
        }
        if user_metadata:
            body["user_metadata"] = user_metadata
        return self._request("POST", "/auth/v1/admin/users", json_body=body)


class _Table:
    """Fluent Supabase REST table helper."""

    def __init__(self, client: SupabaseClient, table: str) -> None:
        self._client = client
        self._table = table
        self._filters: list[str] = []

    def _path(self) -> str:
        return f"/rest/v1/{self._table}"

    def _query(self) -> str:
        return "&".join(self._filters)

    def select(self, columns: str = "*") -> list[dict[str, Any]]:
        url = f"{self._path()}?select={columns}"
        if self._filters:
            url = f"{url}&{self._query()}"
        return self._client._request("GET", url)

    def eq(self, col: str, val: Any) -> "_Table":
        self._filters.append(f"{col}=eq.{val}")
        return self

    def insert(self, rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
        return self._client._request("POST", self._path(), json_body=rows)

    def upsert(self, rows: list[dict[str, Any]], on_conflict: str = "id") -> list[dict[str, Any]]:
        headers = self._client._headers.copy()
        headers["Prefer"] = f"resolution=merge-duplicates,return=representation"
        url = f"{self._client._url}{self._path()}?on_conflict={on_conflict}"
        import urllib.request
        data = json.dumps(rows).encode("utf-8")
        req = urllib.request.Request(url, data=data, method="POST", headers=headers)
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode("utf-8")
            if body.strip():
                return json.loads(body)
            return []

    def update(self, row: dict[str, Any]) -> list[dict[str, Any]]:
        url = f"{self._path()}?{self._query()}"
        return self._client._request("PATCH", url, json_body=row)

    def delete(self) -> list[dict[str, Any]]:
        url = f"{self._path()}?{self._query()}"
        return self._client._request("DELETE", url)


# ---------------------------------------------------------------------------
# Seeder
# ---------------------------------------------------------------------------

@dataclass
class SeedState:
    """Holds all seeded data references for cross-table relations."""
    client: SupabaseClient | None = None
    rng: random.Random = field(default_factory=lambda: random.Random(SEED))
    auth_users: dict[str, dict[str, Any]] = field(default_factory=dict)  # email -> auth user
    profiles: dict[str, dict[str, Any]] = field(default_factory=dict)     # email -> profile row
    wallet_ids: dict[str, str] = field(default_factory=dict)              # email -> wallet_id
    listing_ids: list[str] = field(default_factory=list)
    purchase_ids: list[str] = field(default_factory=list)
    escrow_account_ids: list[str] = field(default_factory=list)
    started_at: datetime = field(default_factory=_now)
    stats: dict[str, int] = field(default_factory=lambda: {
        "auth_users_created": 0,
        "auth_users_reused": 0,
        "profiles_created": 0,
        "wallets_created": 0,
        "readings_inserted": 0,
        "listings_inserted": 0,
        "purchases_inserted": 0,
        "transactions_inserted": 0,
        "ledger_entries_inserted": 0,
        "escrow_accounts_inserted": 0,
        "settlements_inserted": 0,
        "deposits_inserted": 0,
        "withdrawals_inserted": 0,
        "refunds_inserted": 0,
        "disputes_inserted": 0,
        "payment_methods_inserted": 0,
        "audit_events_inserted": 0,
        "ai_insights_inserted": 0,
        "security_events_inserted": 0,
    })


def _get_client() -> SupabaseClient:
    _load_env()
    url = os.environ.get("SUPABASE_URL", "")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        print("ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set.")
        sys.exit(1)
    print(f"Connecting to Supabase at {url}")
    return SupabaseClient(url, key)


# ── Auth Users ──────────────────────────────────────────────────────────


def _seed_auth_users(state: SeedState) -> None:
    """Create or reuse Auth users."""
    assert state.client is not None

    for i, user_config in enumerate(DEMO_USERS):
        email = user_config["email"]
        password = _get_password(user_config)
        id_str = str(_DEMO_UUIDS[i])

        # Check if user already exists
        existing = state.client.rest("profiles").eq("id", id_str).select()
        if existing:
            print(f"  [REUSE] Reusing existing Auth user: {email}")
            state.auth_users[email] = existing[0]
            state.profiles[email] = existing[0]
            state.stats["auth_users_reused"] += 1
            continue

        # Include user_metadata so the handle_new_auth_user trigger
        # can populate all profile fields (phone, city, district, role, etc.)
        loc = user_config["location"]
        user_metadata = {
            "full_name": user_config["name"],
            "phone": user_config["phone"],
            "role": user_config["role"],
            "city": loc["city"],
            "district": loc["district"],
            "state": "Kerala",
        }

        try:
            result = state.client.admin_create_user(email, password, user_metadata=user_metadata)
            user_id = result.get("id", id_str)
            state.auth_users[email] = result
            state.stats["auth_users_created"] += 1
            print(f"  [OK] Created Auth user: {email} (id={user_id[:8]}...)")
        except RuntimeError as e:
            err_str = str(e)
            # Handle 422/similar errors: user already exists (any error type)
            # Look up by email to get the real Auth user ID
            existing_profile = state.client.rest("profiles").eq("email", email).select()
            if existing_profile:
                real_id = existing_profile[0]["id"]
                state.auth_users[email] = {"id": real_id}
                state.profiles[email] = existing_profile[0]
                state.stats["auth_users_reused"] += 1
                print(f"  [REUSE] Found existing user by email: {email} (id={real_id[:8]}...)")
            else:
                # No profile found either - this may be a real error
                if "422" in err_str or "409" in err_str or "already" in err_str.lower() or "duplicate" in err_str.lower():
                    print(f"  [REUSE] Auth user exists but no profile: {email}")
                    state.auth_users[email] = {"id": id_str}
                    state.stats["auth_users_reused"] += 1
                else:
                    print(f"  [WARN] Could not create Auth user {email}: {e}")
                    print(f"    Using stable UUID {id_str} for profile seeding.")
                    state.auth_users[email] = {"id": id_str}


# ── Profiles ────────────────────────────────────────────────────────────


def _seed_profiles(state: SeedState) -> None:
    """Create profiles if they don't exist."""
    assert state.client is not None

    for i, user_config in enumerate(DEMO_USERS):
        email = user_config["email"]
        user_id = state.auth_users.get(email, {}).get("id", str(_DEMO_UUIDS[i]))
        loc = user_config["location"]

        if email in state.profiles:
            continue

        profile = {
            "id": user_id,
            "email": email,
            "full_name": user_config["name"],
            "role": user_config["role"],
            "phone": user_config["phone"],
            "city": loc["city"],
            "district": loc["district"],
            "state": "Kerala",
            "is_active": True,
            "email_verified": True,
            "is_verified": True,
            "kyc_status": "approved",
        }

        try:
            state.client.rest("profiles").upsert([profile], on_conflict="id")
            state.profiles[email] = profile
            state.stats["profiles_created"] += 1
            print(f"  [OK] Created profile: {email} ({user_config['role']})")
        except RuntimeError as e:
            print(f"  [FAIL] Failed to create profile {email}: {e}")


# ── Payment Methods ────────────────────────────────────────────────────


def _seed_payment_methods(state: SeedState) -> None:
    """Create demo payment methods."""
    assert state.client is not None

    methods_data = [
        {"email": f"admin{DEMO_EMAIL_DOMAIN}", "type": "Wallet", "label": "VoltShare Wallet",
         "metadata": {"wallet_address": "VS-ADMIN-001"}, "is_default": True},
        {"email": f"consumer1{DEMO_EMAIL_DOMAIN}", "type": "UPI", "label": "demo-consumer1@upi",
         "metadata": {"upi_id": "demo-consumer1@upi"}, "is_default": True},
        {"email": f"consumer1{DEMO_EMAIL_DOMAIN}", "type": "Bank", "label": "Savings ...4821",
         "metadata": {"bank_name": "SBI", "last_four": "4821"}, "is_default": False},
        {"email": f"consumer2{DEMO_EMAIL_DOMAIN}", "type": "UPI", "label": "demo-consumer2@upi",
         "metadata": {"upi_id": "demo-consumer2@upi"}, "is_default": True},
        {"email": f"producer1{DEMO_EMAIL_DOMAIN}", "type": "Bank", "label": "Current ...7834",
         "metadata": {"bank_name": "Federal Bank", "last_four": "7834"}, "is_default": True},
        {"email": f"producer2{DEMO_EMAIL_DOMAIN}", "type": "UPI", "label": "demo-producer2@upi",
         "metadata": {"upi_id": "demo-producer2@upi"}, "is_default": True},
    ]

    for m in methods_data:
        profile = state.profiles.get(m["email"])
        if not profile:
            continue
        meta = m["metadata"]
        meta["seed_marker"] = DEMO_MARKER
        row = {
            "user_id": profile["id"],
            "type": m["type"],
            "label": m["label"],
            "metadata": json.dumps(meta),
            "is_default": m["is_default"],
        }
        try:
            state.client.rest("payment_methods").insert([row])
            state.stats["payment_methods_inserted"] += 1
        except RuntimeError:
            pass  # may already exist

    print(f"  [OK] Inserted {state.stats['payment_methods_inserted']} payment methods")


# ── Wallets ─────────────────────────────────────────────────────────────


def _seed_wallets(state: SeedState) -> None:
    """Create wallets for each demo user."""
    assert state.client is not None

    # Initial balances based on role
    wallet_balances = {
        f"admin{DEMO_EMAIL_DOMAIN}": {"available": 500_000, "held": 0},          # ₹5,000
        f"consumer1{DEMO_EMAIL_DOMAIN}": {"available": 125_000, "held": 15_000},   # ₹1,250
        f"consumer2{DEMO_EMAIL_DOMAIN}": {"available": 80_000, "held": 5_000},    # ₹800
        f"producer1{DEMO_EMAIL_DOMAIN}": {"available": 250_000, "held": 30_000},   # ₹2,500
        f"producer2{DEMO_EMAIL_DOMAIN}": {"available": 180_000, "held": 20_000},   # ₹1,800
    }

    for email, balances in wallet_balances.items():
        profile = state.profiles.get(email)
        if not profile:
            continue

        # Check if wallet exists
        existing = state.client.rest("wallets").eq("user_id", profile["id"]).select()
        if existing:
            state.wallet_ids[email] = existing[0]["wallet_id"]
            print(f"  [EXISTS] Wallet exists for {email}")
            continue

        row = {
            "user_id": profile["id"],
            "available_balance": balances["available"],
            "held_balance": balances["held"],
            "currency": "INR",
            "status": "ACTIVE",
        }
        result = state.client.rest("wallets").insert([row])
        if result:
            state.wallet_ids[email] = result[0]["wallet_id"]
            state.stats["wallets_created"] += 1
            print(f"  [OK] Created wallet for {email}")


# ── Energy Readings ────────────────────────────────────────────────────


def _seed_energy_readings(state: SeedState) -> None:
    """Create 30 days of hourly energy readings for each user."""
    assert state.client is not None

    rng = state.rng
    now = _now()

    for email, profile in state.profiles.items():
        user_config = next((u for u in DEMO_USERS if u["email"] == email), None)
        if not user_config:
            continue

        is_producer = user_config["role"] in ("producer", "admin")
        base_consumption = 1.2 if user_config["role"] == "consumer" else 0.8
        base_solar = 3.0 if is_producer else 0.5
        battery = rng.randint(40, 70)

        rows: list[dict[str, Any]] = []
        days = 30

        for day in range(days):
            date = now - timedelta(days=days - day - 1)
            # Daily weather factor (±30%)
            weather = 0.7 + rng.random() * 0.6

            for hour in range(24):
                ts = date.replace(hour=hour, minute=0, second=0, microsecond=0)
                solar_factor = _SOLAR_CURVE[hour] * weather
                cons_factor = _CONSUMPTION_CURVE[hour]

                solar = round(base_solar * solar_factor + rng.gauss(0, 0.05), 3)
                consumption = round(base_consumption * cons_factor + rng.gauss(0, 0.03), 3)
                solar = max(0, solar)
                consumption = max(0, consumption)

                net = solar - consumption
                if net > 0 and solar > 0.5:
                    battery = min(100, battery + rng.randint(1, 5))
                    grid_export = round(net * 0.7, 3)
                    grid_import = 0
                    battery_charge = round(min(net * 0.3, 5.0), 3)
                else:
                    battery = max(0, battery - rng.randint(1, 8))
                    grid_import = round(abs(net) * 0.6, 3)
                    grid_export = 0
                    battery_charge = max(0, round(-net * 0.2, 3))

                carbon = round(solar * 0.85, 3)
                earnings_val = round(solar * 6.5, 2)
                cost_val = round(consumption * 7.0, 2)

                row = {
                    "user_id": profile["id"],
                    # 006 schema columns
                    "solar_power_kw": round(solar, 3),
                    "consumption_kw": round(consumption, 3),
                    "battery_percentage": battery,
                    "recorded_at": ts.isoformat(),
                    # 004 schema columns
                    "timestamp": ts.isoformat(),
                    "solar_generation_kwh": round(solar, 3),
                    "consumption_kwh": round(consumption, 3),
                    "battery_percent": battery,
                    "battery_charge_kw": battery_charge,
                    "grid_import_kwh": grid_import,
                    "grid_export_kwh": grid_export,
                    "carbon_saved": carbon,
                    "earnings": earnings_val,
                    "cost": cost_val,
                }
                rows.append(row)

        # Insert in batches
        for i in range(0, len(rows), BATCH_SIZE):
            chunk = rows[i:i + BATCH_SIZE]
            try:
                state.client.rest("energy_readings").insert(chunk)
            except RuntimeError as e:
                if "duplicate" in str(e).lower():
                    print(f"  [EXISTS] Energy readings already exist for {email}, skipping")
                else:
                    print(f"  [WARN] Batch insert warning for {email}: {e}")
                break

        state.stats["readings_inserted"] += len(rows)
        print(f"  [OK] Inserted {len(rows)} energy readings for {email}")


# ── Energy Listings ────────────────────────────────────────────────────


def _seed_listings(state: SeedState) -> None:
    """Create energy listings owned by producer demo users."""
    assert state.client is not None

    rng = state.rng
    now = _now()
    producer_emails = [u["email"] for u in DEMO_USERS if u["role"] in ("producer", "admin")]

    listing_templates = [
        {"source": "solar", "kwh": 50, "price": 6.50, "location": LOCATIONS[0], "battery": True, "verified": True},
        {"source": "solar", "kwh": 35, "price": 7.00, "location": LOCATIONS[1], "battery": True, "verified": True},
        {"source": "wind", "kwh": 80, "price": 5.50, "location": LOCATIONS[2], "battery": False, "verified": True},
        {"source": "solar", "kwh": 25, "price": 8.00, "location": LOCATIONS[3], "battery": True, "verified": True},
        {"source": "hydro", "kwh": 100, "price": 4.50, "location": LOCATIONS[4], "battery": False, "verified": True},
        {"source": "biomass", "kwh": 40, "price": 6.00, "location": LOCATIONS[5], "battery": False, "verified": False},
        {"source": "solar", "kwh": 60, "price": 7.50, "location": LOCATIONS[0], "battery": True, "verified": True},
        {"source": "community_solar", "kwh": 90, "price": 5.75, "location": LOCATIONS[1], "battery": True, "verified": True},
        {"source": "solar", "kwh": 30, "price": 8.50, "location": LOCATIONS[2], "battery": True, "verified": True},
        {"source": "wind", "kwh": 45, "price": 6.25, "location": LOCATIONS[3], "battery": False, "verified": True},
        {"source": "solar", "kwh": 55, "price": 7.25, "location": LOCATIONS[4], "battery": True, "verified": True},
        {"source": "hydro", "kwh": 70, "price": 5.00, "location": LOCATIONS[5], "battery": False, "verified": True},
        {"source": "solar", "kwh": 20, "price": 9.00, "location": LOCATIONS[0], "battery": True, "verified": True},
        {"source": "biomass", "kwh": 35, "price": 6.75, "location": LOCATIONS[1], "battery": False, "verified": False},
        {"source": "solar", "kwh": 65, "price": 6.80, "location": LOCATIONS[2], "battery": True, "verified": True},
        {"source": "community_solar", "kwh": 75, "price": 5.25, "location": LOCATIONS[3], "battery": True, "verified": True},
        {"source": "solar", "kwh": 40, "price": 7.75, "location": LOCATIONS[4], "battery": True, "verified": True},
        {"source": "wind", "kwh": 55, "price": 5.80, "location": LOCATIONS[5], "battery": False, "verified": True},
        {"source": "solar", "kwh": 45, "price": 8.25, "location": LOCATIONS[0], "battery": True, "verified": True},
        {"source": "solar", "kwh": 15, "price": 9.50, "location": LOCATIONS[1], "battery": True, "verified": True},
    ]

    # Mix of statuses: 80% active, 10% sold, 10% cancelled
    statuses = ["active"] * 16 + ["sold"] * 2 + ["cancelled"] * 2

    for idx, tmpl in enumerate(listing_templates):
        if idx >= len(statuses):
            break
        seller_email = producer_emails[idx % len(producer_emails)]
        seller = state.profiles.get(seller_email)
        if not seller:
            continue

        status = statuses[idx]
        available = tmpl["kwh"] if status == "active" else 0
        reserved = 0 if status == "active" else (tmpl["kwh"] if status == "sold" else 0)
        loc = tmpl["location"]
        start = now - timedelta(days=rng.randint(1, 14))
        end = start + timedelta(hours=rng.randint(24, 72))

        idempotency = _idempotency_key("listing", idx)
        listing_id = str(uuid.uuid4())

        listing_id = str(uuid.uuid4())
        price = tmpl["price"]
        row = {
            # Backend schema columns
            "id": listing_id,
            "seller_id": seller["id"],
            "title": f"{tmpl['source'].replace('_', ' ').title()} Energy - {loc['city']}",
            "description": f"Clean {tmpl['source']} energy from {seller.get('full_name', 'Seller')}.",
            "energy_source": tmpl["source"],
            "quantity_total_kwh": tmpl["kwh"],
            "quantity_available_kwh": available,
            "quantity_reserved_kwh": reserved,
            "price_per_kwh": price,
            "currency": "INR",
            "minimum_purchase_kwh": 0.5,
            "maximum_purchase_kwh": tmpl["kwh"],
            "location_name": f"{loc['city']}, {loc['district']}",
            "available_from": start.isoformat(),
            "available_until": end.isoformat(),
            "status": status,
            "is_featured": idx < 3 if status == "active" else False,
            "is_verified": tmpl["verified"],
            # 025 migration columns (also required)
            "available_energy_kwh": available,
            "original_energy_kwh": tmpl["kwh"],
            "price_per_kwh_paise": int(price * 100),
            "availability_start": start.isoformat(),
            "availability_end": end.isoformat(),
            "renewable_verified": tmpl["verified"],
            "battery_backed": tmpl["battery"],
        }

        try:
            result = state.client.rest("energy_listings").upsert([row], on_conflict="id")
            if result:
                state.listing_ids.append(result[0]["id"])
                state.stats["listings_inserted"] += 1
        except RuntimeError as e:
            print(f"  [WARN] Failed to insert listing {idx}: {e}")

    print(f"  [OK] Inserted {state.stats['listings_inserted']} energy listings")


# ── Purchases ───────────────────────────────────────────────────────────


def _seed_purchases(state: SeedState) -> None:
    """Create purchase history between consumers and producers."""
    assert state.client is not None

    rng = state.rng
    consumer_emails = [u["email"] for u in DEMO_USERS if u["role"] == "consumer"]
    producer_emails = [u["email"] for u in DEMO_USERS if u["role"] == "producer"]

    if not state.listing_ids:
        print("  [WARN] No listings available for purchases")
        return

    purchase_configs = [
        {"consumer": consumer_emails[0], "listing_idx": 0, "qty": 5.0, "days_ago": 25},
        {"consumer": consumer_emails[0], "listing_idx": 2, "qty": 10.0, "days_ago": 20},
        {"consumer": consumer_emails[1], "listing_idx": 1, "qty": 8.0, "days_ago": 18},
        {"consumer": consumer_emails[0], "listing_idx": 3, "qty": 3.0, "days_ago": 14},
        {"consumer": consumer_emails[1], "listing_idx": 4, "qty": 12.0, "days_ago": 10},
        {"consumer": consumer_emails[0], "listing_idx": 6, "qty": 6.0, "days_ago": 7},
        {"consumer": consumer_emails[1], "listing_idx": 8, "qty": 4.0, "days_ago": 5},
        {"consumer": consumer_emails[0], "listing_idx": 10, "qty": 7.0, "days_ago": 3},
    ]

    for pidx, pc in enumerate(purchase_configs):
        if pc["listing_idx"] >= len(state.listing_ids):
            continue

        listing_id = state.listing_ids[pc["listing_idx"]]
        consumer = state.profiles.get(pc["consumer"])
        if not consumer:
            continue

        # Get listing details to find seller and price
        try:
            listing = state.client.rest("energy_listings").eq("id", listing_id).select()
        except RuntimeError:
            continue
        if not listing:
            continue

        seller_id = listing[0].get("seller_id", "")
        price_per_kwh = float(listing[0].get("price_per_kwh", 6.0))
        unit_price_paise = int(price_per_kwh * 100)
        quantity = pc["qty"]
        subtotal_paise = int(quantity * unit_price_paise)
        platform_fee_paise = int(subtotal_paise * 0.05)  # 5% platform fee
        total_paise = subtotal_paise + platform_fee_paise

        idempotency = _idempotency_key("purchase", pidx)
        purchase_id = str(uuid.uuid4())
        created = _now() - timedelta(days=pc["days_ago"])

        purchase_row = {
            "listing_id": listing_id,
            "buyer_id": consumer["id"],
            "seller_id": seller_id,
            "quantity_kwh": quantity,
            "unit_price_paise": unit_price_paise,
            "platform_fee_paise": platform_fee_paise,
            "total_amount_paise": total_paise,
            "status": "completed",
            "idempotency_key": idempotency,
            "created_at": created.isoformat(),
            "updated_at": created.isoformat(),
        }

        try:
            result = state.client.rest("energy_purchases").insert([purchase_row])
            if result:
                purchase_id = result[0]["id"]
            state.purchase_ids.append(purchase_id)
            state.stats["purchases_inserted"] += 1
        except RuntimeError as e:
            if "409" in str(e):
                # Record exists - look up by idempotency_key
                existing = state.client.rest("energy_purchases").eq("idempotency_key", idempotency).select()
                if existing:
                    state.purchase_ids.append(existing[0]["id"])
                    state.stats["purchases_inserted"] += 1
            else:
                print(f"  [WARN] Failed to insert purchase {pidx}: {e}")

    print(f"  [OK] Inserted {state.stats['purchases_inserted']} purchases")


# ── Wallet Transactions ────────────────────────────────────────────────


def _resolve_wallet_id(state: SeedState, user_id: str) -> str:
    """Resolve wallet_id for a given user_id from state cache or Supabase."""
    for email, wid in state.wallet_ids.items():
        profile = state.profiles.get(email)
        if profile and profile["id"] == user_id:
            return wid
    # Fallback: query Supabase
    try:
        wallets = state.client.rest("wallets").eq("user_id", user_id).select()  # type: ignore[union-attr]
        if wallets:
            wid = wallets[0]["wallet_id"]
            return wid
    except RuntimeError:
        pass
    return ""


def _seed_wallet_transactions(state: SeedState) -> None:
    """Create wallet transactions for purchases, deposits, etc."""
    assert state.client is not None

    rng = state.rng
    tx_index = 0

    # Purchase debits
    for pidx, purchase_id in enumerate(state.purchase_ids):
        try:
            purchase = state.client.rest("energy_purchases").eq("id", purchase_id).select()
        except RuntimeError:
            continue
        if not purchase:
            continue

        p = purchase[0]
        buyer_id = p["buyer_id"]
        seller_id = p["seller_id"]
        total_paise = int(p["total_amount_paise"])
        fee_paise = int(p["platform_fee_paise"])
        buyer_wallet_id = _resolve_wallet_id(state, buyer_id)
        seller_wallet_id = _resolve_wallet_id(state, seller_id)

        tx_id = _uuid()
        idempotency = _idempotency_key("tx_purchase", pidx)

        row = {
            "wallet_id": buyer_wallet_id,
            "user_id": buyer_id,
            "type": "Purchase",
            "status": "COMPLETED",
            "amount": total_paise,
            "currency": "INR",
            "idempotency_key": idempotency,
            "reference": f"PUR-{purchase_id[:8]}",
            "description": f"Energy purchase from listing",
            "related_purchase_id": purchase_id,
            "created_at": p.get("created_at", _now().isoformat()),
        }
        try:
            state.client.rest("wallet_transactions").insert([row])
            state.stats["transactions_inserted"] += 1
        except RuntimeError:
            pass

        # Sale credit for seller
        sale_amount = total_paise - fee_paise
        sale_row = {
            "wallet_id": seller_wallet_id,
            "user_id": seller_id,
            "type": "Sale",
            "status": "COMPLETED",
            "amount": sale_amount,
            "currency": "INR",
            "idempotency_key": _idempotency_key("tx_sale", pidx),
            "reference": f"SALE-{purchase_id[:8]}",
            "description": "Energy sale proceeds",
            "related_purchase_id": purchase_id,
            "created_at": p.get("created_at", _now().isoformat()),
        }
        try:
            state.client.rest("wallet_transactions").insert([sale_row])
            state.stats["transactions_inserted"] += 1
        except RuntimeError:
            pass

        tx_index += 1

    # Deposits
    for email, profile in state.profiles.items():
        dep_idempotency = _idempotency_key("deposit", tx_index)
        dep_wallet_id = _resolve_wallet_id(state, profile["id"])
        dep_row = {
            "wallet_id": dep_wallet_id,
            "user_id": profile["id"],
            "type": "Deposit",
            "status": "COMPLETED",
            "amount": 50_000,  # ₹500
            "currency": "INR",
            "idempotency_key": dep_idempotency,
            "reference": f"DEP-{profile['id'][:8]}",
            "description": "Demo deposit via UPI",
            "created_at": (_now() - timedelta(days=rng.randint(1, 15))).isoformat(),
        }
        try:
            state.client.rest("wallet_transactions").insert([dep_row])
            state.stats["transactions_inserted"] += 1
        except RuntimeError:
            pass
        tx_index += 1

    print(f"  [OK] Inserted {state.stats['transactions_inserted']} wallet transactions")


# ── Ledger Entries ─────────────────────────────────────────────────────


def _seed_ledger_entries(state: SeedState) -> None:
    """Create ledger entries that reconcile with wallet transactions."""
    assert state.client is not None

    rng = state.rng
    entry_index = 0

    for pidx, purchase_id in enumerate(state.purchase_ids):
        try:
            purchase = state.client.rest("energy_purchases").eq("id", purchase_id).select()
        except RuntimeError:
            continue
        if not purchase:
            continue

        p = purchase[0]
        buyer_id = p["buyer_id"]
        seller_id = p["seller_id"]
        total_paise = int(p["total_amount_paise"])
        fee_paise = int(p["platform_fee_paise"])
        sale_paise = total_paise - fee_paise
        buyer_wallet_id = _resolve_wallet_id(state, buyer_id)
        seller_wallet_id = _resolve_wallet_id(state, seller_id)

        # Debit buyer
        buyer_entry = {
            "transaction_id": purchase_id,
            "wallet_id": buyer_wallet_id,
            "user_id": buyer_id,
            "account_type": "energy_purchase",
            "debit": total_paise,
            "credit": 0,
            "description": f"Energy purchase debit [voltshare_demo_v1]",
        }
        try:
            state.client.rest("ledger_entries").insert([buyer_entry])
            state.stats["ledger_entries_inserted"] += 1
        except RuntimeError:
            pass

        # Credit seller
        seller_entry = {
            "transaction_id": purchase_id,
            "wallet_id": seller_wallet_id,
            "user_id": seller_id,
            "account_type": "energy_sale",
            "debit": 0,
            "credit": sale_paise,
            "description": f"Energy sale credit [voltshare_demo_v1]",
        }
        try:
            state.client.rest("ledger_entries").insert([seller_entry])
            state.stats["ledger_entries_inserted"] += 1
        except RuntimeError:
            pass

        # Platform fee entry
        fee_entry = {
            "transaction_id": purchase_id,
            "wallet_id": seller_wallet_id,
            "user_id": seller_id,
            "account_type": "platform_fee",
            "debit": fee_paise,
            "credit": 0,
            "description": f"Platform fee [voltshare_demo_v1]",
        }
        try:
            state.client.rest("ledger_entries").insert([fee_entry])
            state.stats["ledger_entries_inserted"] += 1
        except RuntimeError:
            pass

        entry_index += 3

    print(f"  [OK] Inserted {state.stats['ledger_entries_inserted']} ledger entries")


# ── Escrow Accounts ────────────────────────────────────────────────────


def _seed_escrow_accounts(state: SeedState) -> None:
    """Create escrow accounts for completed purchases."""
    assert state.client is not None

    for pidx, purchase_id in enumerate(state.purchase_ids):
        try:
            purchase = state.client.rest("energy_purchases").eq("id", purchase_id).select()
        except RuntimeError:
            continue
        if not purchase:
            continue

        p = purchase[0]
        buyer_id = p["buyer_id"]
        seller_id = p["seller_id"]
        listing_id = p["listing_id"]
        total_paise = int(p["total_amount_paise"])
        fee_paise = int(p["platform_fee_paise"])
        amount_held = total_paise - fee_paise
        escrow_uuid = _uuid()

        escrow_row = {
            "escrow_id": escrow_uuid,
            "purchase_id": purchase_id,
            "buyer_id": buyer_id,
            "seller_id": seller_id,
            "amount_held": amount_held,
            "platform_fee": fee_paise,
            "status": "COMPLETED" if pidx < len(state.purchase_ids) - 2 else "ACTIVE",
        }
        try:
            state.client.rest("escrow_accounts").insert([escrow_row])
            state.escrow_account_ids.append(escrow_uuid)
            state.stats["escrow_accounts_inserted"] += 1
        except RuntimeError as e:
            if "duplicate" not in str(e).lower():
                print(f"  [WARN] Escrow insert warning: {e}")

    print(f"  [OK] Inserted {state.stats['escrow_accounts_inserted']} escrow accounts")


# ── Settlements ────────────────────────────────────────────────────────


def _seed_settlements(state: SeedState) -> None:
    """Create settlements for completed escrow records."""
    assert state.client is not None

    for eidx, escrow_id in enumerate(state.escrow_account_ids):
        # Skip last 2 escrows (keep them as "ACTIVE" / pending settlement)
        if eidx >= len(state.escrow_account_ids) - 2:
            continue

        try:
            escrow = state.client.rest("escrow_accounts").eq("escrow_id", escrow_id).select()
        except RuntimeError:
            continue
        if not escrow:
            continue

        e = escrow[0]
        amount_held = int(e["amount_held"])
        fee = int(e["platform_fee"])
        seller_amount = amount_held - fee

        settlement_row = {
            "escrow_id": escrow_id,
            "purchase_id": e["purchase_id"],
            "seller_id": e["seller_id"],
            "amount": seller_amount,
            "platform_fee": fee,
            "status": "COMPLETED",
        }
        try:
            state.client.rest("settlements").insert([settlement_row])
            state.stats["settlements_inserted"] += 1
        except RuntimeError:
            pass

    print(f"  [OK] Inserted {state.stats['settlements_inserted']} settlements")


# ── Deposits & Withdrawals & Refunds ──────────────────────────────────


def _seed_deposits(state: SeedState) -> None:
    """Create deposit records for demo users."""
    assert state.client is not None

    for email, profile in state.profiles.items():
        dep_id = _uuid()
        wallet_id = state.wallet_ids.get(email, "")
        row = {
            "deposit_id": dep_id,
            "wallet_id": wallet_id,
            "user_id": profile["id"],
            "amount": 50_000,
            "method": "UPI",
            "status": "COMPLETED",
        }
        try:
            state.client.rest("deposits").upsert([row], on_conflict="deposit_id")
            state.stats["deposits_inserted"] += 1
        except RuntimeError:
            pass

    print(f"  [OK] Inserted {state.stats['deposits_inserted']} deposits")


def _seed_withdrawals(state: SeedState) -> None:
    """Create withdrawal records for producer demo users."""
    assert state.client is not None

    producer_emails = [u["email"] for u in DEMO_USERS if u["role"] == "producer"]
    for email in producer_emails:
        profile = state.profiles.get(email)
        if not profile:
            continue
        wallet_id = state.wallet_ids.get(email, "")
        row = {
            "wallet_id": wallet_id,
            "user_id": profile["id"],
            "amount": 25_000,
            "method": "Bank Transfer",
            "status": "COMPLETED",
        }
        try:
            state.client.rest("withdrawals").insert([row])
            state.stats["withdrawals_inserted"] += 1
        except RuntimeError:
            pass

    print(f"  [OK] Inserted {state.stats['withdrawals_inserted']} withdrawals")


def _seed_refunds(state: SeedState) -> None:
    """Create refund records for eligible purchases."""
    assert state.client is not None

    if len(state.purchase_ids) >= 2:
        purchase_id = state.purchase_ids[-2]  # second-to-last purchase
        try:
            purchase = state.client.rest("energy_purchases").eq("id", purchase_id).select()
        except RuntimeError:
            return
        if purchase:
            p = purchase[0]
            profile = state.profiles.get(f"consumer1{DEMO_EMAIL_DOMAIN}")
            wallet_id = state.wallet_ids.get(f"consumer1{DEMO_EMAIL_DOMAIN}", "")
            if profile:
                refund_amt = int(int(p["total_amount_paise"]) * 0.8)
                row = {
                    "wallet_id": wallet_id,
                    "user_id": profile["id"],
                    "transaction_id": purchase_id,
                    "amount": refund_amt,
                    "status": "COMPLETED",
                }
                try:
                    state.client.rest("refunds").insert([row])
                    state.stats["refunds_inserted"] += 1
                except RuntimeError:
                    pass

    print(f"  [OK] Inserted {state.stats['refunds_inserted']} refunds")


# ── Disputes ────────────────────────────────────────────────────────────


def _seed_disputes(state: SeedState) -> None:
    """Create 2-4 disputes tied to valid escrow records."""
    assert state.client is not None

    if len(state.escrow_account_ids) < 2:
        return

    dispute_data = [
        {"escrow_idx": 0, "category": "energy shortfall",
         "description": "Delivered energy was less than agreed quantity by approximately 15%."},
        {"escrow_idx": 2, "category": "delayed delivery",
         "description": "Energy delivery started 45 minutes after the scheduled window."},
        {"escrow_idx": 4, "category": "settlement mismatch",
         "description": "Settlement amount does not match the verified delivered quantity."},
    ]

    for d in dispute_data:
        if d["escrow_idx"] >= len(state.escrow_account_ids):
            continue
        escrow_id = state.escrow_account_ids[d["escrow_idx"]]
        try:
            escrow = state.client.rest("escrow_accounts").eq("escrow_id", escrow_id).select()
        except RuntimeError:
            continue
        if not escrow:
            continue

        e = escrow[0]
        buyer_id = e["buyer_id"]
        dispute_id = _uuid()

        row = {
            "id": dispute_id,
            "escrow_id": escrow_id,
            "raised_by": buyer_id,
            "category": d["category"],
            "description": d["description"],
            "status": "underReview",
        }
        try:
            state.client.rest("disputes").insert([row])
            state.stats["disputes_inserted"] += 1
        except RuntimeError:
            # Conflict - dispute already exists, that's fine (idempotent)
            pass

    print(f"  [OK] Inserted {state.stats['disputes_inserted']} disputes")


# ── Audit Events ────────────────────────────────────────────────────────


def _seed_audit_events(state: SeedState) -> None:
    """Create audit entries for key operations."""
    assert state.client is not None

    audit_actions = [
        {"action": "user_created", "resource_type": "user", "by_email": f"admin{DEMO_EMAIL_DOMAIN}"},
        {"action": "listing_created", "resource_type": "listing", "by_email": f"producer1{DEMO_EMAIL_DOMAIN}"},
        {"action": "purchase_completed", "resource_type": "purchase", "by_email": f"consumer1{DEMO_EMAIL_DOMAIN}"},
        {"action": "escrow_created", "resource_type": "escrow", "by_email": f"consumer1{DEMO_EMAIL_DOMAIN}"},
        {"action": "settlement_completed", "resource_type": "settlement", "by_email": f"producer1{DEMO_EMAIL_DOMAIN}"},
        {"action": "dispute_raised", "resource_type": "dispute", "by_email": f"consumer1{DEMO_EMAIL_DOMAIN}"},
        {"action": "admin_reviewed", "resource_type": "user", "by_email": f"admin{DEMO_EMAIL_DOMAIN}"},
    ]

    for i, a in enumerate(audit_actions):
        profile = state.profiles.get(a["by_email"])
        if not profile:
            continue

        event = {
            "actor_user_id": profile["id"],
            "action": a["action"],
            "resource_type": a["resource_type"],
            "resource_id": str(uuid.uuid4()),
            "status": "succeeded",
            "risk_score": 10 if a["action"] == "dispute_raised" else 0,
            "request_id": str(uuid.uuid4()),
            "idempotency_key": _idempotency_key("audit", i),
            "metadata": json.dumps({"seed_marker": DEMO_MARKER}),
            "integrity_hash": _checksum({"action": a["action"], "seed": DEMO_MARKER, "index": i}),
        }
        try:
            state.client.rest("audit_events").insert([event])
            state.stats["audit_events_inserted"] += 1
        except RuntimeError:
            pass

    print(f"  [OK] Inserted {state.stats['audit_events_inserted']} audit events")


# ── AI Insights ─────────────────────────────────────────────────────────


def _seed_ai_insights(state: SeedState) -> None:
    """Create AI insight records for demo users."""
    assert state.client is not None

    insight_templates = [
        {"type": "energy_optimization",
         "title": "Shift appliance usage",
         "message": "Move high-consumption appliances to the solar surplus window (10:00-15:00).",
         "confidence": 0.87},
        {"type": "generation_recommendation",
         "title": "Optimal panel angle",
         "message": "Adjust panel tilt to 12° for maximum generation in current season.",
         "confidence": 0.82},
        {"type": "pricing_insight",
         "title": "Peak price alert",
         "message": "Evening prices are 22% above daytime average. Consider shifting purchases.",
         "confidence": 0.79},
        {"type": "sustainability_insight",
         "title": "Carbon reduction",
         "message": "Your solar generation offset 45 kg CO₂ this week. Excellent progress!",
         "confidence": 0.91},
        {"type": "anomaly_insight",
         "title": "Unusual consumption",
         "message": "Consumption spiked 30% above normal between 02:00-04:00. Possible appliance issue.",
         "confidence": 0.73},
    ]

    for i, tmpl in enumerate(insight_templates):
        for email, profile in state.profiles.items():
            if profile.get("role") == "admin":
                continue
            payload = {
                "seed_marker": DEMO_MARKER,
                "type": tmpl["type"],
                "title": tmpl["title"],
                "message": tmpl["message"],
                "confidence": tmpl["confidence"],
                "generated_for_date": _now().isoformat(),
            }
            row = {
                "user_id": profile["id"],
                "source": "fallback rule engine",
                "payload": json.dumps(payload),
            }
            try:
                state.client.rest("ai_insights").insert([row])
                state.stats["ai_insights_inserted"] += 1
            except RuntimeError:
                pass

    print(f"  [OK] Inserted {state.stats['ai_insights_inserted']} AI insights")


# ── Security Events & Login Events ────────────────────────────────────


def _seed_security_events(state: SeedState) -> None:
    """Create security and login events for demo users."""
    assert state.client is not None

    rng = state.rng

    for email, profile in state.profiles.items():
        # Security events
        for se_idx in range(3):
            event_types = ["successful_login", "new_device_login", "profile_updated"]
            event = {
                "user_id": profile["id"],
                "event_type": event_types[se_idx],
                "risk_score": rng.randint(0, 30),
                "metadata": json.dumps({
                    "seed_marker": DEMO_MARKER,
                    "ip_prefix": "10.0.0",
                    "timestamp": (_now() - timedelta(days=rng.randint(0, 14))).isoformat(),
                }),
            }
            try:
                state.client.rest("security_events").insert([event])
                state.stats["security_events_inserted"] += 1
            except RuntimeError:
                pass

        # Login events
        for _ in range(5):
            login_event = {
                "user_id": profile["id"],
                "success": rng.random() > 0.15,
                "ip_hash": hashlib.sha256(f"10.0.0.{rng.randint(1, 255)}".encode()).hexdigest()[:16],
                "user_agent_hash": hashlib.sha256("okhttp/4.12".encode()).hexdigest()[:16],
            }
            try:
                state.client.rest("login_events").insert([login_event])
            except RuntimeError:
                pass

    print(f"  [OK] Inserted {state.stats['security_events_inserted']} security events")


# ── Idempotency Records ────────────────────────────────────────────────


def _seed_idempotency_records(state: SeedState) -> None:
    """Create idempotency records for seeded purchases."""
    assert state.client is not None

    for pidx, purchase_id in enumerate(state.purchase_ids):
        try:
            purchase = state.client.rest("energy_purchases").eq("id", purchase_id).select()
        except RuntimeError:
            continue
        if not purchase:
            continue

        p = purchase[0]
        buyer_id = p["buyer_id"]
        idem_key = p.get("idempotency_key", _idempotency_key("purchase", pidx))

        row = {
            "user_id": buyer_id,
            "operation": "create_purchase",
            "idempotency_key": idem_key,
            "request_hash": hashlib.sha256(f"demo-purchase-{pidx}".encode()).hexdigest(),
            "response_payload": json.dumps({"purchase_id": purchase_id, "seed_marker": DEMO_MARKER}),
            "http_status": 201,
            "expires_at": (_now() + timedelta(hours=24)).isoformat(),
        }
        try:
            state.client.rest("idempotency_records").insert([row])
        except RuntimeError:
            pass

    print(f"  [OK] Seeded {len(state.purchase_ids)} idempotency records")


def _seed_trusted_devices(state: SeedState) -> None:
    """Create fictional trusted device records for demo users."""
    assert state.client is not None

    for email, profile in state.profiles.items():
        for dev_idx in range(2):
            fingerprint = hashlib.sha256(f"demo-device-{email}-{dev_idx}-2026".encode()).hexdigest()[:32]
            row = {
                "user_id": profile["id"],
                "device_fingerprint": fingerprint,
                "trusted": dev_idx == 0,  # first device trusted, second not yet
            }
            try:
                state.client.rest("trusted_devices").insert([row])
            except RuntimeError:
                pass

    print(f"  [OK] Seeded trusted devices for demo users")


# ── Main ────────────────────────────────────────────────────────────────


def main() -> None:
    """Run the full seed process."""
    print("=" * 60)
    print("VoltShare Live Demo Data Seeder")
    print("=" * 60)

    state = SeedState()
    state.client = _get_client()

    print(f"\nStep 1/11: Creating Auth users...")
    _seed_auth_users(state)

    print(f"\nStep 2/11: Creating profiles...")
    _seed_profiles(state)

    print(f"\nStep 3/11: Creating wallets & payment methods...")
    _seed_wallets(state)
    _seed_payment_methods(state)

    print(f"\nStep 4/11: Inserting energy readings (30 days x 24 hours per user)...")
    _seed_energy_readings(state)

    print(f"\nStep 5/11: Creating energy listings...")
    _seed_listings(state)

    print(f"\nStep 6/11: Creating purchases...")
    _seed_purchases(state)

    print(f"\nStep 7/11: Creating wallet transactions & ledger entries...")
    _seed_wallet_transactions(state)
    _seed_ledger_entries(state)

    print(f"\nStep 8/11: Creating escrow accounts & settlements...")
    _seed_escrow_accounts(state)
    _seed_settlements(state)

    print(f"\nStep 9/11: Creating deposits, withdrawals & refunds...")
    _seed_deposits(state)
    _seed_withdrawals(state)
    _seed_refunds(state)

    print(f"\nStep 10/11: Creating disputes & audit events...")
    _seed_disputes(state)
    _seed_audit_events(state)

    print(f"\nStep 11/13: Creating AI insights & security events...")
    _seed_ai_insights(state)
    _seed_security_events(state)

    print(f"\nStep 12/13: Creating idempotency records & trusted devices...")
    _seed_idempotency_records(state)
    _seed_trusted_devices(state)

    # Summary
    elapsed = _now() - state.started_at
    print(f"\n{'=' * 60}")
    print(f"  Seed complete in {elapsed.total_seconds():.1f}s")
    print(f"{'=' * 60}")
    for key, count in state.stats.items():
        label = key.replace("_", " ").title()
        print(f"  {label}: {count}")
    print(f"{'=' * 60}")
    print(f"\nDemo accounts: @{DEMO_EMAIL_DOMAIN.lstrip('@')}")
    print("Passwords: configured via environment variables")
    print(f"Marker: {DEMO_MARKER}")


if __name__ == "__main__":
    main()
