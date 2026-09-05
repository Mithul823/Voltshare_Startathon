#!/usr/bin/env python3
"""Energy readings simulator for VoltShare.

Generates realistic 30-second energy readings and posts them to the FastAPI
backend.  Designed for live-demo environments where a running backend and
Supabase project are available.

Usage:
    python scripts/simulate_energy_readings.py \\
        --user-id <uuid> \\
        --api-base http://localhost:8000/api/v1 \\
        --access-token <supabase-access-token> \\
        --interval 30

Requirements:
    pip install httpx

Press Ctrl+C to stop gracefully.
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import signal
import sys
from datetime import datetime, timezone
from math import exp, sin, pi
from random import Random, random

import httpx

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("simulator")

# Realistic simulation parameters
_SOLAR_PEAK_HOUR = 12.5  # solar peak around 12:30 PM
_SOLAR_SPREAD = 18       # hours
_SOLAR_AMPLITUDE = 3.5   # peak kW
_BASE_LOAD = 0.6         # minimum kW consumption
_BATTERY_CAPACITY_KWH = 10
_EXPORT_PRICE_RS = 8.0
_GRID_PRICE_RS = 10.25
_CARBON_FACTOR = 0.7


def _solar_power(hour: float, random_jitter: float) -> float:
    """Solar generation curve based on hour of day."""
    if hour < 6 or hour > 18:
        return 0.0
    curve = exp(-((hour - _SOLAR_PEAK_HOUR) ** 2) / _SOLAR_SPREAD) * _SOLAR_AMPLITUDE
    return max(0.0, curve + random_jitter)


def _consumption_power(hour: float, random_jitter: float) -> float:
    """Electricity consumption curve with morning/evening peaks."""
    morning_peak = 0.6 * exp(-((hour - 8) ** 2) / 6)
    evening_peak = 1.2 * exp(-((hour - 19.5) ** 2) / 8)
    night_base = _BASE_LOAD + (0.3 if hour < 6 or hour > 23 else 0)
    return max(_BASE_LOAD, night_base + morning_peak + evening_peak + random_jitter)


class Simulator:
    """Energy readings simulator engine."""

    def __init__(self, user_id: str, api_base: str, access_token: str, interval_seconds: int = 30, seed: int = 42):
        self.user_id = user_id
        self.api_url = f"{api_base.rstrip('/')}/dashboard/simulate"
        self.headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }
        self.interval = interval_seconds
        self._rng = Random(seed)
        self._battery_percent = 50
        self._running = True
        self._client = httpx.AsyncClient(timeout=10.0)

    async def run(self) -> None:
        """Run the simulator loop until interrupted."""
        logger.info("Starting energy simulator for user %s → %s every %ds",
                     self.user_id[:8], self.api_url, self.interval)
        logger.info("Press Ctrl+C to stop")

        # Register signal handler for graceful shutdown
        loop = asyncio.get_running_loop()
        for sig in (signal.SIGINT, signal.SIGTERM):
            try:
                loop.add_signal_handler(sig, self._shutdown)
            except NotImplementedError:
                # Windows does not support add_signal_handler
                pass

        while self._running:
            reading = self._generate_reading()
            try:
                response = await self._client.post(self.api_url, json=reading, headers=self.headers)
                if response.is_success:
                    logger.info("✓ %.3f kW gen | %.3f kW con | %d%% bat | → posted",
                                reading["solar_power_kw"], reading["consumption_kw"], reading["battery_percentage"])
                elif response.status_code == 401:
                    logger.warning("✗ Authentication failed — token may be expired")
                else:
                    logger.warning("✗ HTTP %d: %s", response.status_code, response.text[:120])
            except httpx.RequestError as exc:
                logger.warning("✗ Connection error: %s", exc)

            await asyncio.sleep(self.interval)

        # Clean shutdown
        await self._client.aclose()
        logger.info("Simulator stopped")

    def _generate_reading(self) -> dict:
        """Generate one realistic energy reading."""
        now = datetime.now(timezone.utc)
        hour = now.hour + now.minute / 60

        solar_jitter = (self._rng.random() * 2 - 1) * 0.15
        consumption_jitter = (self._rng.random() * 2 - 1) * 0.12

        solar_power = _solar_power(hour, solar_jitter)
        consumption_power = _consumption_power(hour, consumption_jitter)

        # Battery dynamics
        surplus = solar_power - consumption_power
        battery_delta = 0
        if surplus > 0.1:
            # Charging
            self._battery_percent = min(100, self._battery_percent + 0.5)
            battery_delta = surplus * 0.6  # 60% goes to battery
        elif surplus < -0.1:
            # Discharging
            self._battery_percent = max(10, self._battery_percent - 0.3)
            battery_delta = surplus * 0.4  # 40% drawn from battery

        return {
            "solar_power_kw": round(solar_power, 3),
            "consumption_kw": round(consumption_power, 3),
            "battery_percentage": int(self._battery_percent),
            "timestamp": now.isoformat(),
        }

    def _shutdown(self) -> None:
        """Handle shutdown signal."""
        self._running = False


async def main() -> None:
    parser = argparse.ArgumentParser(description="VoltShare energy simulator")
    parser.add_argument("--user-id", required=True, help="Supabase user UUID")
    parser.add_argument("--api-base", default="http://localhost:8000/api/v1",
                        help="FastAPI base URL (default: http://localhost:8000/api/v1)")
    parser.add_argument("--access-token", required=True, help="Supabase access token")
    parser.add_argument("--interval", type=int, default=30,
                        help="Seconds between readings (default: 30)")
    args = parser.parse_args()

    simulator = Simulator(
        user_id=args.user_id,
        api_base=args.api_base,
        access_token=args.access_token,
        interval_seconds=args.interval,
    )
    try:
        await simulator.run()
    except asyncio.CancelledError:
        pass


if __name__ == "__main__":
    asyncio.run(main())
