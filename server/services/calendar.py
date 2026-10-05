import logging
from datetime import datetime, date, time, timedelta
from typing import Dict, Any, List, Optional
import pytz
import httpx
import icalendar
import recurring_ical_events
from server.config import settings

logger = logging.getLogger(__name__)

SAMPLE_EVENTS = {
    "today": [
        {"title": "Morning Standup & Planning", "time": "09:30 AM", "all_day": False, "location": "Zoom"},
        {"title": "Dentist Appointment", "time": "02:00 PM", "all_day": False, "location": "Dental Clinic"},
        {"title": "Evening Walk & Grocery", "time": "06:30 PM", "all_day": False, "location": "Market"},
    ],
    "tomorrow": [
        {"title": "Design System Review", "time": "11:00 AM", "all_day": False, "location": "Studio"},
        {"title": "Family Dinner", "time": "07:00 PM", "all_day": False, "location": "Home"},
    ],
    "is_sample": True,
}

def _to_tz_datetime(dt_val: Any, target_tz: pytz.BaseTzInfo) -> datetime:
    """Converts a date or datetime to an aware datetime in target_tz."""
    if isinstance(dt_val, datetime):
        if dt_val.tzinfo is None:
            return target_tz.localize(dt_val)
        return dt_val.astimezone(target_tz)
    elif isinstance(dt_val, date):
        dt = datetime.combine(dt_val, time.min)
        return target_tz.localize(dt)
    raise ValueError(f"Unsupported datetime type: {type(dt_val)}")

def _format_time(dt_start: datetime, dt_end: Optional[datetime], is_all_day: bool) -> str:
    if is_all_day:
        return "All Day"
    start_str = dt_start.strftime("%I:%M %p").lstrip("0")
    if dt_end and (dt_end - dt_start) > timedelta(minutes=5):
        end_str = dt_end.strftime("%I:%M %p").lstrip("0")
        return f"{start_str} - {end_str}"
    return start_str

async def fetch_calendar_events() -> Dict[str, Any]:
    urls = settings.parsed_ical_urls
    if not urls:
        return SAMPLE_EVENTS

    try:
        target_tz = pytz.timezone(settings.timezone)
    except Exception:
        target_tz = pytz.UTC

    now = datetime.now(target_tz)
    today_start = datetime.combine(now.date(), time.min)
    today_start = target_tz.localize(today_start) if today_start.tzinfo is None else today_start
    tomorrow_date = now.date() + timedelta(days=1)
    tomorrow_end = datetime.combine(tomorrow_date, time.max)
    tomorrow_end = target_tz.localize(tomorrow_end) if tomorrow_end.tzinfo is None else tomorrow_end

    raw_events: List[Dict[str, Any]] = []

    async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
        for url in urls:
            try:
                resp = await client.get(url)
                if resp.status_code != 200:
                    logger.warning(f"Failed to fetch iCal feed {url}: HTTP {resp.status_code}")
                    continue

                cal = icalendar.Calendar.from_ical(resp.content)
                cal_name = str(cal.get("X-WR-CALNAME", ""))

                events_in_range = recurring_ical_events.of(cal).between(today_start, tomorrow_end)

                for ev in events_in_range:
                    dtstart_prop = ev.get("DTSTART")
                    if not dtstart_prop:
                        continue
                    dt_start_raw = dtstart_prop.dt
                    is_all_day = isinstance(dt_start_raw, date) and not isinstance(dt_start_raw, datetime)
                    dt_start = _to_tz_datetime(dt_start_raw, target_tz)

                    dtend_prop = ev.get("DTEND")
                    dt_end = _to_tz_datetime(dtend_prop.dt, target_tz) if dtend_prop else None

                    summary = str(ev.get("SUMMARY", "Untitled Event"))
                    location = str(ev.get("LOCATION", "")) if ev.get("LOCATION") else ""

                    raw_events.append({
                        "title": summary,
                        "start_dt": dt_start,
                        "end_dt": dt_end,
                        "time": _format_time(dt_start, dt_end, is_all_day),
                        "all_day": is_all_day,
                        "location": location,
                        "cal_name": cal_name,
                        "event_date": dt_start.date(),
                    })
            except Exception as e:
                logger.error(f"Error parsing iCal feed {url}: {e}")

    today_events = []
    tomorrow_events = []

    raw_events.sort(key=lambda x: (0 if x["all_day"] else 1, x["start_dt"]))

    today_date = now.date()
    for ev in raw_events:
        item = {
            "title": ev["title"],
            "time": ev["time"],
            "all_day": ev["all_day"],
            "location": ev["location"],
            "cal_name": ev.get("cal_name", ""),
        }
        if ev["event_date"] == today_date:
            today_events.append(item)
        elif ev["event_date"] == tomorrow_date:
            tomorrow_events.append(item)

    return {
        "today": today_events,
        "tomorrow": tomorrow_events,
        "is_sample": False,
        "total_count": len(today_events) + len(tomorrow_events),
    }