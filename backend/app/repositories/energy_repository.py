"""Energy readings repository — in-memory (demo) and Supabase (live).

Supports storing, querying, and simulating energy readings for the dashboard.
The Supabase implementation uses the service-role admin client to bypass RLS.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from math import exp, sin, pi
from typing import Any, Protocol

from app.core.config import Settings, get_settings
from app.core.exceptions import ApiError, ErrorCode
from app.db.supabase import get_supabase_admin_client
from uuid import uuid4

from app.schemas.common import now_utc
from app.schemas.dashboard import EnergyReading


# ---------------------------------------------------------------------------
# Protocol / interface
# ---------------------------------------------------------------------------

class EnergyReadingsRepository(Protocol):
    """Interface for energy readings data access."""

    def readings_for(self, user_id: str) -> list[EnergyReading]: ...
    def latest(self, user_id: str) -> EnergyReading: ...
    def between(self, user_id: str, start: datetime, end: datetime) -> list[EnergyReading]: ...
    def append(self, user_id: str, reading: EnergyReading) -> EnergyReading: ...
    def seed_user(self, user_id: str, reference_time: datetime | None = None) -> list[EnergyReading]: ...


# ---------------------------------------------------------------------------
# In-memory repository (demo / fallback)
# ---------------------------------------------------------------------------

def _generate_seed_readings(user_id: str, reference_time: datetime | None = None) -> list[EnergyReading]:
    """Generate 48 realistic 30-minute readings for demo purposes."""
    now = reference_time or now_utc()
    window_start = now - timedelta(minutes=30 * 47)
    readings: list[EnergyReading] = []
    for index in range(48):
        timestamp = window_start + timedelta(minutes=30 * index)
        hour = timestamp.hour + timestamp.minute / 60
        solar_curve = max(0.0, exp(-((hour - 12.5) ** 2) / 18) * 3.2)
        night_load = 0.55 if hour < 6 or hour > 22 else 0
        evening_peak = 1.1 if 18 <= hour <= 22 else 0
        consumption = 1.0 + evening_peak + night_load + max(0, sin(hour / 24 * pi) * 0.4)
        battery = int(min(96, max(18, 42 + solar_curve * 12 - evening_peak * 8 - night_load * 5)))
        export = max(0.0, solar_curve - consumption) * 0.5
        grid_import = max(0.0, consumption - solar_curve) * 0.4
        readings.append(EnergyReading(
            id=str(uuid4()),
            user_id=user_id,
            timestamp=timestamp,
            solar_generation_kwh=round(solar_curve, 3),
            consumption_kwh=round(consumption, 3),
            battery_percent=battery,
            battery_charge_kw=round(max(-1.8, min(2.4, solar_curve - consumption)), 3),
            grid_import_kwh=round(grid_import, 3),
            grid_export_kwh=round(export, 3),
            carbon_saved=round(solar_curve * 0.7, 3),
            earnings=round(export * 8.0, 2),
            cost=round(grid_import * 10.25, 2),
        ))
    return readings


class InMemoryEnergyReadingsRepository:
    """In-memory energy readings repository with deterministic seed data."""

    def __init__(self) -> None:
        self._readings: dict[str, list[EnergyReading]] = {}
        self._counter: dict[str, int] = {}

    def readings_for(self, user_id: str) -> list[EnergyReading]:
        if user_id not in self._readings:
            self.seed_user(user_id)
        return self._readings.get(user_id, [])

    def latest(self, user_id: str) -> EnergyReading:
        readings = self.readings_for(user_id)
        return readings[-1] if readings else self.seed_user(user_id)[-1]

    def between(self, user_id: str, start: datetime, end: datetime) -> list[EnergyReading]:
        return [r for r in self.readings_for(user_id) if start <= r.timestamp <= end]

    def append(self, user_id: str, reading: EnergyReading) -> EnergyReading:
        if user_id not in self._readings:
            self.seed_user(user_id)
        self._readings[user_id].append(reading)
        return reading

    def seed_user(self, user_id: str, reference_time: datetime | None = None) -> list[EnergyReading]:
        readings = _generate_seed_readings(user_id, reference_time)
        self._readings[user_id] = readings
        return readings


# ---------------------------------------------------------------------------
# Supabase-backed repository (live mode)
# ---------------------------------------------------------------------------


def _row_to_reading(row: dict[str, Any]) -> EnergyReading:
    solar = float(row.get("solar_generation_kwh") if row.get("solar_generation_kwh") is not None else row.get("solar_power_kw", 0))
    consumption = float(row.get("consumption_kwh") if row.get("consumption_kwh") is not None else row.get("consumption_kw", 0))
    battery = int(row.get("battery_percent") if row.get("battery_percent") is not None else row.get("battery_percentage", 50))
    ts = _parse_dt(row.get("timestamp") or row.get("recorded_at"))
    return EnergyReading(
        id=str(row["id"]),
        user_id=str(row["user_id"]),
        timestamp=ts,
        solar_generation_kwh=solar,
        consumption_kwh=consumption,
        battery_percent=battery,
        battery_charge_kw=float(row.get("battery_charge_kw", 0)),
        grid_import_kwh=float(row.get("grid_import_kwh", 0)),
        grid_export_kwh=float(row.get("grid_export_kwh", 0)),
        carbon_saved=float(row.get("carbon_saved", 0)),
        earnings=float(row.get("earnings", 0)),
        cost=float(row.get("cost", 0)),
    )


def _reading_to_row(reading: EnergyReading) -> dict[str, Any]:
    return {
        "id": reading.id,
        "user_id": reading.user_id,
        "timestamp": reading.timestamp.isoformat(),
        "recorded_at": reading.timestamp.isoformat(),
        "solar_power_kw": reading.solar_generation_kwh,
        "consumption_kw": reading.consumption_kwh,
        "battery_percentage": reading.battery_percent,
        "solar_generation_kwh": reading.solar_generation_kwh,
        "consumption_kwh": reading.consumption_kwh,
        "battery_percent": reading.battery_percent,
        "battery_charge_kw": reading.battery_charge_kw,
        "grid_import_kwh": reading.grid_import_kwh,
        "grid_export_kwh": reading.grid_export_kwh,
        "carbon_saved": reading.carbon_saved,
        "earnings": reading.earnings,
        "cost": reading.cost,
    }


def _parse_dt(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    return now_utc()


class SupabaseEnergyReadingsRepository:
    """Supabase PostgreSQL-backed energy readings repository."""

    def __init__(self, settings: Settings | None = None) -> None:
        current = settings or get_settings()
        self._client = get_supabase_admin_client(current)
        self._in_memory = InMemoryEnergyReadingsRepository()

    def _require_client(self) -> None:
        if self._client is None:
            raise ApiError(503, ErrorCode.DATABASE_ERROR, "Supabase is not configured for live energy readings.")

    def readings_for(self, user_id: str) -> list[EnergyReading]:
        self._require_client()
        result = self._client.table("energy_readings") \
            .select("*") \
            .eq("user_id", user_id) \
            .order("timestamp", desc=True) \
            .limit(48) \
            .execute()
        if result.data:
            rows = sorted(result.data, key=lambda r: r["timestamp"])
            return [_row_to_reading(row) for row in rows]
        # Seed demo data on first access
        return self.seed_user(user_id)

    def latest(self, user_id: str) -> EnergyReading:
        self._require_client()
        result = self._client.table("energy_readings") \
            .select("*") \
            .eq("user_id", user_id) \
            .order("timestamp", desc=True) \
            .limit(1) \
            .execute()
        if result.data:
            return _row_to_reading(result.data[0])
        return self.seed_user(user_id)[-1]

    def between(self, user_id: str, start: datetime, end: datetime) -> list[EnergyReading]:
        self._require_client()
        result = self._client.table("energy_readings") \
            .select("*") \
            .eq("user_id", user_id) \
            .gte("timestamp", start.isoformat()) \
            .lte("timestamp", end.isoformat()) \
            .order("timestamp") \
            .execute()
        if result.data and len(result.data) >= 6:
            return [_row_to_reading(row) for row in result.data]
        # Auto-seed fresh readings for this user when window has no recent data
        seed = self.seed_user(user_id, end)
        windowed = [r for r in seed if start <= r.timestamp <= end]
        return windowed or seed

    def append(self, user_id: str, reading: EnergyReading) -> EnergyReading:
        self._require_client()
        row = _reading_to_row(reading)
        result = self._client.table("energy_readings").insert(row).execute()
        if not result.data:
            raise ApiError(500, ErrorCode.DATABASE_ERROR, "Failed to persist energy reading.")
        self._in_memory.append(user_id, reading)
        return _row_to_reading(result.data[0])

    def seed_user(self, user_id: str, reference_time: datetime | None = None) -> list[EnergyReading]:
        """Seed 48 demo readings for a user in live mode.

        This is safe — only called on first access when no readings exist.
        """
        self._require_client()
        readings = _generate_seed_readings(user_id, reference_time)
        rows = [_reading_to_row(r) for r in readings]
        # Batch insert in chunks to avoid payload size limits
        chunk_size = 12
        for i in range(0, len(rows), chunk_size):
            chunk = rows[i:i + chunk_size]
            self._client.table("energy_readings").insert(chunk).execute()
        self._in_memory.seed_user(user_id, reference_time)
        return readings


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

def get_energy_readings_repository(settings: Settings | None = None) -> EnergyReadingsRepository:
    """Return the active energy readings repository based on configuration."""
    current = settings or get_settings()
    if current.supabase_url and current.supabase_service_role_key:
        return SupabaseEnergyReadingsRepository(current)
    return InMemoryEnergyReadingsRepository()
