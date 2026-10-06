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

    # Kindle WP63GW (7th Gen Basic) Browser Portrait: 600x700 (fits under 85px top navigation bar)
    kindle_screen_width: int = 600
    kindle_screen_height: int = 700
    screen_orientation: int = 0  # 0, 90, 180, 270

    image_format: str = "png"  # png or bmp
    color_mode: str = "1bit"  # 1bit or 8bit
    dithering: bool = True

    # Weather Defaults (Atlanta, GA & Celsius)
    timezone: str = "America/New_York"
    ical_urls: str = ""
    latitude: float = 33.7490
    longitude: float = -84.3880
    location_name: str = "Atlanta"
    celsius: bool = True

    # Tasks / Notes Integration
    tasks_file_path: str = "config/tasks.md"
    google_tasks_credentials_file: Optional[str] = None
    google_tasks_list_id: str = ""

    # Google Keep Integration (Optional)
    google_keep_email: str = ""
    google_keep_password: str = ""  # Google App Password or master token
    google_keep_note_title: str = "Kindle Tasks"

    # Device Security & Cache
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