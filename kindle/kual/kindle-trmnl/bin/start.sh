#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Start Background Loop
# Renders the first dashboard frame immediately, starts the background loop,
# and keeps KUAL ready so touching the screen returns to the KUAL menu.
# ==============================================================================

EXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Strip Windows carriage returns from all scripts
sed -i -e 's/\r$//' "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true
chmod +x "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true

PID_FILE="/tmp/kindle-trmnl.pid"

# Check if loop is already running
if [ -f "$PID_FILE" ]; then
    OLD_PID="$(cat "$PID_FILE" 2>/dev/null)"
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        eips 0 38 "TRMNL: Loop already running (PID $OLD_PID)" 2>/dev/null || true
        eips 0 39 "Stop it first before restarting." 2>/dev/null || true
        exit 0
    fi
    rm -f "$PID_FILE"
fi

eips 0 37 "=== Kindle TRMNL ===" 2>/dev/null || true
eips 0 38 "Starting background loop..." 2>/dev/null || true
eips 0 39 "Rendering first update now..." 2>/dev/null || true

# Prevent screensaver while running loop
lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null || true

# Render first frame immediately
DISPLAY_SCRIPT="${EXT_DIR}/display.sh"
[ ! -f "$DISPLAY_SCRIPT" ] && DISPLAY_SCRIPT="/mnt/us/extensions/kindle-trmnl/display.sh"

if [ -f "$DISPLAY_SCRIPT" ]; then
    sh "$DISPLAY_SCRIPT"
fi

# Locate loop.sh and start it in background
LOOP_SCRIPT="${EXT_DIR}/loop.sh"
[ ! -f "$LOOP_SCRIPT" ] && LOOP_SCRIPT="/mnt/us/extensions/kindle-trmnl/loop.sh"

if [ -f "$LOOP_SCRIPT" ]; then
    sh "$LOOP_SCRIPT" >/tmp/kindle-loop.log 2>&1 &
    sleep 1
fi
