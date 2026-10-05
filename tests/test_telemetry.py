import pytest
from server.services.telemetry import TelemetryService

def test_telemetry_service(tmp_path):
    fpath = tmp_path / "test_status.json"
    service = TelemetryService(file_path=str(fpath))
    
    # Test update and derived properties
    updated = service.update({"battery_percent": 90, "signal_strength": -50})
    assert updated["battery_percent"] == 90
    assert updated["battery_icon"] == "battery-full"
    assert updated["wifi_bars"] == 4

    # Low battery test
    updated_low = service.update({"battery_percent": 12, "signal_strength": -85})
    assert updated_low["battery_icon"] == "battery-empty"
    assert updated_low["wifi_bars"] == 1