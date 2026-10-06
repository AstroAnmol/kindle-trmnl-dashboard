#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Start Background Loop
# Detaches from KUAL, stops the Kindle reader framework (so nothing repaints
# over the dashboard), and starts the background refresh loop.
# ==============================================================================

EXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Strip Windows carriage returns from all scripts
sed -i -e 's/\r$//' "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true
chmod +x "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true

# Self-detach so KUAL can close cleanly without killing our loop
if [ "$1" != "__run" ]; then
    SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    if command -v setsid >/dev/null 2>&1; then
        setsid /bin/sh "$SCRIPT_PATH" __run </dev/null >/tmp/kindle-start.log 2>&1 &
    else
        /bin/sh "$SCRIPT_PATH" __run </dev/null >/tmp/kindle-start.log 2>&1 &
    fi
    exit 0
fi

trap '' HUP

# Wait for KUAL to finish closing
sleep 3

# Load configuration
if [ -f "${EXT_DIR}/config.sh" ]; then
    . "${EXT_DIR}/config.sh"
elif [ -f "/mnt/us/extensions/kindle-trmnl/config.sh" ]; then
    . "/mnt/us/extensions/kindle-trmnl/config.sh"
fi

PID_FILE="/tmp/kindle-trmnl.pid"
LOG_FILE="${LOG_FILE:-/tmp/kindle-trmnl.log}"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [START] $*" >> "$LOG_FILE"
    echo "[START] $*"
}

# Check if already running
if [ -f "$PID_FILE" ]; then
    OLD_PID="$(cat "$PID_FILE" 2>/dev/null)"
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        log "Loop already running with PID $OLD_PID."
        exit 0
    fi
    rm -f "$PID_FILE"
fi

# Stop Kindle reader framework to take over screen (matches kindle-dash and jstriblet)
log "Taking over screen: stopping reader framework..."
if command -v initctl >/dev/null 2>&1; then
    initctl stop framework >/dev/null 2>&1 || initctl stop lab126_gui >/dev/null 2>&1 || true
    initctl stop webreader >/dev/null 2>&1 || true
elif [ -x /etc/init.d/framework ]; then
    /etc/init.d/framework stop >/dev/null 2>&1 || true
fi

# Prevent screensaver
lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null || true

# Locate loop.sh
LOOP_SCRIPT=""
if [ -f "${EXT_DIR}/loop.sh" ]; then
    LOOP_SCRIPT="${EXT_DIR}/loop.sh"
elif [ -f "/mnt/us/extensions/kindle-trmnl/loop.sh" ]; then
    LOOP_SCRIPT="/mnt/us/extensions/kindle-trmnl/loop.sh"
elif [ -f "/mnt/us/kindle-trmnl-dashboard/kindle/loop.sh" ]; then
    LOOP_SCRIPT="/mnt/us/kindle-trmnl-dashboard/kindle/loop.sh"
fi

if [ -n "$LOOP_SCRIPT" ]; then
    log "Launching loop script: $LOOP_SCRIPT"
    if command -v setsid >/dev/null 2>&1; then
        setsid /bin/sh "$LOOP_SCRIPT" </dev/null >> "$LOG_FILE" 2>&1 &
    else
        /bin/sh "$LOOP_SCRIPT" </dev/null >> "$LOG_FILE" 2>&1 &
    fi
    sleep 2
    if [ -f "$PID_FILE" ]; then
        log "Dashboard loop started successfully (PID $(cat "$PID_FILE"))."
    else
        log "Dashboard loop launched."
    fi
else
    log "ERROR: loop.sh not found!"
fi
