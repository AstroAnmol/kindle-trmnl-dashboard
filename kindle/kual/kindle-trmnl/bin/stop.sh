#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Stop Background Loop
# ==============================================================================

PID_FILE="/tmp/kindle-trmnl.pid"

if [ -f "$PID_FILE" ]; then
    PID="$(cat "$PID_FILE" 2>/dev/null)"
    if [ -n "$PID" ]; then
        kill "$PID" 2>/dev/null || true
        sleep 1
        kill -9 "$PID" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
fi

if command -v pkill >/dev/null 2>&1; then
    pkill -9 -f "loop.sh" 2>/dev/null || true
    pkill -9 -f "display.sh" 2>/dev/null || true
else
    killall -9 loop.sh display.sh 2>/dev/null || true
fi

lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null || true
lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null || true

eips 0 38 "TRMNL: Dashboard loop stopped." 2>/dev/null || true
eips 0 39 "Normal Kindle settings restored." 2>/dev/null || true
