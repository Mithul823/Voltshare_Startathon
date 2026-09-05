#!/usr/bin/env python3
"""Seed historical energy readings for a VoltShare user.

Generates 90 days of 30-minute interval readings and posts them to the
FastAPI backend.  Useful for populating a new Supabase project with
dashboard history.

Usage:
    python scripts/seed_energy_history.py \\
        --user-id <uuid> \\
        --api-base http://localhost:8000/api/v1 \\
        --access-token <supabase-access-token>

Requirements:
    pip install httpx
"""

from __future__ import annotations

import argparse
import logging
import random
import sys
from datetime import datetime, timedelta, timezone
from math import exp, pi, sin

import httpx

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("seed")

_SOLAR_PEAK_HOUR = 12.5
_SOLAR_SPREAD = 18
_SOLAR_AMPLITUDE = 3.5
_BASE_LOAD = 0.6
_CARBON_FACTOR = 0.7


def _generate_reading(hour: float, day_variance: float = 0) -> dict:
    solar = max(0.0, exp(-((hour - _SOLAR_PEAK_HOUR) ** 2) / _SOLAR_SPREAD) * _SOLAR_AMPLITUDE * (1 + day_variance))
    morning_peak = 0.6 * exp(-((hour - 8) ** 2) / 6)
    evening_peak = 1.2 * exp(-((hour - 19.5) ** 2) / 8)
    night_base = _BASE_LOAD + (0.3 if hour < 6 or hour > 23 else 0)
    consumption = max(_BASE_LOAD, night_base + morning_peak + evening_peak)
    # Add small noise
    solar += (random.random() - 0.5) * 0.15
    consumption += (random.random() - 0.5) * 0.12
    solar = max(0, solar)
    consumption = max(_BASE_LOAD, consumption)
    battery = int(min(96, max(18, 42 + solar * 12 - consumption * 8)))
    return {
        "solar_power_kw": round(solar, 3),
        "consumption_kw": round(consumption, 3),
        "battery_percentage": battery,
    }


async def seed(api_base: str, access_token: str, user_id: str, days: int = 90) -> None:
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }
    api_url = f"{api_base.rstrip('/')}/dashboard/simulate"
    now = datetime.now(timezone.utc)
    total = days * 48
    count = 0
    errors = 0

    async with httpx.AsyncClient(timeout=10.0) as client:
        for day_offset in range(days):
            day_variance = (day_offset % 7 - 3) * 0.05  # weekly weather pattern
            for slot in range(48):
                timestamp = now - timedelta(days=days - day_offset, minutes=30 * (48 - slot))
                hour = timestamp.hour + timestamp.minute / 60
                reading = _generate_reading(hour, day_variance)
                reading["timestamp"] = timestamp.isoformat()

                try:
                    response = await client.post(api_url, json=reading, headers=headers)
                    if response.is_success:
                        count += 1
                    else:
                        errors += 1
                        if errors <= 5:
                            logger.warning("HTTP %d: %s", response.status_code, response.text[:80])
                except httpx.RequestError as exc:
                    errors += 1
                    if errors <= 3:
                        logger.warning("Connection error: %s", exc)

                if count % 240 == 0 and count > 0:
                    logger.info("Seeded %d / %d readings...", count, total)

    logger.info("Done: %d succeeded, %d failed out of %d", count, errors, total)


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed historical energy readings")
    parser.add_argument("--user-id", required=True, help="Supabase user UUID")
    parser.add_argument("--api-base", default="http://localhost:8000/api/v1")
    parser.add_argument("--access-token", required=True, help="Supabase access token")
    parser.add_argument("--days", type=int, default=90, help="Days of history (default: 90)")
    args = parser.parse_args()

    import asyncio
    asyncio.run(seed(args.api_base, args.access_token, args.user_id, args.days))


if __name__ == "__main__":
    main()
