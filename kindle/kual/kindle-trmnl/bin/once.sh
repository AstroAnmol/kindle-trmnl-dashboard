#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Refresh Screen Once
# Detaches from KUAL, waits for KUAL to exit & Home Screen to settle,
# then connects to Wi-Fi, fetches the dashboard, and renders it to the screen.
# ==============================================================================

EXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Strip Windows carriage returns from all scripts
sed -i -e 's/\r$//' "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true
chmod +x "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true

# Self-detach: run in background immune to SIGHUP so KUAL can exit cleanly first
if [ "$1" != "__run" ]; then
    SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    if command -v setsid >/dev/null 2>&1; then
        setsid /bin/sh "$SCRIPT_PATH" __run </dev/null >/tmp/kindle-once.log 2>&1 &
    else
        /bin/sh "$SCRIPT_PATH" __run </dev/null >/tmp/kindle-once.log 2>&1 &
    fi
    exit 0
fi

# We are in the detached runner process
trap '' HUP

# Wait for KUAL to completely finish unmapping and for Home Screen to settle
sleep 3

# Load configuration
if [ -f "${EXT_DIR}/config.sh" ]; then
    . "${EXT_DIR}/config.sh"
elif [ -f "/mnt/us/extensions/kindle-trmnl/config.sh" ]; then
    . "/mnt/us/extensions/kindle-trmnl/config.sh"
fi

SERVER_URL="${SERVER_URL:-http://10.0.0.219:5055}"
WIFI_TIMEOUT="${WIFI_TIMEOUT:-20}"
FBINK_ROTATION="${FBINK_ROTATION:-1}"
LOG_FILE="${LOG_FILE:-/tmp/kindle-trmnl.log}"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ONCE] $*" >> "$LOG_FILE"
    echo "[ONCE] $*"
}

log "Refreshing screen once..."

# Suppress screensaver while active
lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null || true

# 1. Detect fbink binary
FOUND_FBINK=""
if [ -n "$FBINK_BIN" ] && [ -x "$FBINK_BIN" ]; then
    FOUND_FBINK="$FBINK_BIN"
elif [ -x "${EXT_DIR}/bin/fbink" ]; then
    FOUND_FBINK="${EXT_DIR}/bin/fbink"
elif command -v fbink >/dev/null 2>&1; then
    FOUND_FBINK="$(command -v fbink)"
elif [ -x "/usr/bin/fbink" ]; then
    FOUND_FBINK="/usr/bin/fbink"
elif [ -x "/mnt/us/bin/fbink" ]; then
    FOUND_FBINK="/mnt/us/bin/fbink"
elif [ -x "/mnt/us/libkh/bin/fbink" ]; then
    FOUND_FBINK="/mnt/us/libkh/bin/fbink"
elif [ -x "/mnt/us/extensions/MRInstaller/bin/fbink" ]; then
    FOUND_FBINK="/mnt/us/extensions/MRInstaller/bin/fbink"
elif [ -x "/mnt/us/kual/bin/fbink" ]; then
    FOUND_FBINK="/mnt/us/kual/bin/fbink"
fi

# 2. Turn ON Wi-Fi
log "Enabling Wi-Fi..."
lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null || true
if command -v wifid >/dev/null 2>&1; then
    wifid enable >/dev/null 2>&1 || true
fi

CONNECTED=0
TIMER=0
while [ $TIMER -lt "$WIFI_TIMEOUT" ]; do
    if ifconfig wlan0 2>/dev/null | grep -q "inet" || ifconfig | grep -q "inet addr:[0-9]"; then
        CONNECTED=1
        break
    fi
    sleep 1
    TIMER=$((TIMER + 1))
done

if [ $CONNECTED -eq 0 ]; then
    sleep 2
    if ifconfig 2>/dev/null | grep -q "inet"; then
        CONNECTED=1
    fi
fi

if [ $CONNECTED -eq 0 ]; then
    log "ERROR: Wi-Fi connection timed out (${WIFI_TIMEOUT}s)."
    lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null || true
    exit 1
fi

log "Wi-Fi connected in ${TIMER}s."

# 3. Detect MAC Address
MAC_ADDR=""
if [ -f /sys/class/net/wlan0/address ]; then
    MAC_ADDR="$(cat /sys/class/net/wlan0/address | tr -d '\r\n')"
fi
if [ -z "$MAC_ADDR" ]; then
    MAC_ADDR="$(lipc-get-prop com.lab126.cmd macAddress 2>/dev/null | tr -d '\r\n')"
fi
[ -z "$MAC_ADDR" ] && MAC_ADDR="kindle-wp63gw"

# 4. Fetch Display Image
SCREEN_FILE="/tmp/screen.png"
rm -f "$SCREEN_FILE"

if [ -n "$FOUND_FBINK" ]; then
    FETCH_URL="${SERVER_URL}/api/display?mac=${MAC_ADDR}"
else
    FETCH_URL="${SERVER_URL}/api/display?mac=${MAC_ADDR}&rotate=90"
fi

log "Fetching image from ${FETCH_URL}..."

FETCH_EXIT=1
if command -v curl >/dev/null 2>&1; then
    curl -s -m 20 -o "$SCREEN_FILE" "$FETCH_URL"
    FETCH_EXIT=$?
elif command -v wget >/dev/null 2>&1; then
    wget -q -T 20 -O "$SCREEN_FILE" "$FETCH_URL"
    FETCH_EXIT=$?
fi

# Turn OFF Wi-Fi immediately to save battery
log "Disabling Wi-Fi..."
lipc-set-prop com.lab126.cmd wirelessEnable 0 2>/dev/null || true

# 5. Render to Screen
if [ $FETCH_EXIT -eq 0 ] && [ -s "$SCREEN_FILE" ]; then
    log "Image downloaded successfully ($(wc -c < "$SCREEN_FILE") bytes)."
    if [ -n "$FOUND_FBINK" ]; then
        log "Drawing with fbink (rotation: $FBINK_ROTATION)..."
        "$FOUND_FBINK" -q -g -c -r "$FBINK_ROTATION" "$SCREEN_FILE"
    elif command -v eips >/dev/null 2>&1; then
        log "Drawing with native eips..."
        eips -c
        sleep 1
        eips -g "$SCREEN_FILE"
    fi
    log "Display refresh complete."
else
    log "ERROR: Failed to download display image (Exit: $FETCH_EXIT)."
fi
