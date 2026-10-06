import io
import time
import logging
from typing import Dict, Any, Tuple, Optional
from jinja2 import Environment, FileSystemLoader, select_autoescape
from PIL import Image, ImageDraw, ImageFont
from server.config import settings

logger = logging.getLogger(__name__)

# Initialize Jinja2 Environment
templates_env = Environment(
    loader=FileSystemLoader("server/templates"),
    autoescape=select_autoescape(["html", "xml"])
)

# In-memory Image Cache
_cached_image_bytes: bytes = b""
_cached_image_time: float = 0.0
_cached_format: str = ""
_cached_rotation: int = 0

def invalidate_render_cache():
    global _cached_image_time
    _cached_image_time = 0.0


def render_html_content(context: Dict[str, Any]) -> str:
    template = templates_env.get_template("dashboard.html")
    return template.render(
        width=settings.kindle_screen_width,
        height=settings.kindle_screen_height,
        **context
    )

def _render_fallback_pillow(context: Dict[str, Any]) -> bytes:
    """Native Pillow fallback renderer if browser engine is unavailable."""
    width = settings.kindle_screen_width
    height = settings.kindle_screen_height
    img = Image.new("RGB", (width, height), color=(255, 255, 255))
    draw = ImageDraw.Draw(img)

    # 1. Top Row: Weather Card (Left) & Date + Time Card (Right)
    top_split = 320
    draw.rectangle([(8, 8), (top_split, 92)], outline=(0, 0, 0), width=2)
    w = context.get("weather", {})
    draw.text((18, 16), f"WEATHER: {w.get('temperature', '')}{w.get('unit', '')} - {w.get('condition', '')}", fill=(0, 0, 0))
    draw.text((18, 42), f"Hi: {w.get('temp_max', '')}° | Lo: {w.get('temp_min', '')}° | Rain: {w.get('precipitation_probability', '')}%", fill=(0, 0, 0))
    draw.text((18, 68), f"Loc: {w.get('location', '')}", fill=(0, 0, 0))

    draw.rectangle([(top_split + 6, 8), (width - 8, 92)], outline=(0, 0, 0), width=2)
    draw.text((top_split + 18, 16), f"{context.get('now_time', '')}", fill=(0, 0, 0))
    draw.text((top_split + 18, 44), f"{context.get('now_day', '')}", fill=(0, 0, 0))
    draw.text((top_split + 18, 68), f"{context.get('now_date', '')}", fill=(0, 0, 0))

    # 2. Middle Row: Calendar (Full Width)
    cal_top = 98
    cal_bottom = 544
    draw.rectangle([(8, cal_top), (width - 8, cal_bottom)], outline=(0, 0, 0), width=2)
    cal = context.get("calendar", {})
    month_grid = cal.get("month_grid", {})
    month_title = month_grid.get("month_title", "CALENDAR")
    draw.text((18, cal_top + 10), f"CALENDAR: {month_title}", fill=(0, 0, 0))

    headers = "   ".join(month_grid.get("headers", ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]))
    draw.text((18, cal_top + 32), headers, fill=(0, 0, 0))

    cy = cal_top + 60
    for week in month_grid.get("weeks", []):
        week_str = "    ".join(f"{d.get('day'):02d}" for d in week)
        draw.text((18, cy), week_str, fill=(0, 0, 0))
        cy += 45

    # 3. Bottom Row: Events (Left) & To Do (Right)
    bot_top = 550
    bot_split = int((width - 16) / 2) + 8
    draw.rectangle([(8, bot_top), (bot_split - 3, height - 8)], outline=(0, 0, 0), width=2)
    draw.rectangle([(bot_split + 3, bot_top), (width - 8, height - 8)], outline=(0, 0, 0), width=2)

    # Left: Upcoming Events
    draw.text((18, bot_top + 10), "UPCOMING EVENTS:", fill=(0, 0, 0))
    events = cal.get("next_events", [])
    ey = bot_top + 36
    for ev in events[:6]:
        draw.text((18, ey), f"• {ev.get('day_badge', '')} {ev.get('time', '')} {ev.get('title', '')[:18]}", fill=(0, 0, 0))
        ey += 24

    # Right: To Do Tasks
    draw.text((bot_split + 14, bot_top + 10), "TO DO:", fill=(0, 0, 0))
    tasks = context.get("tasks", {}).get("tasks", [])
    ty = bot_top + 36
    for t in tasks[:7]:
        mark = "[X]" if t.get("completed") else "[ ]"
        draw.text((bot_split + 14, ty), f"{mark} {t.get('text', '')[:20]}", fill=(0, 0, 0))
        ty += 24

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()

async def render_dashboard_image(context: Dict[str, Any], force_refresh: bool = False, rotate: Optional[int] = None) -> Tuple[bytes, str]:
    global _cached_image_bytes, _cached_image_time, _cached_format, _cached_rotation

    img_format = settings.image_format.lower()
    now_ts = time.time()

    # Determine effective rotation
    effective_rot = settings.screen_orientation
    if rotate is not None:
        if rotate == 1:
            effective_rot = 90
        elif rotate == 2:
            effective_rot = 180
        elif rotate == 3:
            effective_rot = 270
        elif rotate in [90, 180, 270]:
            effective_rot = rotate

    # Check cache validity
    if not force_refresh and _cached_image_bytes and (now_ts - _cached_image_time < settings.cache_ttl_seconds) and (_cached_format == img_format) and (_cached_rotation == effective_rot):
        return _cached_image_bytes, img_format

    html_content = render_html_content(context)
    raw_png_bytes: bytes = b""

    # Attempt Playwright Chromium capture
    try:
        from playwright.async_api import async_playwright
        async with async_playwright() as p:
            browser = await p.chromium.launch(
                headless=True,
                args=[
                    "--no-sandbox",
                    "--disable-setuid-sandbox",
                    "--disable-dev-shm-usage",
                    "--disable-gpu",
                ]
            )
            page = await browser.new_page(
                viewport={"width": settings.kindle_screen_width, "height": settings.kindle_screen_height},
                device_scale_factor=1
            )
            await page.set_content(html_content, wait_until="networkidle")
            raw_png_bytes = await page.screenshot(type="png")
            await browser.close()
    except Exception as e:
        logger.warning(f"Playwright rendering failed or not available ({e}). Using native Pillow fallback.")
        raw_png_bytes = _render_fallback_pillow(context)

    # Process with Pillow for E-ink Optimization
    image = Image.open(io.BytesIO(raw_png_bytes))

    # Apply Screen Orientation Rotation
    if effective_rot in [90, 180, 270]:
        image = image.rotate(360 - effective_rot, expand=True)

    # Convert Color Mode
    if settings.color_mode == "1bit":
        if settings.dithering:
            image = image.convert("1", dither=Image.Dither.FLOYDSTEINBERG)
        else:
            image = image.convert("L").point(lambda p: 255 if p > 128 else 0, mode="1")
    else:
        image = image.convert("L")  # 8-bit Grayscale

    out_buf = io.BytesIO()
    if img_format == "bmp":
        image.save(out_buf, format="BMP")
    else:
        image.save(out_buf, format="PNG", optimize=True)

    final_bytes = out_buf.getvalue()

    # Update Cache
    _cached_image_bytes = final_bytes
    _cached_image_time = now_ts
    _cached_format = img_format
    _cached_rotation = effective_rot

    return final_bytes, img_format