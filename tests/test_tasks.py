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