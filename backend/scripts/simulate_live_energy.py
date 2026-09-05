"""Live energy simulator — inserts one realistic reading per interval.

Usage:
    python scripts/simulate_live_energy.py --email producer1@voltshare-demo.local --interval 15

Arguments:
    --email       Demo user email (default: producer1@voltshare-demo.local)
    --interval    Seconds between readings (default: 15)
    --seed        Fixed random seed for reproducibility (default: 42)

The script inserts readings into the Supabase `energy_readings` table using the
service-role key.  Press Ctrl+C to stop gracefully.
"""

from __future__ import annotations

import json
import os
import random
import signal
import sys
import time
import uuid
from argparse import ArgumentParser
from datetime import datetime, timezone
from typing import Any

import urllib.request
import urllib.error

DEMO_EMAIL_DOMAIN = "@voltshare-demo.local"

_SOLAR_CURVE = [
    0.00, 0.00, 0.00, 0.00, 0.00, 0.02,
    0.10, 0.30, 0.55, 0.75, 0.88, 0.95,
    1.00, 0.95, 0.85, 0.70, 0.50, 0.25,
    0.08, 0.02, 0.00, 0.00, 0.00, 0.00,
]

_CONSUMPTION_CURVE = [
    0.35, 0.30, 0.25, 0.25, 0.30, 0.40,
    0.60, 0.80, 0.70, 0.55, 0.50, 0.45,
    0.40, 0.35, 0.35, 0.40, 0.50, 0.70,
    0.90, 1.00, 0.85, 0.65, 0.50, 0.40,
]

_running = True


def _signal_handler(sig: int, _frame: Any) -> None:
    global _running
    print("\nShutting down gracefully...")
    _running = False


class SupabaseClient:
    def __init__(self, url: str, key: str) -> None:
        self._url = url.rstrip("/")
        self._headers = {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Prefer": "return=representation",
        }

    def insert(self, table: str, row: dict[str, Any]) -> None:
        data = json.dumps([row]).encode("utf-8")
        req = urllib.request.Request(f"{self._url}/rest/v1/{table}", data=data,
                                     method="POST", headers=self._headers)
        with urllib.request.urlopen(req, timeout=15):
            pass

    def select(self, table: str, column: str, value: str) -> list[dict[str, Any]]:
        encoded = urllib.request.quote(value, safe="")
        headers = {**self._headers, "Accept": "application/json"}
        url = f"{self._url}/rest/v1/{table}?{column}=eq.{encoded}&select=id"
        req = urllib.request.Request(url, method="GET", headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                body = resp.read().decode("utf-8")
                if body.strip():
                    return json.loads(body)
                return []
        except urllib.error.HTTPError as e:
            error_body = e.read().decode("utf-8", errors="replace")
            print(f"Supabase select error {e.code}: {error_body}", file=sys.stderr)
            return []


def generate_reading(rng: random.Random, user_id: str, now: datetime) -> dict[str, Any]:
    """Generate one realistic energy reading at the given time."""
    hour = now.hour
    solar_factor = _SOLAR_CURVE[hour]
    cons_factor = _CONSUMPTION_CURVE[hour]
    weather = 0.8 + rng.random() * 0.4  # 0.8-1.2

    solar = max(0, round(3.0 * solar_factor * weather + rng.gauss(0, 0.05), 3))
    consumption = max(0, round(1.0 * cons_factor + rng.gauss(0, 0.03), 3))
    battery = rng.randint(30, 85)

    net = solar - consumption
    if net > 0 and solar > 0.5:
        battery = min(100, battery + rng.randint(1, 4))
        grid_export = round(net * 0.7, 3)
        grid_import = 0
        battery_charge = round(min(net * 0.3, 5.0), 3)
    else:
        battery = max(0, battery - rng.randint(1, 6))
        grid_import = round(abs(net) * 0.6, 3)
        grid_export = 0
        battery_charge = max(0, round(-net * 0.2, 3))

    carbon = round(solar * 0.85, 3)
    earnings_val = round(solar * 6.5, 2)
    cost_val = round(consumption * 7.0, 2)
    ts = now.isoformat()

    return {
        "user_id": user_id,
        # 006 columns
        "solar_power_kw": round(solar, 3),
        "consumption_kw": round(consumption, 3),
        "battery_percentage": battery,
        "recorded_at": ts,
        # 004 columns
        "timestamp": ts,
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


def main() -> None:
    parser = ArgumentParser(description="VoltShare live energy simulator")
    parser.add_argument("--email", default=f"producer1{DEMO_EMAIL_DOMAIN}",
                        help="Demo user email")
    parser.add_argument("--interval", type=int, default=15,
                        help="Seconds between readings (default: 15)")
    parser.add_argument("--seed", type=int, default=42,
                        help="Random seed (default: 42)")
    args = parser.parse_args()

    if not args.email.endswith(DEMO_EMAIL_DOMAIN):
        print(f"ERROR: Email must end with {DEMO_EMAIL_DOMAIN}")
        sys.exit(1)

    url = os.environ.get("SUPABASE_URL", "")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        print("ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set.")
        sys.exit(1)

    client = SupabaseClient(url, key)
    rng = random.Random(args.seed)

    # Resolve user_id (the column in profiles table is 'id', not 'user_id')
    profiles = client.select("profiles", "email", args.email)
    if not profiles:
        print(f"ERROR: User {args.email} not found. Run seed_live_demo_data.py first.")
        sys.exit(1)
    # The select() method requests 'id,user_id' columns but the profile
    # table has 'id' as the primary key.  The response field is 'id'.
    user_id = profiles[0].get("id") or profiles[0].get("user_id", "")

    signal.signal(signal.SIGINT, _signal_handler)
    signal.signal(signal.SIGTERM, _signal_handler)

    count = 0
    print(f"Starting simulator for {args.email} (id={user_id[:8]}...)")
    print(f"Interval: {args.interval}s | Seed: {args.seed}")
    print("Press Ctrl+C to stop.\n")

    while _running:
        now = datetime.now(timezone.utc)
        reading = generate_reading(rng, user_id, now)

        try:
            client.insert("energy_readings", reading)
            count += 1
            print(f"  [{now.strftime('%H:%M:%S')}] Reading #{count} inserted: "
                  f"solar={reading['solar_generation_kwh']:.2f}kW, "
                  f"cons={reading['consumption_kwh']:.2f}kW, "
                  f"battery={reading['battery_percent']}%", flush=True)
        except Exception as e:
            print(f"  [{now.strftime('%H:%M:%S')}] Insert failed: {e}", flush=True)

        # Wait for interval (checking _running periodically)
        for _ in range(args.interval):
            if not _running:
                break
            time.sleep(1)

    print(f"\nSimulator stopped. {count} readings inserted.")

if __name__ == "__main__":
    main()
