import os
import re
import json
import time
import logging
from typing import Dict, Any, List, Optional
from server.config import settings

logger = logging.getLogger(__name__)

DEFAULT_TASKS = [
    {"text": "Complete Kindle TRMNL dashboard setup", "completed": False, "due": "Today"},
    {"text": "Review upcoming week calendar events", "completed": False, "due": "Today"},
    {"text": "Configure Open-Meteo weather coordinates", "completed": True, "due": "Done"},
    {"text": "Charge Kindle e-reader battery", "completed": False, "due": "Tomorrow"},
    {"text": "Water indoor plants", "completed": False, "due": "This week"}
]

# Google Keep In-Memory Cache
_keep_instance: Optional[Any] = None
_keep_last_sync: float = 0.0
_keep_cache: Optional[Dict[str, Any]] = None
KEEP_SYNC_INTERVAL = 300  # 5 minutes

def _fetch_google_keep_tasks() -> Optional[Dict[str, Any]]:
    """Fetches checklist items from Google Keep if credentials are configured."""
    global _keep_instance, _keep_last_sync, _keep_cache

    if not settings.google_keep_email or not settings.google_keep_password:
        return None

    now_ts = time.time()
    if _keep_cache and (now_ts - _keep_last_sync < KEEP_SYNC_INTERVAL):
        return _keep_cache

    try:
        import gkeepapi
        if _keep_instance is None:
            _keep_instance = gkeepapi.Keep()
            logger.info("Authenticating with Google Keep...")
            _keep_instance.login(settings.google_keep_email, settings.google_keep_password)
        else:
            _keep_instance.sync()

        # Find matching note by title
        target_title = settings.google_keep_note_title.strip().lower()
        matched_notes = [
            n for n in _keep_instance.all()
            if n.title and n.title.strip().lower() == target_title
        ]

        if not matched_notes:
            # If no exact title match, search for pinned list notes
            matched_notes = [n for n in _keep_instance.all() if n.pinned and isinstance(n, gkeepapi.node.List)]

        if not matched_notes:
            logger.info(f"No Google Keep note found matching title: '{settings.google_keep_note_title}'")
            return None

        note = matched_notes[0]
        tasks: List[Dict[str, Any]] = []
        notes_list: List[str] = []

        # Extract list items
        if isinstance(note, gkeepapi.node.List):
            for item in note.items:
                if item.text:
                    tasks.append({
                        "text": item.text.strip(),
                        "completed": bool(item.checked)
                    })
        elif hasattr(note, "text") and note.text:
            # Text note fallback: parse markdown-style checkboxes
            return _parse_markdown_tasks(note.text)

        completed_count = sum(1 for t in tasks if t.get("completed"))
        result = {
            "tasks": tasks,
            "notes": [f"Synced from Google Keep ({note.title})"],
            "completed_count": completed_count,
            "pending_count": len(tasks) - completed_count,
            "total": len(tasks),
            "source": "google_keep"
        }

        _keep_cache = result
        _keep_last_sync = now_ts
        logger.info(f"Successfully synced {len(tasks)} tasks from Google Keep ('{note.title}')")
        return result

    except Exception as e:
        logger.warning(f"Google Keep sync error: {e}. Falling back to local tasks.")
        return None

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
        "total": len(tasks),
        "source": "local_markdown"
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
                "total": len(tasks),
                "source": "local_json"
            }
    except Exception as e:
        logger.error(f"Error parsing JSON tasks: {e}")

    return {
        "tasks": list(DEFAULT_TASKS),
        "notes": [],
        "completed_count": 1,
        "pending_count": 4,
        "total": 5,
        "source": "default"
    }

def fetch_tasks_and_notes() -> Dict[str, Any]:
    # 1. Attempt Google Keep fetch if configured
    keep_result = _fetch_google_keep_tasks()
    if keep_result and keep_result.get("tasks"):
        return keep_result

    # 2. Local tasks file (tasks.md or tasks.json)
    task_file = settings.tasks_file_path
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

    # 3. Fallback to config/tasks.json if tasks.md does not exist
    json_fallback = "config/tasks.json"
    if os.path.exists(json_fallback):
        try:
            with open(json_fallback, "r", encoding="utf-8") as f:
                return _parse_json_tasks(f.read())
        except Exception:
            pass

    # 4. Built-in defaults
    return {
        "tasks": list(DEFAULT_TASKS),
        "notes": ["Welcome to your Kindle TRMNL dashboard!"],
        "completed_count": 1,
        "pending_count": 4,
        "total": 5,
        "source": "default"
    }