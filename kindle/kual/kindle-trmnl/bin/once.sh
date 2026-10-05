#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Refresh Screen Once
# Strategy: fetch image WHILE KUAL is open (blocking), then render in
# background AFTER KUAL exits so the home screen repaint can't overwrite it.
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

eips 0 35 "==== KINDLE TRMNL ====" 2>/dev/null || true
eips 0 36 "Refresh Screen Once" 2>/dev/null || true
eips 0 37 "" 2>/dev/null || true

# Prevent screensaver while we work and after dashboard renders
lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null || true

# ---------- Step 1: Enable Wi-Fi (blocking) ----------
eips 0 38 "Enabling Wi-Fi..." 2>/dev/null || true
lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null || true

CONNECTED=0
TIMER=0
while [ $TIMER -lt "$WIFI_TIMEOUT" ]; do
    if ifconfig wlan0 2>/dev/null | grep -q "inet"; then
        CONNECTED=1; break
    fi
    sleep 1; TIMER=$((TIMER + 1))
done
# Grace period
if [ $CONNECTED -eq 0 ]; then
    sleep 2
    ifconfig wlan0 2>/dev/null | grep -q "inet" && CONNECTED=1
fi

if [ $CONNECTED -eq 0 ]; then
    eips 0 38 "Error: Wi-Fi timed out (${WIFI_TIMEOUT}s)." 2>/dev/null || true
    eips 0 39 "Check your network settings." 2>/dev/null || true
    lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null || true
    exit 1
fi

eips 0 38 "Wi-Fi connected. Fetching dashboard..." 2>/dev/null || true

# ---------- Step 2: Get device MAC ----------
MAC_ADDR=""
if [ -f /sys/class/net/wlan0/address ]; then
    MAC_ADDR="$(cat /sys/class/net/wlan0/address | tr -d '\r\n')"
fi
if [ -z "$MAC_ADDR" ]; then
    MAC_ADDR="$(lipc-get-prop com.lab126.cmd macAddress 2>/dev/null | tr -d '\r\n')"
fi
[ -z "$MAC_ADDR" ] && MAC_ADDR="kindle-wp63gw"

# ---------- Step 3: Fetch image (blocking, while KUAL is still open) ----------
SCREEN_FILE="/tmp/screen.png"
rm -f "$SCREEN_FILE"

if [ -n "$FOUND_FBINK" ]; then
    FETCH_URL="${SERVER_URL}/api/display?mac=${MAC_ADDR}"
else
    FETCH_URL="${SERVER_URL}/api/display?mac=${MAC_ADDR}&rotate=90"
fi

FETCH_EXIT=1
if command -v curl >/dev/null 2>&1; then
    curl -s -m 15 -o "$SCREEN_FILE" "$FETCH_URL"
    FETCH_EXIT=$?
else
    wget -q -O "$SCREEN_FILE" "$FETCH_URL"
    FETCH_EXIT=$?
fi

# Disable Wi-Fi now that we have the image
lipc-set-prop com.lab126.cmd wirelessEnable 0 2>/dev/null || true

# ---------- Step 4: Launch deferred background render ----------
# KUAL will exit after this script finishes. We give it 3 seconds to close
# and for the home screen to repaint, then we overwrite it with the dashboard.
# E-ink holds whatever eips/fbink last drew, so the dashboard then persists.

if [ $FETCH_EXIT -eq 0 ] && [ -s "$SCREEN_FILE" ]; then
    BYTES="$(wc -c < "$SCREEN_FILE" | tr -d ' ')"
    eips 0 38 "Image ready (${BYTES} bytes)." 2>/dev/null || true
    eips 0 39 "Dashboard appears in ~3 seconds..." 2>/dev/null || true

    if [ -n "$FOUND_FBINK" ]; then
        # fbink handles rotation natively; no need for eips -c first
        FBINK_BIN="$FOUND_FBINK"
        FBINK_ROT="$FBINK_ROTATION"
        SCRF="$SCREEN_FILE"
        nohup sh -c "sleep 3; '$FBINK_BIN' -q -g -c -r '$FBINK_ROT' '$SCRF'" \
            > /tmp/kindle-once.log 2>&1 &
    else
        SCRF="$SCREEN_FILE"
        nohup sh -c "sleep 3; eips -c; sleep 1; eips -g '$SCRF'" \
            > /tmp/kindle-once.log 2>&1 &
    fi
else
    eips 0 38 "Error: failed to download image." 2>/dev/null || true
    eips 0 39 "Server: ${SERVER_URL}" 2>/dev/null || true
    lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null || true
fi

# Script exits here -> KUAL closes (exitmenu: true) -> home screen briefly
# -> background render fires 3s later, dashboard overwrites home screen
# -> dashboard persists (e-ink retains image; screensaver suppressed)
