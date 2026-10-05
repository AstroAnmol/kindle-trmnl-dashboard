import logging
from typing import Dict, Any, Optional
import httpx
from server.config import settings

logger = logging.getLogger(__name__)

WMO_WEATHER_MAP: Dict[int, Dict[str, str]] = {
    0: {"condition": "Clear Sky", "icon": "sun"},
    1: {"condition": "Mainly Clear", "icon": "sun-cloud"},
    2: {"condition": "Partly Cloudy", "icon": "partly-cloudy"},
    3: {"condition": "Overcast", "icon": "cloudy"},
    45: {"condition": "Foggy", "icon": "fog"},
    48: {"condition": "Rime Fog", "icon": "fog"},
    51: {"condition": "Light Drizzle", "icon": "drizzle"},
    53: {"condition": "Moderate Drizzle", "icon": "drizzle"},
    55: {"condition": "Dense Drizzle", "icon": "drizzle"},
    56: {"condition": "Freezing Drizzle", "icon": "sleet"},
    57: {"condition": "Dense Freezing Drizzle", "icon": "sleet"},
    61: {"condition": "Slight Rain", "icon": "rain"},
    63: {"condition": "Moderate Rain", "icon": "rain"},
    65: {"condition": "Heavy Rain", "icon": "heavy-rain"},
    66: {"condition": "Light Freezing Rain", "icon": "sleet"},
    67: {"condition": "Heavy Freezing Rain", "icon": "sleet"},
    71: {"condition": "Slight Snow", "icon": "snow"},
    73: {"condition": "Moderate Snow", "icon": "snow"},
    75: {"condition": "Heavy Snow", "icon": "heavy-snow"},
    77: {"condition": "Snow Grains", "icon": "snow"},
    80: {"condition": "Slight Showers", "icon": "rain"},
    81: {"condition": "Moderate Showers", "icon": "rain"},
    82: {"condition": "Violent Showers", "icon": "heavy-rain"},
    85: {"condition": "Snow Showers", "icon": "snow"},
    86: {"condition": "Heavy Snow Showers", "icon": "heavy-snow"},
    95: {"condition": "Thunderstorm", "icon": "thunderstorm"},
    96: {"condition": "Thunderstorm w/ Hail", "icon": "thunderstorm"},
    99: {"condition": "Heavy Thunderstorm", "icon": "thunderstorm"},
}

DEFAULT_WEATHER: Dict[str, Any] = {
    "temperature": 72,
    "apparent_temperature": 72,
    "temp_max": 75,
    "temp_min": 60,
    "condition": "Partly Cloudy",
    "icon": "partly-cloudy",
    "weather_code": 2,
    "humidity": 45,
    "precipitation_probability": 10,
    "precipitation": 0.0,
    "wind_speed": 5,
    "unit": "°F",
    "location": settings.location_name,
    "is_fallback": True,
}

_weather_cache: Optional[Dict[str, Any]] = None

async def fetch_weather() -> Dict[str, Any]:
    global _weather_cache
    temp_unit = "celsius" if settings.celsius else "fahrenheit"
    wind_unit = "kmh" if settings.celsius else "mph"
    precip_unit = "mm" if settings.celsius else "inch"
    unit_symbol = "°C" if settings.celsius else "°F"

    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": settings.latitude,
        "longitude": settings.longitude,
        "current": [
            "temperature_2m",
            "relative_humidity_2m",
            "apparent_temperature",
            "precipitation",
            "weather_code",
            "wind_speed_10m",
        ],
        "daily": [
            "weather_code",
            "temperature_2m_max",
            "temperature_2m_min",
            "precipitation_probability_max",
        ],
        "temperature_unit": temp_unit,
        "wind_speed_unit": wind_unit,
        "precipitation_unit": precip_unit,
        "timezone": settings.timezone,
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url, params=params)
            response.raise_for_status()
            data = response.json()

        current = data.get("current", {})
        daily = data.get("daily", {})

        wmo_code = int(current.get("weather_code", 0))
        meta = WMO_WEATHER_MAP.get(wmo_code, {"condition": "Clear", "icon": "sun"})

        temp_max_list = daily.get("temperature_2m_max", [])
        temp_min_list = daily.get("temperature_2m_min", [])
        precip_prob_list = daily.get("precipitation_probability_max", [])

        temp_max = round(temp_max_list[0]) if temp_max_list else round(current.get("temperature_2m", 70))
        temp_min = round(temp_min_list[0]) if temp_min_list else round(current.get("temperature_2m", 60))
        precip_prob = round(precip_prob_list[0]) if precip_prob_list else 0

        weather_info = {
            "temperature": round(current.get("temperature_2m", 70)),
            "apparent_temperature": round(current.get("apparent_temperature", 70)),
            "temp_max": temp_max,
            "temp_min": temp_min,
            "condition": meta["condition"],
            "icon": meta["icon"],
            "weather_code": wmo_code,
            "humidity": round(current.get("relative_humidity_2m", 0)),
            "precipitation_probability": precip_prob,
            "precipitation": current.get("precipitation", 0.0),
            "wind_speed": round(current.get("wind_speed_10m", 0)),
            "unit": unit_symbol,
            "location": settings.location_name,
            "is_fallback": False,
        }
        _weather_cache = weather_info
        return weather_info

    except Exception as e:
        logger.warning(f"Failed to fetch Open-Meteo weather: {e}. Using fallback/cached data.")
        if _weather_cache:
            return _weather_cache
        fallback = dict(DEFAULT_WEATHER)
        fallback["unit"] = unit_symbol
        fallback["location"] = settings.location_name
        return fallback