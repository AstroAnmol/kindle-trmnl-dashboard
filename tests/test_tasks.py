import pytest
from server.services.tasks import _parse_markdown_tasks, _parse_json_tasks

def test_parse_markdown():
    sample_md = """
# Daily Focus
- [ ] Task 1
- [x] Task 2 completed
- Plain note bullet

# Quick Notes
- Buy groceries
"""
    result = _parse_markdown_tasks(sample_md)
    assert len(result["tasks"]) == 3
    assert result["completed_count"] == 1
    assert result["pending_count"] == 2
    assert "Buy groceries" in result["notes"]

def test_parse_json():
    json_data = '[{"text": "Task A", "completed": false}, {"text": "Task B", "completed": true}]'
    result = _parse_json_tasks(json_data)
    assert len(result["tasks"]) == 2
    assert result["completed_count"] == 1
    assert "menu" in result
    assert len(result["menu"]) == 7

def test_parse_weekly_menu():
    sample_md = """
# Focus
- [ ] Task 1

# Notes
- A quick note

# Weekly Menu
- Mon: Pasta
- Tue: Tacos
- Wednesday: Salmon
- Thu: Curry
- Fri: Pizza
- Sat: Burgers
- Sun: Roast
"""
    result = _parse_markdown_tasks(sample_md)
    assert "menu" in result
    assert len(result["menu"]) == 7
    days = [m["day"] for m in result["menu"]]
    assert days == ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    meals = {m["day"]: m["meal"] for m in result["menu"]}
    assert meals["Mon"] == "Pasta"
    assert meals["Tue"] == "Tacos"
    assert meals["Wed"] == "Salmon"
    assert meals["Sun"] == "Roast"