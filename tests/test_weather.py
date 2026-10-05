import pytest
from server.services.weather import WMO_WEATHER_MAP, fetch_weather

def test_wmo_map_coverage():
    # Verify core weather codes
    assert WMO_WEATHER_MAP[0]["icon"] == "sun"
    assert WMO_WEATHER_MAP[3]["condition"] == "Overcast"
    assert WMO_WEATHER_MAP[61]["icon"] == "rain"
    assert WMO_WEATHER_MAP[95]["condition"] == "Thunderstorm"

@pytest.mark.asyncio
async def test_fetch_weather_structure():
    data = await fetch_weather()
    assert "temperature" in data
    assert "condition" in data
    assert "icon" in data
    assert "temp_max" in data
    assert "temp_min" in data
    assert "humidity" in data