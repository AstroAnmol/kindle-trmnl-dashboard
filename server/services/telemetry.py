import json
import os
from datetime import datetime
from typing import Dict, Any, Optional
from server.config import settings

class TelemetryService:
    def __init__(self, file_path: str = settings.device_status_file_path):
        self.file_path = file_path
        self._data: Dict[str, Any] = self._load()

    def _load(self) -> Dict[str, Any]:
        if os.path.exists(self.file_path):
            try:
                with open(self.file_path, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
        return {
            "device_id": "kindle-display",
            "battery_percent": 100,
            "battery_voltage": 4.10,
            "signal_strength": -60,
            "firmware_version": "unknown",
            "last_seen": datetime.now().isoformat()
        }

    def _save(self) -> None:
        try:
            os.makedirs(os.path.dirname(self.file_path), exist_ok=True)
            with open(self.file_path, "w", encoding="utf-8") as f:
                json.dump(self._data, f, indent=2)
        except Exception as e:
            print(f"[TelemetryService] Failed to save telemetry: {e}")

    def update(self, update_data: Dict[str, Any]) -> Dict[str, Any]:
        for k, v in update_data.items():
            if v is not None:
                self._data[k] = v
        self._data["last_seen"] = datetime.now().isoformat()
        self._save()
        return self.get_data()

    def get_data(self) -> Dict[str, Any]:
        data = dict(self._data)
        batt = data.get("battery_percent", 100)
        rssi = data.get("signal_strength", -60)
        
        # Determine battery icon
        if batt is None:
            data["battery_icon"] = "battery-unknown"
        elif batt >= 85:
            data["battery_icon"] = "battery-full"
        elif batt >= 60:
            data["battery_icon"] = "battery-three-quarters"
        elif batt >= 35:
            data["battery_icon"] = "battery-half"
        elif batt >= 15:
            data["battery_icon"] = "battery-quarter"
        else:
            data["battery_icon"] = "battery-empty"

        # Determine Wi-Fi signal bars (0 to 4)
        if rssi is None or rssi == 0:
            data["wifi_bars"] = 0
        elif rssi >= -55:
            data["wifi_bars"] = 4
        elif rssi >= -67:
            data["wifi_bars"] = 3
        elif rssi >= -78:
            data["wifi_bars"] = 2
        elif rssi >= -88:
            data["wifi_bars"] = 1
        else:
            data["wifi_bars"] = 0

        return data

telemetry_service = TelemetryService()