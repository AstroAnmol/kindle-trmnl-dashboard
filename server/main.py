import os
import time
import hashlib
import logging
from datetime import datetime
from typing import Optional, Dict, Any, List
from contextlib import asynccontextmanager

from fastapi import FastAPI, Header, Query, Request, Response, HTTPException, status
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel, Field
import pytz

from server.config import settings
from server.services.weather import fetch_weather
from server.services.calendar import fetch_calendar_events
from server.services.tasks import (
    fetch_tasks_and_notes,
    get_raw_tasks_file,
    save_raw_tasks_markdown,
    toggle_task_in_file,
    add_task_to_file,
    delete_task_from_file,
    add_note_to_file
)
from server.services.telemetry import telemetry_service
from server.services.renderer import (
    render_dashboard_image,
    render_html_content,
    templates_env,
    invalidate_render_cache
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("kindle-trmnl")

class TelemetryPayload(BaseModel):
    device_id: Optional[str] = Field(None, description="MAC address or device identifier")
    battery_percent: Optional[int] = Field(None, description="Battery percentage (0-100)")
    battery_voltage: Optional[float] = Field(None, description="Battery voltage in Volts")
    signal_strength: Optional[int] = Field(None, description="Wi-Fi signal strength in dBm")
    firmware_version: Optional[str] = Field(None, description="Kindle firmware or OS version")

class TaskTogglePayload(BaseModel):
    index: int

class TaskAddPayload(BaseModel):
    text: str

class TaskDeletePayload(BaseModel):
    index: int

class TaskRawPayload(BaseModel):
    markdown: str

class NoteAddPayload(BaseModel):
    note: str

class CalendarConfigPayload(BaseModel):
    ical_urls: str

def _update_env_key(key: str, value: str, env_file: str = "config/.env") -> None:
    """Safely updates or appends a key in config/.env without losing comments."""
    lines = []
    found = False
    if os.path.exists(env_file):
        with open(env_file, "r", encoding="utf-8") as f:
            lines = f.readlines()

    new_lines = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith(f"{key}=") or stripped.startswith(f"#{key}="):
            new_lines.append(f"{key}={value}\n")
            found = True
        else:
            new_lines.append(line)

    if not found:
        new_lines.append(f"{key}={value}\n")

    try:
        os.makedirs(os.path.dirname(env_file), exist_ok=True)
        with open(env_file, "w", encoding="utf-8") as f:
            f.writelines(new_lines)
    except Exception as e:
        logger.error(f"Failed to update {env_file}: {e}")

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("==================================================")
    logger.info("🚀 Kindle TRMNL Dashboard Server Initializing")
    logger.info(f"   • Host/Port: {settings.host}:{settings.port}")
    logger.info(f"   • Viewport: {settings.kindle_screen_width}x{settings.kindle_screen_height}")
    logger.info(f"   • Refresh Rate: {settings.refresh_rate_seconds}s")
    logger.info(f"   • Timezone: {settings.timezone}")
    logger.info(f"   • Location: {settings.location_name} (Celsius: {settings.celsius})")
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

    menu_data = tasks_data.get("menu", [])
    for item in menu_data:
        item["is_today"] = (
            item.get("day_full", "").lower() == now_day.lower()
            or item.get("day", "").lower() == now_day[:3].lower()
        )

    return {
        "now_day": now_day,
        "now_date": now_date,
        "now_time": now_time,
        "last_updated": last_updated,
        "weather": weather_data,
        "calendar": calendar_data,
        "tasks": tasks_data,
        "menu": menu_data,
        "telemetry": telemetry_data,
        "refresh_rate_seconds": settings.refresh_rate_seconds,
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

@app.get("/api/display/image", summary="TRMNL Display Raw Image")
async def api_display_image(
    request: Request,
    id_header: Optional[str] = Header(None, alias="ID"),
    token_header: Optional[str] = Header(None, alias="Access-Token"),
    mac_param: Optional[str] = Query(None, alias="mac"),
    format_param: Optional[str] = Query(None, alias="format"),
    rotate: Optional[int] = Query(None, description="Rotation degrees: 90, 180, 270 or 1, 2, 3"),
    orientation: Optional[int] = Query(None, description="Alias for rotate"),
    force: bool = Query(False, alias="force"),
    battery_level: Optional[int] = Query(None, alias="batteryLevel"),
    is_charging: Optional[int] = Query(None, alias="isCharging")
):
    """Renders and returns raw optimized binary image (PNG or BMP) for Kindle e-ink display."""
    device_id = id_header or token_header or mac_param or "anonymous"

    allowed = settings.parsed_allowed_device_ids
    if allowed:
        norm_id = device_id.strip().lower()
        if norm_id not in allowed:
            logger.warning(f"Unauthorized device access attempt from: '{device_id}'")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Unauthorized Kindle Device ID or Access Token"
            )

    # Ingest battery telemetry if provided via query parameters (e.g., from onlinescreensaver update.sh)
    if battery_level is not None:
        telemetry_update = {
            "device_id": device_id,
            "battery_percent": battery_level
        }
        if is_charging is not None:
            telemetry_update["is_charging"] = bool(is_charging)
        telemetry_service.update(telemetry_update)

    eff_rot = rotate if rotate is not None else orientation
    context = await build_dashboard_context()
    image_bytes, out_format = await render_dashboard_image(context, force_refresh=force, rotate=eff_rot)

    media_type = "image/bmp" if out_format == "bmp" else "image/png"
    etag = f'"{hashlib.md5(image_bytes).hexdigest()}"'

    # Support conditional HTTP 304 Not Modified requests (ETag caching saves Kindle battery & avoids unnecessary refresh)
    if_none_match = request.headers.get("if-none-match")
    if if_none_match and if_none_match.strip() == etag and not force:
        return Response(
            status_code=status.HTTP_304_NOT_MODIFIED,
            headers={
                "ETag": etag,
                "Cache-Control": "no-store, no-cache, must-revalidate",
                "Refresh-Rate": str(settings.refresh_rate_seconds),
            }
        )

    response_headers = {
        "Refresh-Rate": str(settings.refresh_rate_seconds),
        "Image-Format": out_format,
        "Cache-Control": "no-store, no-cache, must-revalidate",
        "X-Device-Id": device_id,
        "ETag": etag,
    }

    return Response(content=image_bytes, media_type=media_type, headers=response_headers)

@app.get("/api/display", summary="TRMNL Display Image Render or Browser Viewer")
async def api_display(
    request: Request,
    id_header: Optional[str] = Header(None, alias="ID"),
    token_header: Optional[str] = Header(None, alias="Access-Token"),
    mac_param: Optional[str] = Query(None, alias="mac"),
    format_param: Optional[str] = Query(None, alias="format"),
    rotate: Optional[int] = Query(None, description="Rotation degrees: 90, 180, 270 or 1, 2, 3"),
    orientation: Optional[int] = Query(None, description="Alias for rotate"),
    force: bool = Query(False, alias="force"),
    battery_level: Optional[int] = Query(None, alias="batteryLevel"),
    is_charging: Optional[int] = Query(None, alias="isCharging")
):
    """
    Renders optimized binary image for Kindle e-ink display, or a clean HTML viewer
    page displaying the image with today's date title when opened in the Kindle Experimental Browser.
    """
    device_id = id_header or token_header or mac_param or "anonymous"

    allowed = settings.parsed_allowed_device_ids
    if allowed:
        norm_id = device_id.strip().lower()
        if norm_id not in allowed:
            logger.warning(f"Unauthorized device access attempt from: '{device_id}'")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Unauthorized Kindle Device ID or Access Token"
            )

    accept_header = request.headers.get("accept", "")
    wants_browser_view = format_param == "html" or (
        "text/html" in accept_header and format_param not in ["png", "bmp"]
    )

    if wants_browser_view:
        context = await build_dashboard_context()
        now_day = context.get("now_day", "")
        now_date = context.get("now_date", "")
        refresh_sec = settings.refresh_rate_seconds
        timestamp = int(time.time())
        html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <meta http-equiv="refresh" content="{refresh_sec}">
    <title>{now_day}, {now_date}</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        html, body {{
            width: 100%;
            height: 100%;
            background-color: #ffffff;
            overflow: hidden;
            text-align: center;
        }}
        img {{
            display: block;
            width: 100%;
            max-width: 600px;
            height: auto;
            margin: 0 auto;
        }}
    </style>
</head>
<body>
    <img src="/api/display/image?t={timestamp}" alt="{now_day}, {now_date}">
</body>
</html>"""
        return HTMLResponse(
            content=html,
            headers={
                "Cache-Control": "no-store, no-cache, must-revalidate",
                "Refresh": str(refresh_sec),
                "X-Device-Id": device_id,
            }
        )

    # Return raw image for curl / TRMNL clients / scripts
    return await api_display_image(
        request=request,
        id_header=id_header,
        token_header=token_header,
        mac_param=mac_param,
        format_param=format_param,
        rotate=rotate,
        orientation=orientation,
        force=force,
        battery_level=battery_level,
        is_charging=is_charging
    )

@app.post("/api/log", summary="TRMNL Telemetry Logger")
async def api_log(payload: TelemetryPayload):
    """Accepts battery percentage, voltage, and signal strength from Kindle client."""
    logger.info(f"Received Kindle Telemetry: {payload.model_dump(exclude_none=True)}")
    updated = telemetry_service.update(payload.model_dump(exclude_none=True))
    return {
        "status": 200,
        "message": "Telemetry logged successfully",
        "current_state": updated
    }

# ==============================================================================
# Tasks & Notes Interactive Management Endpoints
# ==============================================================================

@app.get("/api/tasks", summary="Get Current Tasks & Notes")
async def api_get_tasks():
    """Returns current parsed tasks, notes, and raw markdown content."""
    parsed = fetch_tasks_and_notes()
    raw = get_raw_tasks_file()
    return {
        "tasks": parsed.get("tasks", []),
        "notes": parsed.get("notes", []),
        "menu": parsed.get("menu", []),
        "completed_count": parsed.get("completed_count", 0),
        "total": parsed.get("total", 0),
        "raw_markdown": raw,
        "source": parsed.get("source", "local_markdown")
    }

@app.post("/api/tasks/toggle", summary="Toggle Task Completion")
async def api_toggle_task(payload: TaskTogglePayload):
    """Toggles completion checkbox of n-th task in config/tasks.md."""
    success = toggle_task_in_file(payload.index)
    if success:
        invalidate_render_cache()
    return {"success": success, "data": fetch_tasks_and_notes()}

@app.post("/api/tasks/add", summary="Add New Task")
async def api_add_task(payload: TaskAddPayload):
    """Appends an unchecked task to config/tasks.md."""
    if not payload.text.strip():
        raise HTTPException(status_code=400, detail="Task text cannot be empty")
    success = add_task_to_file(payload.text.strip())
    if success:
        invalidate_render_cache()
    return {"success": success, "data": fetch_tasks_and_notes()}

@app.post("/api/tasks/delete", summary="Delete Task")
async def api_delete_task(payload: TaskDeletePayload):
    """Deletes n-th task from config/tasks.md."""
    success = delete_task_from_file(payload.index)
    if success:
        invalidate_render_cache()
    return {"success": success, "data": fetch_tasks_and_notes()}

@app.post("/api/tasks/raw", summary="Save Raw Markdown Tasks")
async def api_save_raw_tasks(payload: TaskRawPayload):
    """Overwrites config/tasks.md with user-edited markdown."""
    success = save_raw_tasks_markdown(payload.markdown)
    if success:
        invalidate_render_cache()
    return {"success": success, "message": "Tasks saved successfully"}

@app.post("/api/notes/add", summary="Add Quick Note")
async def api_add_note(payload: NoteAddPayload):
    """Adds a quick note bullet point to config/tasks.md."""
    if not payload.note.strip():
        raise HTTPException(status_code=400, detail="Note text cannot be empty")
    success = add_note_to_file(payload.note.strip())
    if success:
        invalidate_render_cache()
    return {"success": success, "data": fetch_tasks_and_notes()}

# ==============================================================================
# Configuration & Calendar Endpoints
# ==============================================================================

@app.get("/api/config", summary="Get Server Settings")
async def api_get_config():
    """Returns non-sensitive server settings."""
    return {
        "ical_urls": settings.ical_urls,
        "location_name": settings.location_name,
        "latitude": settings.latitude,
        "longitude": settings.longitude,
        "celsius": settings.celsius,
        "timezone": settings.timezone,
        "refresh_rate_seconds": settings.refresh_rate_seconds,
        "kindle_screen_width": settings.kindle_screen_width,
        "kindle_screen_height": settings.kindle_screen_height,
    }

@app.post("/api/config/calendar", summary="Update Google Calendar Feed URLs")
async def api_update_calendar(payload: CalendarConfigPayload):
    """Updates ICAL_URLS in memory and in config/.env file."""
    clean_urls = payload.ical_urls.strip()
    settings.ical_urls = clean_urls
    _update_env_key("ICAL_URLS", clean_urls)
    invalidate_render_cache()
    # Trigger fetch to verify
    cal_data = await fetch_calendar_events()
    return {
        "success": True,
        "message": "Calendar feed updated successfully",
        "calendar_status": cal_data.get("status", "unknown"),
        "events_count": cal_data.get("total_count", 0)
    }

# ==============================================================================
# Browser & Developer Endpoints
# ==============================================================================

@app.get("/", response_class=HTMLResponse, summary="Interactive Web Preview")
async def preview_page():
    """Interactive desktop/mobile preview page with live refresh and task editor."""
    tmpl = templates_env.get_template("preview.html")
    html = tmpl.render(
        width=settings.kindle_screen_width,
        height=settings.kindle_screen_height,
        cache_bust=int(time.time()),
        ical_urls=settings.ical_urls,
        location_name=settings.location_name,
        celsius=settings.celsius
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