from datetime import datetime

from app.schemas.dashboard import BatteryPoint, EnergyPoint, EnergyReading


class EnergyMonitoringService:
    def energy_points(self, readings: list[EnergyReading]) -> list[EnergyPoint]:
        return [EnergyPoint(time=reading.timestamp, value=reading.solar_generation_kwh) for reading in readings]

    def consumption_points(self, readings: list[EnergyReading]) -> list[EnergyPoint]:
        return [EnergyPoint(time=reading.timestamp, value=reading.consumption_kwh) for reading in readings]

    def battery_points(self, readings: list[EnergyReading]) -> list[BatteryPoint]:
        return [
            BatteryPoint(
                time=reading.timestamp,
                battery_percent=reading.battery_percent,
                battery_charge_kw=reading.battery_charge_kw,
            )
            for reading in readings
        ]

    def filter_by_window(self, readings: list[EnergyReading], start: datetime, end: datetime) -> list[EnergyReading]:
        return [reading for reading in readings if start <= reading.timestamp <= end]


energy_monitoring_service = EnergyMonitoringService()
