#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Stop Background Loop
# ==============================================================================
PID_FILE="/tmp/kindle-trmnl.pid"

if [ -f "$PID_FILE" ]; then
    PID="$(cat "$PID_FILE")"
    kill "$PID" 2>/dev/null || true
    rm -f "$PID_FILE"
fi

killall -9 display.sh loop.sh 2>/dev/null || true

lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null || true
lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null || true

eips 0 39 "TRMNL: Loop stopped. Wi-Fi restored." 2>/dev/null || true
