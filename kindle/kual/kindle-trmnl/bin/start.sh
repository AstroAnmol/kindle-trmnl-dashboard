#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Start Background Loop
# Strategy: fetch the first dashboard frame synchronously (user sees progress),
# launch a deferred render for 3s after KUAL exits, then start the background
# loop for subsequent periodic refreshes.
# ==============================================================================

EXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Self-heal: strip Windows carriage returns from all scripts
sed -i -e 's/\r$//' "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true
chmod +x "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true

# Load config
if [ -f "${EXT_DIR}/config.sh" ]; then
    . "${EXT_DIR}/config.sh"
elif [ -f "/mnt/us/extensions/kindle-trmnl/config.sh" ]; then
    . "/mnt/us/extensions/kindle-trmnl/config.sh"
fi

SERVER_URL="${SERVER_URL:-http://10.0.0.219:5055}"
WIFI_TIMEOUT="${WIFI_TIMEOUT:-20}"
FBINK_ROTATION="${FBINK_ROTATION:-1}"
PID_FILE="/tmp/kindle-trmnl.pid"

# Detect fbink
FOUND_FBINK=""
if [ -x "${EXT_DIR}/bin/fbink" ]; then
    FOUND_FBINK="${EXT_DIR}/bin/fbink"
elif command -v fbink >/dev/null 2>&1; then
    FOUND_FBINK="$(command -v fbink)"
elif [ -x "/usr/bin/fbink" ]; then
    FOUND_FBINK="/usr/bin/fbink"
elif [ -x "/mnt/us/bin/fbink" ]; then
    FOUND_FBINK="/mnt/us/bin/fbink"
elif [ -x "/mnt/us/extensions/MRInstaller/bin/fbink" ]; then
    FOUND_FBINK="/mnt/us/extensions/MRInstaller/bin/fbink"
fi

eips 0 34 "==== KINDLE TRMNL ====" 2>/dev/null || true
eips 0 35 "Start Dashboard Loop" 2>/dev/null || true
eips 0 36 "" 2>/dev/null || true

# Guard: already running?
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    RPID="$(cat "$PID_FILE")"
    eips 0 37 "Loop already running (PID $RPID)." 2>/dev/null || true
    eips 0 38 "Stop it first before restarting." 2>/dev/null || true
    exit 0
fi
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

if [ -z "$LOOP_SCRIPT" ]; then
    eips 0 37 "Error: loop.sh not found!" 2>/dev/null || true
    eips 0 38 "Expected: ${EXT_DIR}/loop.sh" 2>/dev/null || true
    exit 1
fi

# Prevent screensaver
lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null || true

# ---------- Step 1: Enable Wi-Fi & fetch first frame (blocking) ----------
eips 0 37 "Enabling Wi-Fi for first refresh..." 2>/dev/null || true
lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null || true

CONNECTED=0; TIMER=0
while [ $TIMER -lt "$WIFI_TIMEOUT" ]; do
    if ifconfig wlan0 2>/dev/null | grep -q "inet"; then CONNECTED=1; break; fi
    sleep 1; TIMER=$((TIMER + 1))
done
[ $CONNECTED -eq 0 ] && sleep 2
[ $CONNECTED -eq 0 ] && ifconfig wlan0 2>/dev/null | grep -q "inet" && CONNECTED=1

SCREEN_FILE="/tmp/screen.png"

if [ $CONNECTED -eq 1 ]; then
    eips 0 37 "Downloading first frame..." 2>/dev/null || true

    MAC_ADDR=""
    [ -f /sys/class/net/wlan0/address ] && MAC_ADDR="$(cat /sys/class/net/wlan0/address | tr -d '\r\n')"
    [ -z "$MAC_ADDR" ] && MAC_ADDR="$(lipc-get-prop com.lab126.cmd macAddress 2>/dev/null | tr -d '\r\n')"
    [ -z "$MAC_ADDR" ] && MAC_ADDR="kindle-wp63gw"

    rm -f "$SCREEN_FILE"
    if [ -n "$FOUND_FBINK" ]; then
        FETCH_URL="${SERVER_URL}/api/display?mac=${MAC_ADDR}"
    else
        FETCH_URL="${SERVER_URL}/api/display?mac=${MAC_ADDR}&rotate=90"
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -s -m 15 -o "$SCREEN_FILE" "$FETCH_URL"
    else
        wget -q -O "$SCREEN_FILE" "$FETCH_URL"
    fi

    lipc-set-prop com.lab126.cmd wirelessEnable 0 2>/dev/null || true
else
    eips 0 37 "Wi-Fi unavailable - loop will try on next cycle." 2>/dev/null || true
    lipc-set-prop com.lab126.cmd wirelessEnable 0 2>/dev/null || true
fi

# ---------- Step 2: Start background loop ----------
nohup sh "$LOOP_SCRIPT" > /tmp/kindle-loop.log 2>&1 &
sleep 1

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    STARTED_PID="$(cat "$PID_FILE")"
    eips 0 38 "Loop started (PID $STARTED_PID)." 2>/dev/null || true
else
    eips 0 38 "Warning: loop may not have started." 2>/dev/null || true
fi

# ---------- Step 3: Deferred render of first frame ----------
# KUAL exits after this script. We fire the render 3s later so the
# home-screen repaint has settled and our eips write persists on screen.
if [ -s "$SCREEN_FILE" ]; then
    BYTES="$(wc -c < "$SCREEN_FILE" | tr -d ' ')"
    eips 0 39 "Dashboard appears in ~3s (${BYTES} bytes ready)" 2>/dev/null || true

    if [ -n "$FOUND_FBINK" ]; then
        FBINK_BIN="$FOUND_FBINK"
        FBINK_ROT="$FBINK_ROTATION"
        SCRF="$SCREEN_FILE"
        nohup sh -c "sleep 3; '$FBINK_BIN' -q -g -c -r '$FBINK_ROT' '$SCRF'" \
            > /tmp/kindle-start.log 2>&1 &
    else
        SCRF="$SCREEN_FILE"
        nohup sh -c "sleep 3; eips -c; sleep 1; eips -g '$SCRF'" \
            > /tmp/kindle-start.log 2>&1 &
    fi
else
    eips 0 39 "Loop running - first refresh coming via loop." 2>/dev/null || true
fi

# Script exits -> KUAL closes -> home screen briefly -> deferred render fires
# -> dashboard persists. Loop then keeps refreshing every cycle.
