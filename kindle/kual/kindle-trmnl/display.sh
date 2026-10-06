#!/bin/sh
# ==============================================================================
# Kindle Client Script: kindle-trmnl-dashboard
# Optimized for: Kindle WP63GW (7th Gen Basic - KT2 / Touch 2)
# Compatible with: native eips (built-in) and fbink (NiLuJe)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Auto-strip Windows carriage returns if any
sed -i -e 's/\r$//' "${SCRIPT_DIR}"/*.sh "${SCRIPT_DIR}/bin"/*.sh 2>/dev/null || true

# Locate config.sh
if [ -f "${SCRIPT_DIR}/config.sh" ]; then
    . "${SCRIPT_DIR}/config.sh"
elif [ -f "/mnt/us/extensions/kindle-trmnl/config.sh" ]; then
    . "/mnt/us/extensions/kindle-trmnl/config.sh"
fi

SERVER_URL="${SERVER_URL:-http://10.0.0.219:5055}"
DEFAULT_INTERVAL="${DEFAULT_INTERVAL:-900}"
FBINK_ROTATION="${FBINK_ROTATION:-1}"
WIFI_TIMEOUT="${WIFI_TIMEOUT:-15}"
LOW_BATTERY_THRESHOLD="${LOW_BATTERY_THRESHOLD:-10}"
LOG_FILE="${LOG_FILE:-/tmp/kindle-trmnl.log}"

# Check if run with --sleep (e.g. from background loop)
SLEEP_MODE=0
if [ "$1" = "--sleep" ] || [ "$LOOP_MODE" = "1" ]; then
    SLEEP_MODE=1
fi

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [TRMNL] $*" >> "$LOG_FILE"
    echo "[TRMNL] $*"
}

# ------------------------------------------------------------------------------
# 1. Detect fbink binary
# ------------------------------------------------------------------------------
FOUND_FBINK=""
if [ -n "$FBINK_BIN" ] && [ -x "$FBINK_BIN" ]; then
    FOUND_FBINK="$FBINK_BIN"
elif [ -x "${SCRIPT_DIR}/bin/fbink" ]; then
    FOUND_FBINK="${SCRIPT_DIR}/bin/fbink"
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

# ------------------------------------------------------------------------------
# 2. Detect Device MAC Address
# ------------------------------------------------------------------------------
MAC_ADDR=""
if [ -f /sys/class/net/wlan0/address ]; then
    MAC_ADDR="$(cat /sys/class/net/wlan0/address | tr -d '\r\n')"
fi
if [ -z "$MAC_ADDR" ]; then
    MAC_ADDR="$(lipc-get-prop com.lab126.cmd macAddress 2>/dev/null | tr -d '\r\n')"
fi
if [ -z "$MAC_ADDR" ]; then
    MAC_ADDR="kindle-wp63gw"
fi

# ------------------------------------------------------------------------------
# 3. Read Battery Capacity & Voltage
# ------------------------------------------------------------------------------
BATT_PERCENT=100
if [ -f /sys/devices/system/yoshi_battery/battery_capacity ]; then
    BATT_PERCENT="$(cat /sys/devices/system/yoshi_battery/battery_capacity | tr -d '\r\n')"
elif [ -f /sys/class/power_supply/battery/capacity ]; then
    BATT_PERCENT="$(cat /sys/class/power_supply/battery/capacity | tr -d '\r\n')"
elif [ -f /sys/class/power_supply/max77696-battery/capacity ]; then
    BATT_PERCENT="$(cat /sys/class/power_supply/max77696-battery/capacity | tr -d '\r\n')"
fi

BATT_VOLTAGE=4.0
if [ -f /sys/devices/system/yoshi_battery/battery_voltage ]; then
    RAW_V="$(cat /sys/devices/system/yoshi_battery/battery_voltage | tr -d '\r\n')"
    BATT_VOLTAGE=$(awk -v v="$RAW_V" 'BEGIN { printf "%.2f", (v > 1000 ? v/1000 : v) }' 2>/dev/null || echo "4.0")
fi

log "Device MAC: $MAC_ADDR | Battery: ${BATT_PERCENT}% (${BATT_VOLTAGE}V)"

# ------------------------------------------------------------------------------
# 4. Turn ON Wi-Fi
# ------------------------------------------------------------------------------
if command -v eips >/dev/null 2>&1; then
    eips 0 39 "TRMNL: Enabling Wi-Fi..." 2>/dev/null || true
fi

lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null || true

CONNECTED=0
TIMER=0
while [ $TIMER -lt $WIFI_TIMEOUT ]; do
    if ifconfig wlan0 2>/dev/null | grep -q "inet addr:" || ifconfig wlan0 2>/dev/null | grep -q "inet "; then
        CONNECTED=1
        break
    fi
    sleep 1
    TIMER=$((TIMER + 1))
done

# If loop exited without match, give 2 more seconds grace
if [ $CONNECTED -eq 0 ]; then
    sleep 2
    if ifconfig wlan0 2>/dev/null | grep -q "inet"; then
        CONNECTED=1
    fi
fi

if [ $CONNECTED -eq 0 ]; then
    log "⚠️  Wi-Fi connection timed out."
    if command -v eips >/dev/null 2>&1; then
        eips 0 39 "TRMNL: Wi-Fi timed out. Check connection." 2>/dev/null || true
    fi
    exit 1
fi

log "Wi-Fi connected in ${TIMER}s."

# ------------------------------------------------------------------------------
# 5. POST Telemetry
# ------------------------------------------------------------------------------
JSON_PAYLOAD="{\"device_id\":\"$MAC_ADDR\",\"battery_percent\":$BATT_PERCENT,\"battery_voltage\":$BATT_VOLTAGE,\"signal_strength\":-50,\"firmware_version\":\"WP63GW-KT2\"}"
if command -v curl >/dev/null 2>&1; then
    curl -s -m 5 -X POST -H "Content-Type: application/json" -d "$JSON_PAYLOAD" "${SERVER_URL}/api/log" >/dev/null 2>&1 || true
elif command -v wget >/dev/null 2>&1; then
    wget -q -O /dev/null --post-data="$JSON_PAYLOAD" "${SERVER_URL}/api/log" >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------------------
# 6. Fetch Display Image
# ------------------------------------------------------------------------------
SCREEN_FILE="/tmp/screen.png"
rm -f "$SCREEN_FILE"

if [ -n "$FOUND_FBINK" ]; then
    FETCH_URL="${SERVER_URL}/api/display?mac=${MAC_ADDR}"
else
    # Tell server to rotate 90° so native eips draws landscape on 600x800 panel
    FETCH_URL="${SERVER_URL}/api/display?mac=${MAC_ADDR}&rotate=90"
fi

if command -v eips >/dev/null 2>&1; then
    eips 0 39 "TRMNL: Downloading dashboard..." 2>/dev/null || true
fi

log "Fetching display image from ${FETCH_URL} ..."

FETCH_EXIT=1
if command -v curl >/dev/null 2>&1; then
    curl -s -m 15 -o "$SCREEN_FILE" "$FETCH_URL"
    FETCH_EXIT=$?
else
    # Simple, universally compatible busybox wget syntax
    wget -q -O "$SCREEN_FILE" "$FETCH_URL"
    FETCH_EXIT=$?
fi

# ------------------------------------------------------------------------------
# 7. Render to Screen
# ------------------------------------------------------------------------------
if [ $FETCH_EXIT -eq 0 ] && [ -s "$SCREEN_FILE" ]; then
    log "Image downloaded successfully ($(wc -c < "$SCREEN_FILE") bytes)."
    
    # Pause 1 second for KUAL to completely finish unmounting/closing
    sleep 1

    if [ -n "$FOUND_FBINK" ]; then
        log "Rendering image with fbink (rotation: $FBINK_ROTATION)..."
        "$FOUND_FBINK" -q -g -c -r "$FBINK_ROTATION" "$SCREEN_FILE"
    elif command -v eips >/dev/null 2>&1; then
        log "Rendering image with native eips..."
        eips -c
        sleep 1
        eips -g "$SCREEN_FILE"
    fi
    log "Display update complete."
else
    log "⚠️  Failed to download image (Exit: $FETCH_EXIT)."
    if command -v eips >/dev/null 2>&1; then
        eips 0 38 "TRMNL Error: Could not reach server" 2>/dev/null || true
        eips 0 39 "$SERVER_URL" 2>/dev/null || true
    fi
fi

# ------------------------------------------------------------------------------
# 8. Power OFF Wi-Fi to preserve battery
# ------------------------------------------------------------------------------
log "Disabling Wi-Fi..."
lipc-set-prop com.lab126.cmd wirelessEnable 0 2>/dev/null || true
if command -v wifid >/dev/null 2>&1; then
    wifid disable >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------------------
# 9. Deep Sleep (ONLY in background loop mode)
# ------------------------------------------------------------------------------
if [ $SLEEP_MODE -eq 1 ]; then
    INTERVAL="$DEFAULT_INTERVAL"
    if [ -f "/mnt/us/suspend.enabled" ] || [ "$SUSPEND_ENABLED" = "1" ]; then
        log "Arming RTC alarm for ${INTERVAL}s and entering deep sleep..."
        echo 0 > /sys/class/rtc/rtc0/wakealarm 2>/dev/null || true
        echo "+$INTERVAL" > /sys/class/rtc/rtc0/wakealarm 2>/dev/null || true
        lipc-set-prop -i com.lab126.powerd rtcWakeup "$INTERVAL" 2>/dev/null || true
        echo "mem" > /sys/power/state 2>/dev/null || sleep "$INTERVAL"
    else
        log "Sleeping awake for ${INTERVAL}s (touchscreen and KUAL active)..."
        sleep "$INTERVAL"
    fi
    log "Woke from sleep cycle."
fi
