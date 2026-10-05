from typing import List, Optional
from pydantic_settings import BaseSettings, SettingsConfigDict
import os

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=["config/.env", ".env"],
        env_file_encoding="utf-8",
        extra="ignore"
    )

    port: int = 5055
    host: str = "0.0.0.0"
    refresh_rate_seconds: int = 900

    kindle_screen_width: int = 800
    kindle_screen_height: int = 480
    screen_orientation: int = 0  # 0, 90, 180, 270

    image_format: str = "png"  # png or bmp
    color_mode: str = "1bit"  # 1bit or 8bit
    dithering: bool = True

    timezone: str = "America/New_York"
    ical_urls: str = ""
    latitude: float = 40.7128
    longitude: float = -74.0060
    location_name: str = "New York"
    celsius: bool = False

    tasks_file_path: str = "config/tasks.md"
    google_tasks_credentials_file: Optional[str] = None

    allowed_device_ids: str = ""
    cache_ttl_seconds: int = 60
    device_status_file_path: str = "config/device_status.json"

    @property
    def parsed_ical_urls(self) -> List[str]:
        if not self.ical_urls:
            return []
        urls = []
        for line in self.ical_urls.replace(",", "\n").splitlines():
            clean = line.strip()
            if clean and not clean.startswith("#"):
                urls.append(clean)
        return urls

    @property
    def parsed_allowed_device_ids(self) -> List[str]:
        if not self.allowed_device_ids:
            return []
        return [dev.strip().lower() for dev in self.allowed_device_ids.split(",") if dev.strip()]

settings = Settings()