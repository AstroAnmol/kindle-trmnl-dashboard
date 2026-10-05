#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Start Background Loop
# ==============================================================================

EXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Self-heal: strip Windows carriage returns from all scripts
sed -i -e 's/\r$//' "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true
chmod +x "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true

PID_FILE="/tmp/kindle-trmnl.pid"

eips 0 35 "==== KINDLE TRMNL ====" 2>/dev/null || true
eips 0 36 "Start Dashboard Loop" 2>/dev/null || true
eips 0 37 "" 2>/dev/null || true

# Check if already running
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    RUNNING_PID="$(cat "$PID_FILE")"
    eips 0 38 "Loop already running!" 2>/dev/null || true
    eips 0 39 "PID: ${RUNNING_PID}. Stop it first." 2>/dev/null || true
    exit 0
fi

# Remove any stale PID file
rm -f "$PID_FILE"

# Locate loop.sh
LOOP_SCRIPT=""
if [ -f "${EXT_DIR}/loop.sh" ]; then
    LOOP_SCRIPT="${EXT_DIR}/loop.sh"
elif [ -f "/mnt/us/extensions/kindle-trmnl/loop.sh" ]; then
    LOOP_SCRIPT="/mnt/us/extensions/kindle-trmnl/loop.sh"
elif [ -f "/mnt/us/kindle-trmnl-dashboard/kindle/kual/kindle-trmnl/loop.sh" ]; then
    LOOP_SCRIPT="/mnt/us/kindle-trmnl-dashboard/kindle/kual/kindle-trmnl/loop.sh"
fi

if [ -n "$LOOP_SCRIPT" ]; then
    eips 0 37 "Launching loop..." 2>/dev/null || true
    eips 0 38 "${LOOP_SCRIPT}" 2>/dev/null || true

    nohup sh "$LOOP_SCRIPT" > /tmp/kindle-loop.log 2>&1 &

    # Wait a moment for the loop to write its PID file
    sleep 2

    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        STARTED_PID="$(cat "$PID_FILE")"
        eips 0 37 "Loop started! PID: ${STARTED_PID}" 2>/dev/null || true
        eips 0 38 "Dashboard will refresh every cycle." 2>/dev/null || true
        eips 0 39 "First refresh starts now..." 2>/dev/null || true
    else
        eips 0 37 "WARNING: Loop may not have started." 2>/dev/null || true
        eips 0 38 "Check /tmp/kindle-loop.log" 2>/dev/null || true
        eips 0 39 "Log: $(tail -1 /tmp/kindle-loop.log 2>/dev/null | cut -c1-42)" 2>/dev/null || true
    fi
else
    eips 0 37 "ERROR: loop.sh not found!" 2>/dev/null || true
    eips 0 38 "Expected path:" 2>/dev/null || true
    eips 0 39 "${EXT_DIR}/loop.sh" 2>/dev/null || true
fi
