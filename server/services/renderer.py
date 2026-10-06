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

    # Weather Top Card (full width)
    draw.rectangle([(10, 10), (width - 10, 100)], outline=(0, 0, 0), width=2)
    w = context.get("weather", {})
    draw.text((25, 20), f"WEATHER: {w.get('temperature', '')}{w.get('unit', '')} - {w.get('condition', '')}", fill=(0, 0, 0))
    draw.text((25, 48), f"High: {w.get('temp_max', '')}° | Low: {w.get('temp_min', '')}° | Rain: {w.get('precipitation_probability', '')}%", fill=(0, 0, 0))
    draw.text((25, 74), f"Loc: {w.get('location', '')} | Updated: {context.get('now_time', '')}", fill=(0, 0, 0))

    # Main Columns
    left_w = int(width * 0.54)
    draw.rectangle([(10, 108), (left_w - 5, height - 10)], outline=(0, 0, 0), width=2)
    draw.rectangle([(left_w + 5, 108), (width - 10, height - 10)], outline=(0, 0, 0), width=2)

    # Calendar / Agenda
    draw.text((20, 118), "UPCOMING EVENTS:", fill=(0, 0, 0))
    cal = context.get("calendar", {})
    events = cal.get("next_events", [])
    y = 145
    for ev in events[:8]:
        draw.text((25, y), f"• {ev.get('day_badge', '')} {ev.get('time', '')} {ev.get('title', '')[:22]}", fill=(0, 0, 0))
        y += 24

    # Tasks
    draw.text((left_w + 15, 118), "TASKS & FOCUS:", fill=(0, 0, 0))
    tasks = context.get("tasks", {}).get("tasks", [])
    ty = 145
    for t in tasks[:10]:
        mark = "[X]" if t.get("completed") else "[ ]"
        draw.text((left_w + 20, ty), f"{mark} {t.get('text', '')[:20]}", fill=(0, 0, 0))
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