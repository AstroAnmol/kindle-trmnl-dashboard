import os
import re
import json
import logging
from typing import Dict, Any, List
from server.config import settings

logger = logging.getLogger(__name__)

DEFAULT_TASKS = [
    {"text": "Complete Kindle TRMNL dashboard setup", "completed": False, "due": "Today"},
    {"text": "Review upcoming week calendar events", "completed": False, "due": "Today"},
    {"text": "Configure Open-Meteo weather coordinates", "completed": True, "due": "Done"},
    {"text": "Charge Kindle e-reader battery", "completed": False, "due": "Tomorrow"},
    {"text": "Water indoor plants", "completed": False, "due": "This week"}
]

def _parse_markdown_tasks(content: str) -> Dict[str, Any]:
    tasks: List[Dict[str, Any]] = []
    notes: List[str] = []
    current_section = "tasks"

    for line in content.splitlines():
        trimmed = line.strip()
        if not trimmed:
            continue

        if trimmed.startswith("#"):
            header_lower = trimmed.lower()
            if "note" in header_lower or "quick" in header_lower:
                current_section = "notes"
            else:
                current_section = "tasks"
            continue

        # Checkbox regex: - [ ] or - [x]
        checkbox_match = re.match(r"^[-*]\s*\[([ xX])\]\s*(.*)$", trimmed)
        if checkbox_match:
            is_done = checkbox_match.group(1).lower() == "x"
            task_text = checkbox_match.group(2).strip()
            if task_text:
                tasks.append({"text": task_text, "completed": is_done})
            continue

        # Plain bullet point: - ...
        bullet_match = re.match(r"^[-*]\s*(.*)$", trimmed)
        if bullet_match:
            item_text = bullet_match.group(1).strip()
            if current_section == "notes":
                notes.append(item_text)
            else:
                tasks.append({"text": item_text, "completed": False})

    completed_count = sum(1 for t in tasks if t.get("completed"))
    pending_count = len(tasks) - completed_count

    return {
        "tasks": tasks,
        "notes": notes,
        "completed_count": completed_count,
        "pending_count": pending_count,
        "total": len(tasks)
    }

def _parse_json_tasks(content: str) -> Dict[str, Any]:
    try:
        raw_list = json.loads(content)
        if isinstance(raw_list, list):
            tasks = []
            for item in raw_list:
                if isinstance(item, dict) and "text" in item:
                    tasks.append({
                        "text": str(item.get("text", "")),
                        "completed": bool(item.get("completed", False)),
                        "due": str(item.get("due", "")) if item.get("due") else ""
                    })
            completed_count = sum(1 for t in tasks if t.get("completed"))
            return {
                "tasks": tasks,
                "notes": [],
                "completed_count": completed_count,
                "pending_count": len(tasks) - completed_count,
                "total": len(tasks)
            }
    except Exception as e:
        logger.error(f"Error parsing JSON tasks: {e}")

    return {
        "tasks": list(DEFAULT_TASKS),
        "notes": [],
        "completed_count": 1,
        "pending_count": 4,
        "total": 5
    }

def fetch_tasks_and_notes() -> Dict[str, Any]:
    task_file = settings.tasks_file_path
    
    # Check if Google Tasks credentials are provided
    if settings.google_tasks_credentials_file and os.path.exists(settings.google_tasks_credentials_file):
        try:
            # Placeholder hook for Google Tasks API if credentials present
            pass
        except Exception as e:
            logger.warning(f"Google Tasks fetch failed: {e}. Falling back to local file.")

    if os.path.exists(task_file):
        try:
            with open(task_file, "r", encoding="utf-8") as f:
                content = f.read()

            if task_file.endswith(".json"):
                return _parse_json_tasks(content)
            else:
                return _parse_markdown_tasks(content)
        except Exception as e:
            logger.error(f"Failed to read task file {task_file}: {e}")

    # Fallback to tasks.json if tasks.md does not exist
    json_fallback = "config/tasks.json"
    if os.path.exists(json_fallback):
        try:
            with open(json_fallback, "r", encoding="utf-8") as f:
                return _parse_json_tasks(f.read())
        except Exception:
            pass

    return {
        "tasks": list(DEFAULT_TASKS),
        "notes": ["Welcome to your Kindle TRMNL dashboard!"],
        "completed_count": 1,
        "pending_count": 4,
        "total": 5
    }