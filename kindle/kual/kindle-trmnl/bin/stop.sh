#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Stop Background Loop
# Terminates the loop, restores the Kindle reader GUI framework, and re-enables
# Wi-Fi and screensaver.
# ==============================================================================

EXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

PID_FILE="/tmp/kindle-trmnl.pid"
LOG_FILE="/tmp/kindle-trmnl.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [STOP] $*" >> "$LOG_FILE"
    echo "[STOP] $*"
}

log "Stopping Kindle TRMNL dashboard..."

# 1. Kill loop by PID
if [ -f "$PID_FILE" ]; then
    PID="$(cat "$PID_FILE" 2>/dev/null)"
    if [ -n "$PID" ]; then
        kill "$PID" 2>/dev/null || true
        sleep 1
        kill -9 "$PID" 2>/dev/null || true
        log "Killed loop PID $PID"
    fi
    rm -f "$PID_FILE"
fi

# 2. Kill any lingering loop or display processes
if command -v pkill >/dev/null 2>&1; then
    pkill -9 -f "loop.sh" 2>/dev/null || true
    pkill -9 -f "display.sh" 2>/dev/null || true
    pkill -9 -f "once.sh" 2>/dev/null || true
else
    killall -9 loop.sh display.sh once.sh 2>/dev/null || true
fi

# 3. Restore Kindle GUI framework (takeover_end)
log "Restoring Kindle reader framework..."
if command -v initctl >/dev/null 2>&1; then
    initctl start framework >/dev/null 2>&1 || initctl start lab126_gui >/dev/null 2>&1 || true
    initctl start webreader >/dev/null 2>&1 || true
elif [ -x /etc/init.d/framework ]; then
    /etc/init.d/framework start >/dev/null 2>&1 || true
fi

# 4. Restore power management and Wi-Fi
lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null || true
lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null || true
if command -v wifid >/dev/null 2>&1; then
    wifid enable >/dev/null 2>&1 || true
fi

log "Kindle restored to normal."

# Quick on-screen feedback
eips 0 38 "TRMNL: Loop stopped." 2>/dev/null || true
eips 0 39 "Kindle framework restored." 2>/dev/null || true
