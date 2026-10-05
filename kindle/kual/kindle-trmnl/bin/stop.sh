#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Stop Background Loop
# ==============================================================================

PID_FILE="/tmp/kindle-trmnl.pid"
KILLED=0

eips -c 2>/dev/null || true
sleep 1

eips 0 0 "==== KINDLE TRMNL ====" 2>/dev/null || true
eips 0 1 "Stop Dashboard Loop" 2>/dev/null || true
eips 0 2 "" 2>/dev/null || true

# 1. Kill by PID file
if [ -f "$PID_FILE" ]; then
    PID="$(cat "$PID_FILE")"
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null || true
        sleep 1
        kill -9 "$PID" 2>/dev/null || true
        eips 0 3 "Killed loop PID: ${PID}" 2>/dev/null || true
        KILLED=1
    else
        eips 0 3 "Stale PID file (${PID}) - removing" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
else
    eips 0 3 "No PID file found." 2>/dev/null || true
fi

# 2. Kill any lingering loop.sh / display.sh processes by name
# busybox killall matches the argv[0] of the process (typically 'sh')
# so we use pkill -f if available, else killall on the script names
if command -v pkill >/dev/null 2>&1; then
    pkill -9 -f "loop.sh" 2>/dev/null && KILLED=1 || true
    pkill -9 -f "display.sh" 2>/dev/null && KILLED=1 || true
else
    killall -9 loop.sh display.sh 2>/dev/null && KILLED=1 || true
fi

# 3. Kill any stuck wget or curl (from a hung display.sh fetch)
pkill -9 -f "wget" 2>/dev/null || killall -9 wget 2>/dev/null || true
pkill -9 -f "curl" 2>/dev/null || killall -9 curl 2>/dev/null || true

# 4. Restore normal Kindle behaviour
lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null || true
lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null || true

eips 0 4 "" 2>/dev/null || true

if [ $KILLED -eq 1 ]; then
    eips 0 5 "Loop stopped successfully." 2>/dev/null || true
else
    eips 0 5 "No loop was running." 2>/dev/null || true
fi

eips 0 6 "Wi-Fi re-enabled." 2>/dev/null || true
eips 0 7 "Screen saver re-enabled." 2>/dev/null || true
eips 0 8 "" 2>/dev/null || true
eips 0 9 "Tap Back or anywhere to return." 2>/dev/null || true
