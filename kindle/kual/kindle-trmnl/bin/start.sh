#!/bin/sh
BASE_DIR="/mnt/us/kindle-trmnl-dashboard"
if [ ! -d "$BASE_DIR" ]; then
    BASE_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
fi

PID_FILE="/tmp/kindle-trmnl.pid"
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    exit 0
fi

nohup sh "${BASE_DIR}/loop.sh" >/dev/null 2>&1 &