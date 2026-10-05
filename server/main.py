import time
import logging
from datetime import datetime
from typing import Optional, Dict, Any
from contextlib import asynccontextmanager

from fastapi import FastAPI, Header, Query, Request, Response, HTTPException, status
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel, Field
import pytz

from server.config import settings
from server.services.weather import fetch_weather
from server.services.calendar import fetch_calendar_events
from server.services.tasks import fetch_tasks_and_notes
from server.services.telemetry import telemetry_service
from server.services.renderer import render_dashboard_image, render_html_content, templates_env

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("kindle-trmnl")

class TelemetryPayload(BaseModel):
    device_id: Optional[str] = Field(None, description="MAC address or device identifier")
    battery_percent: Optional[int] = Field(None, description="Battery percentage (0-100)")
    battery_voltage: Optional[float] = Field(None, description="Battery voltage in Volts")
    signal_strength: Optional[int] = Field(None, description="Wi-Fi signal strength in dBm")
    firmware_version: Optional[str] = Field(None, description="Kindle firmware or OS version")

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("==================================================")
    logger.info("🚀 Kindle TRMNL Dashboard Server Initializing")
    logger.info(f"   • Host/Port: {settings.host}:{settings.port}")
    logger.info(f"   • Viewport: {settings.kindle_screen_width}x{settings.kindle_screen_height}")
    logger.info(f"   • Refresh Rate: {settings.refresh_rate_seconds}s")
    logger.info(f"   • Timezone: {settings.timezone}")
    logger.info("==================================================")
    yield
    logger.info("🛑 Kindle TRMNL Dashboard Server Shutting Down")

app = FastAPI(
    title="Kindle TRMNL Dashboard",
    description="Self-hosted TRMNL-compatible e-ink dashboard server for jailbroken Kindles.",
    version="1.0.0",
    lifespan=lifespan
)

# Mount static files
app.mount("/static", StaticFiles(directory="server/static"), name="static")

async def build_dashboard_context() -> Dict[str, Any]:
    try:
        target_tz = pytz.timezone(settings.timezone)
    except Exception:
        target_tz = pytz.UTC

    now = datetime.now(target_tz)
    now_day = now.strftime("%A")
    now_date = now.strftime("%B %d, %Y")
    now_time = now.strftime("%I:%M %p").lstrip("0")
    last_updated = now.strftime("%I:%M:%S %p")

    weather_data = await fetch_weather()
    calendar_data = await fetch_calendar_events()
    tasks_data = fetch_tasks_and_notes()
    telemetry_data = telemetry_service.get_data()

    return {
        "now_day": now_day,
        "now_date": now_date,
        "now_time": now_time,
        "last_updated": last_updated,
        "weather": weather_data,
        "calendar": calendar_data,
        "tasks": tasks_data,
        "telemetry": telemetry_data,
    }

# ==============================================================================
# TRMNL Protocol Endpoints
# ==============================================================================

@app.get("/api/setup", summary="TRMNL Setup Handshake")
async def api_setup():
    """TRMNL device setup & connection handshake."""
    return {
        "status": 200,
        "message": "Connected to self-hosted TRMNL"
    }

@app.get("/api/display", summary="TRMNL Display Image Render")
async def api_display(
    request: Request,
    id_header: Optional[str] = Header(None, alias="ID"),
    token_header: Optional[str] = Header(None, alias="Access-Token"),
    mac_param: Optional[str] = Query(None, alias="mac"),
    format_param: Optional[str] = Query(None, alias="format"),
    force: bool = Query(False, alias="force")
):
    """
    Renders optimized binary image (PNG or BMP) for Kindle e-ink display.
    Validates Kindle MAC address/Token and returns 'Refresh-Rate' & 'Image-Format' headers.
    """
    device_id = id_header or token_header or mac_param or "anonymous"

    # Validate against ALLOWED_DEVICE_IDS if configured
    allowed = settings.parsed_allowed_device_ids
    if allowed:
        norm_id = device_id.strip().lower()
        if norm_id not in allowed:
            logger.warning(f"Unauthorized device access attempt from: '{device_id}'")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Unauthorized Kindle Device ID or Access Token"
            )

    context = await build_dashboard_context()
    image_bytes, out_format = await render_dashboard_image(context, force_refresh=force)

    # Determine media type
    if out_format == "bmp":
        media_type = "image/bmp"
    else:
        media_type = "image/png"

    response_headers = {
        "Refresh-Rate": str(settings.refresh_rate_seconds),
        "Image-Format": out_format,
        "Cache-Control": "no-store, no-cache, must-revalidate",
        "X-Device-Id": device_id,
    }

    return Response(content=image_bytes, media_type=media_type, headers=response_headers)

@app.post("/api/log", summary="TRMNL Telemetry Logger")
async def api_log(payload: TelemetryPayload):
    """
    Accepts battery percentage, voltage, and signal strength from Kindle client.
    """
    logger.info(f"Received Kindle Telemetry: {payload.model_dump(exclude_none=True)}")
    updated = telemetry_service.update(payload.model_dump(exclude_none=True))
    return {
        "status": 200,
        "message": "Telemetry logged successfully",
        "current_state": updated
    }

# ==============================================================================
# Browser & Developer Endpoints
# ==============================================================================

@app.get("/", response_class=HTMLResponse, summary="Interactive Web Preview")
async def preview_page():
    """Interactive desktop/mobile preview page with live refresh."""
    tmpl = templates_env.get_template("preview.html")
    html = tmpl.render(
        width=settings.kindle_screen_width,
        height=settings.kindle_screen_height,
        cache_bust=int(time.time())
    )
    return HTMLResponse(content=html)

@app.get("/preview", summary="Raw Rendered Image Preview")
async def preview_raw_image():
    """Directly returns the rendered image for fast browser inspection."""
    context = await build_dashboard_context()
    image_bytes, out_format = await render_dashboard_image(context)
    media_type = "image/bmp" if out_format == "bmp" else "image/png"
    return Response(content=image_bytes, media_type=media_type)

@app.get("/dashboard.html", response_class=HTMLResponse, summary="Raw Rendered Dashboard HTML")
async def raw_html():
    """Returns raw dashboard HTML template with live data."""
    context = await build_dashboard_context()
    html = render_html_content(context)
    return HTMLResponse(content=html)

@app.get("/api/data", summary="Aggregated Dashboard Data")
async def api_data():
    """Returns aggregated JSON context (weather, calendar, tasks, telemetry)."""
    return await build_dashboard_context()

@app.get("/api/health", summary="Health Check")
async def health_check():
    """Service health status for Docker health checks."""
    return {
        "status": "ok",
        "timestamp": datetime.now().isoformat(),
        "device_battery": telemetry_service.get_data().get("battery_percent"),
        "timezone": settings.timezone
    }