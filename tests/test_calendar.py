import pytest
from datetime import datetime, date, time
import pytz
from server.services.calendar import _format_time, _to_tz_datetime, SAMPLE_EVENTS, fetch_calendar_events

def test_format_time():
    tz = pytz.timezone("America/New_York")
    dt1 = tz.localize(datetime(2026, 10, 5, 9, 30))
    dt2 = tz.localize(datetime(2026, 10, 5, 11, 0))
    
    assert _format_time(dt1, dt2, False) == "9:30 AM - 11:00 AM"
    assert _format_time(dt1, None, False) == "9:30 AM"
    assert _format_time(dt1, dt2, True) == "All Day"

def test_to_tz_datetime():
    tz = pytz.timezone("America/New_York")
    d = date(2026, 10, 5)
    dt = _to_tz_datetime(d, tz)
    assert dt.tzinfo is not None
    assert dt.date() == d

@pytest.mark.asyncio
async def test_fetch_calendar_events_sample():
    res = await fetch_calendar_events()
    assert "today" in res
    assert "tomorrow" in res
    assert len(res["today"]) > 0