import logging
import calendar as py_calendar
from datetime import datetime, date, time, timedelta
from typing import Dict, Any, List, Optional
import pytz
import httpx
import icalendar
import recurring_ical_events
from server.config import settings

logger = logging.getLogger(__name__)

def build_month_grid(now: datetime, all_events_by_date: Dict[date, List[Dict[str, Any]]]) -> Dict[str, Any]:
    """Generates a standard 7-column month grid (Sunday-first) with event indicators."""
    cal = py_calendar.Calendar(firstweekday=6)  # Sunday first
    weeks_dates = cal.monthdatescalendar(now.year, now.month)
    today_date = now.date()

    weeks = []
    for w in weeks_dates:
        week_days = []
        for d in w:
            day_events = all_events_by_date.get(d, [])
            week_days.append({
                "day": d.day,
                "date_str": d.isoformat(),
                "is_current_month": (d.month == now.month),
                "is_today": (d == today_date),
                "is_past": (d < today_date),
                "has_events": (len(day_events) > 0),
                "event_count": len(day_events),
                "events": day_events[:2],
            })
        weeks.append(week_days)

    return {
        "month_title": now.strftime("%B %Y").upper(),
        "month_name": now.strftime("%B"),
        "year": now.year,
        "headers": ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"],
        "weeks": weeks,
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

def _build_sample_response(target_tz: pytz.BaseTzInfo) -> Dict[str, Any]:
    now = datetime.now(target_tz)
    today_date = now.date()
    tomorrow_date = today_date + timedelta(days=1)
    day_after = today_date + timedelta(days=2)
    next_week = today_date + timedelta(days=4)

    today_evs = [
        {"title": "Morning Standup & Planning", "time": "09:30 AM", "all_day": False, "location": "Zoom"},
        {"title": "Dentist Appointment", "time": "02:00 PM", "all_day": False, "location": "Dental Clinic"},
        {"title": "Evening Walk & Grocery", "time": "06:30 PM", "all_day": False, "location": "Market"},
    ]
    tomorrow_evs = [
        {"title": "Design System Review", "time": "11:00 AM", "all_day": False, "location": "Studio"},
        {"title": "Family Dinner", "time": "07:00 PM", "all_day": False, "location": "Home"},
    ]
    upcoming_evs = [
        {"title": "Sprint Retrospective", "time": "03:00 PM", "all_day": False, "location": "Office", "date_str": day_after.strftime("%b %d"), "day_name": day_after.strftime("%A")},
        {"title": "Product Launch Prep", "time": "10:00 AM", "all_day": False, "location": "Work", "date_str": next_week.strftime("%b %d"), "day_name": next_week.strftime("%A")},
    ]

    events_by_date: Dict[date, List[Dict[str, Any]]] = {
        today_date: today_evs,
        tomorrow_date: tomorrow_evs,
        day_after: [{"title": "Sprint Retro", "time": "3:00 PM", "all_day": False}],
        next_week: [{"title": "Launch Prep", "time": "10:00 AM", "all_day": False}],
    }

    # Consolidated next_events sequence
    next_events = []
    for ev in today_evs:
        next_events.append({
            "day_badge": "Today",
            "time": ev["time"],
            "title": ev["title"],
            "all_day": ev["all_day"],
            "location": ev["location"]
        })
    for ev in tomorrow_evs:
        next_events.append({
            "day_badge": "Tomorrow",
            "time": ev["time"],
            "title": ev["title"],
            "all_day": ev["all_day"],
            "location": ev["location"]
        })
    for ev in upcoming_evs:
        next_events.append({
            "day_badge": f"{ev['day_name'][:3]} {ev['date_str']}",
            "time": ev["time"],
            "title": ev["title"],
            "all_day": ev["all_day"],
            "location": ev.get("location", "")
        })

    month_grid = build_month_grid(now, events_by_date)

    return {
        "today": today_evs,
        "tomorrow": tomorrow_evs,
        "upcoming": upcoming_evs,
        "next_events": next_events[:5],
        "month_grid": month_grid,
        "is_sample": True,
        "status": "sample_events",
        "status_message": "No ICAL_URLS configured in config/.env. Showing sample events.",
        "total_count": len(today_evs) + len(tomorrow_evs),
        "successful_feeds": 0,
    }

async def fetch_calendar_events() -> Dict[str, Any]:
    try:
        target_tz = pytz.timezone(settings.timezone)
    except Exception:
        target_tz = pytz.UTC

    now = datetime.now(target_tz)
    today_date = now.date()

    urls = settings.parsed_ical_urls
    if not urls:
        return _build_sample_response(target_tz)

    # 1. Determine date range for month grid and lookahead
    cal = py_calendar.Calendar(firstweekday=6)
    month_weeks = cal.monthdatescalendar(now.year, now.month)
    grid_start_date = month_weeks[0][0]
    grid_end_date = month_weeks[-1][-1]

    # Lookahead extends at least 14 days ahead of today for next_events
    search_start_date = min(grid_start_date, today_date)
    search_end_date = max(grid_end_date, today_date + timedelta(days=14))

    search_start = target_tz.localize(datetime.combine(search_start_date, time.min))
    search_end = target_tz.localize(datetime.combine(search_end_date, time.max))

    raw_events: List[Dict[str, Any]] = []
    feed_errors: List[str] = []
    successful_feeds = 0

    async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
        for raw_url in urls:
            url = raw_url.strip()
            if url.startswith("webcal://"):
                url = "https://" + url[9:]
            elif not url.startswith("http://") and not url.startswith("https://"):
                url = "https://" + url

            try:
                logger.info(f"Fetching calendar feed: {url[:50]}...")
                resp = await client.get(url, headers={"User-Agent": "Mozilla/5.0 (compatible; KindleTRMNL/1.0)"})

                if resp.status_code != 200:
                    err_msg = f"HTTP {resp.status_code} on feed {url[:40]}..."
                    logger.warning(err_msg)
                    feed_errors.append(err_msg)
                    continue

                if b"BEGIN:VCALENDAR" not in resp.content:
                    err_msg = f"Feed did not return valid iCal data. Make sure to use the 'Secret address in iCal format' ending in .ics"
                    logger.warning(err_msg)
                    feed_errors.append(err_msg)
                    continue

                cal_obj = icalendar.Calendar.from_ical(resp.content)
                cal_name = str(cal_obj.get("X-WR-CALNAME", ""))
                successful_feeds += 1

                # Expand recurring events in full month + lookahead window
                events_in_range = recurring_ical_events.of(cal_obj).between(search_start, search_end)

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
                        "day_name": dt_start.strftime("%A"),
                    })
            except Exception as e:
                err_msg = f"Error processing iCal feed {url[:40]}: {e}"
                logger.error(err_msg)
                feed_errors.append(err_msg)

    if successful_feeds == 0 and feed_errors:
        fallback = _build_sample_response(target_tz)
        fallback["status"] = "error"
        fallback["status_message"] = "; ".join(feed_errors)
        return fallback

    # Sort events by date and time
    raw_events.sort(key=lambda x: (x["start_dt"], 0 if x["all_day"] else 1))

    # Build events_by_date index for month grid
    events_by_date: Dict[date, List[Dict[str, Any]]] = {}
    for ev in raw_events:
        d = ev["event_date"]
        if d not in events_by_date:
            events_by_date[d] = []
        events_by_date[d].append({
            "title": ev["title"],
            "time": ev["time"],
            "all_day": ev["all_day"]
        })

    month_grid = build_month_grid(now, events_by_date)

    # Build today, tomorrow, and sequential next_events
    today_events = []
    tomorrow_events = []
    upcoming_events = []
    next_events = []

    tomorrow_date = today_date + timedelta(days=1)

    for ev in raw_events:
        item = {
            "title": ev["title"],
            "time": ev["time"],
            "all_day": ev["all_day"],
            "location": ev["location"],
            "cal_name": ev.get("cal_name", ""),
            "day_name": ev["day_name"],
            "date_str": ev["event_date"].strftime("%b %d"),
        }
        if ev["event_date"] == today_date:
            today_events.append(item)
            next_events.append({
                "day_badge": "Today",
                "time": ev["time"],
                "title": ev["title"],
                "all_day": ev["all_day"],
                "location": ev["location"]
            })
        elif ev["event_date"] == tomorrow_date:
            tomorrow_events.append(item)
            next_events.append({
                "day_badge": "Tomorrow",
                "time": ev["time"],
                "title": ev["title"],
                "all_day": ev["all_day"],
                "location": ev["location"]
            })
        elif ev["event_date"] > tomorrow_date:
            upcoming_events.append(item)
            next_events.append({
                "day_badge": f"{ev['day_name'][:3]} {item['date_str']}",
                "time": ev["time"],
                "title": ev["title"],
                "all_day": ev["all_day"],
                "location": ev["location"]
            })

    status_str = "connected"
    if feed_errors:
        status_str = f"partial_errors: {'; '.join(feed_errors)}"

    return {
        "today": today_events,
        "tomorrow": tomorrow_events,
        "upcoming": upcoming_events[:4],
        "next_events": next_events[:6],
        "month_grid": month_grid,
        "is_sample": False,
        "status": status_str,
        "total_count": len(today_events) + len(tomorrow_events),
        "successful_feeds": successful_feeds,
    }
