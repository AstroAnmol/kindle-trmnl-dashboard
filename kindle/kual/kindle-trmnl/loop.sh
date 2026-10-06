#!/bin/sh
# ==============================================================================
# Kindle Continuous Background Loop: kindle-trmnl-dashboard
# Run in background on Kindle or via KUAL extension
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="/tmp/kindle-trmnl.pid"
LOG_FILE="/tmp/kindle-trmnl.log"

echo $$ > "$PID_FILE"

cleanup() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [LOOP] Stopping loop (PID: $$)..." >> "$LOG_FILE"
    rm -f "$PID_FILE"
    exit 0
}

trap cleanup INT TERM
# Crucial: ignore SIGHUP so KUAL session closure cannot kill this loop
trap '' HUP

echo "$(date '+%Y-%m-%d %H:%M:%S') [LOOP] Started Kindle TRMNL Dashboard loop (PID: $$)" >> "$LOG_FILE"

while true; do
    sh "${SCRIPT_DIR}/display.sh" --sleep
    sleep 2
done
