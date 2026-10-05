#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Start Background Loop
# ==============================================================================
eips 0 39 "TRMNL: Starting background loop..." 2>/dev/null || true

EXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

sed -i -e 's/\r$//' "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true
chmod +x "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true

PID_FILE="/tmp/kindle-trmnl.pid"

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    eips 0 39 "TRMNL: Loop already running (PID $(cat "$PID_FILE"))" 2>/dev/null || true
    exit 0
fi

LOOP_SCRIPT=""
if [ -f "${EXT_DIR}/loop.sh" ]; then
    LOOP_SCRIPT="${EXT_DIR}/loop.sh"
elif [ -f "/mnt/us/extensions/kindle-trmnl/loop.sh" ]; then
    LOOP_SCRIPT="/mnt/us/extensions/kindle-trmnl/loop.sh"
fi

if [ -n "$LOOP_SCRIPT" ]; then
    nohup sh "$LOOP_SCRIPT" >/tmp/kindle-loop.log 2>&1 &
    sleep 1
    eips 0 39 "TRMNL: Dashboard loop started!" 2>/dev/null || true
else
    eips 0 39 "TRMNL Error: loop.sh not found!" 2>/dev/null || true
fi
