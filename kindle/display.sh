#!/bin/sh
# ==============================================================================
# Kindle Display Loop Step: kindle-trmnl-dashboard
# Optimized for: Kindle WP63GW (7th Gen Basic - KT2 / Touch 2)
# Fetches latest dashboard image, renders to e-ink screen via fbink,
# sends battery telemetry, and puts Kindle into deep sleep with RTC wakeup.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/config.sh"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [KINDLE-TRMNL] $1" | tee -a "$LOG_FILE"
}

# ------------------------------------------------------------------------------
# 1. Locate fbink rendering binary
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
fi

# ------------------------------------------------------------------------------
# 2. Detect Device MAC Address (Unique Device ID)
# ------------------------------------------------------------------------------
MAC_ADDR=""
if [ -f /sys/class/net/wlan0/address ]; then
    MAC_ADDR="$(cat /sys/class/net/wlan0/address | tr -d '\r\n')"
fi
if [ -z "$MAC_ADDR" ]; then
    MAC_ADDR="$(lipc-get-prop com.lab126.cmd macAddress 2>/dev/null | tr -d '\r\n')"
fi
if [ -z "$MAC_ADDR" ]; then
    MAC_ADDR="$(ifconfig wlan0 2>/dev/null | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' | head -n 1)"
fi
if [ -z "$MAC_ADDR" ]; then
    MAC_ADDR="kindle-wp63gw"
fi

DEVICE_TOKEN="${API_TOKEN:-$MAC_ADDR}"

# ------------------------------------------------------------------------------
# 3. Read Battery Capacity & Voltage (Kindle WP63GW / KT2 sysfs nodes)
# ------------------------------------------------------------------------------
BATT_PERCENT=100
if [ -f /sys/devices/system/yoshi_battery/battery_capacity ]; then
    BATT_PERCENT="$(cat /sys/devices/system/yoshi_battery/battery_capacity | tr -d '\r\n')"
elif [ -f /sys/class/power_supply/max77696-battery/capacity ]; then
    BATT_PERCENT="$(cat /sys/class/power_supply/max77696-battery/capacity | tr -d '\r\n')"
elif [ -f /sys/class/power_supply/mc13892_battery/capacity ]; then
    BATT_PERCENT="$(cat /sys/class/power_supply/mc13892_battery/capacity | tr -d '\r\n')"
elif [ -f /sys/class/power_supply/battery/capacity ]; then
    BATT_PERCENT="$(cat /sys/class/power_supply/battery/capacity | tr -d '\r\n')"
elif [ -f /sys/devices/platform/pmic_battery.1/power_supply/pmic_battery/capacity ]; then
    BATT_PERCENT="$(cat /sys/devices/platform/pmic_battery.1/power_supply/pmic_battery/capacity | tr -d '\r\n')"
else
    LIPC_BATT="$(lipc-get-prop com.lab126.powerd battLevel 2>/dev/null | tr -d '\r\n')"
    if [ -n "$LIPC_BATT" ]; then
        BATT_PERCENT="$LIPC_BATT"
    fi
fi

BATT_VOLTAGE=4.0
if [ -f /sys/devices/system/yoshi_battery/battery_voltage ]; then
    RAW_V="$(cat /sys/devices/system/yoshi_battery/battery_voltage | tr -d '\r\n')"
    BATT_VOLTAGE=$(awk -v v="$RAW_V" 'BEGIN { printf "%.2f", (v > 1000 ? v/1000 : v) }')
elif [ -f /sys/class/power_supply/max77696-battery/voltage_now ]; then
    RAW_V="$(cat /sys/class/power_supply/max77696-battery/voltage_now | tr -d '\r\n')"
    BATT_VOLTAGE=$(awk -v v="$RAW_V" 'BEGIN { printf "%.2f", (v > 1000000 ? v/1000000 : (v > 1000 ? v/1000 : v)) }')
elif [ -f /sys/class/power_supply/mc13892_battery/voltage_now ]; then
    RAW_V="$(cat /sys/class/power_supply/mc13892_battery/voltage_now | tr -d '\r\n')"
    BATT_VOLTAGE=$(awk -v v="$RAW_V" 'BEGIN { printf "%.2f", (v > 1000000 ? v/1000000 : (v > 1000 ? v/1000 : v)) }')
elif [ -f /sys/class/power_supply/battery/voltage_now ]; then
    RAW_V="$(cat /sys/class/power_supply/battery/voltage_now | tr -d '\r\n')"
    BATT_VOLTAGE=$(awk -v v="$RAW_V" 'BEGIN { printf "%.2f", (v > 1000000 ? v/1000000 : (v > 1000 ? v/1000 : v)) }')
fi

log "Device MAC: $MAC_ADDR | Battery: ${BATT_PERCENT}% (${BATT_VOLTAGE}V)"

# ------------------------------------------------------------------------------
# 4. Turn ON Wi-Fi and Wait for Connection
# ------------------------------------------------------------------------------
log "Enabling Wi-Fi..."
lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null || true

CONNECTED=0
TIMER=0
while [ $TIMER -lt $WIFI_TIMEOUT ]; do
    if ifconfig wlan0 2>/dev/null | grep -q "inet addr:" || ip route show 2>/dev/null | grep -q "default"; then
        CONNECTED=1
        break
    fi
    sleep 1
    TIMER=$((TIMER + 1))
done

if [ $CONNECTED -eq 0 ]; then
    log "⚠️  Wi-Fi connection timed out after ${WIFI_TIMEOUT}s."
else
    log "Wi-Fi connected in ${TIMER}s."
fi

# Read Wi-Fi Signal RSSI
RSSI=-60
LIPC_RSSI="$(lipc-get-prop com.lab126.cmd wirelessSignal 2>/dev/null | tr -d '\r\n')"
if [ -n "$LIPC_RSSI" ] && [ "$LIPC_RSSI" -ne 0 ] 2>/dev/null; then
    RSSI="$LIPC_RSSI"
elif [ -f /proc/net/wireless ]; then
    PROC_RSSI="$(awk 'NR==3 {print $4}' /proc/net/wireless | tr -d '.\r\n')"
    if [ -n "$PROC_RSSI" ]; then
        RSSI="$PROC_RSSI"
    fi
fi

# ------------------------------------------------------------------------------
# 5. POST Telemetry to /api/log
# ------------------------------------------------------------------------------
if [ $CONNECTED -eq 1 ]; then
    JSON_PAYLOAD="{\"device_id\":\"$MAC_ADDR\",\"battery_percent\":$BATT_PERCENT,\"battery_voltage\":$BATT_VOLTAGE,\"signal_strength\":$RSSI,\"firmware_version\":\"WP63GW-KT2\"}"
    curl -s -m 6 -X POST \
        -H "Content-Type: application/json" \
        -d "$JSON_PAYLOAD" \
        "${SERVER_URL}/api/log" >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------------------
# 6. Fetch Display Image from /api/display
# ------------------------------------------------------------------------------
SCREEN_FILE="/tmp/screen.img"
HEADERS_FILE="/tmp/headers.txt"
INTERVAL="$DEFAULT_INTERVAL"

if [ $CONNECTED -eq 1 ]; then
    log "Fetching display image from ${SERVER_URL}/api/display ..."
    curl -s -m 15 -D "$HEADERS_FILE" \
        -H "ID: $MAC_ADDR" \
        -H "Access-Token: $DEVICE_TOKEN" \
        -o "$SCREEN_FILE" \
        "${SERVER_URL}/api/display"
    
    FETCH_EXIT=$?
    if [ $FETCH_EXIT -eq 0 ] && [ -s "$SCREEN_FILE" ]; then
        # Parse dynamic Refresh-Rate header if provided
        SERVER_REFRESH="$(grep -i "Refresh-Rate:" "$HEADERS_FILE" 2>/dev/null | awk -F': ' '{print $2}' | tr -d '\r\n ')"
        if [ -n "$SERVER_REFRESH" ] && [ "$SERVER_REFRESH" -gt 0 ] 2>/dev/null; then
            INTERVAL="$SERVER_REFRESH"
            log "Server requested Refresh-Rate: ${INTERVAL}s."
        fi

        # ----------------------------------------------------------------------
        # 7. Render Image to Screen via fbink (with landscape rotation)
        # ----------------------------------------------------------------------
        if [ -n "$FOUND_FBINK" ]; then
            log "Rendering image with fbink (rotation: $FBINK_ROTATION)..."
            "$FOUND_FBINK" -q -g -c -r "$FBINK_ROTATION" "$SCREEN_FILE"
        elif command -v eips >/dev/null 2>&1; then
            log "Rendering image with native eips fallback..."
            eips -c
            eips -g "$SCREEN_FILE"
        else
            log "⚠️  No display tool found (neither fbink nor eips)!"
        fi
    else
        log "⚠️  Failed to download display image (Exit: $FETCH_EXIT)."
    fi
fi

# ------------------------------------------------------------------------------
# 8. Low Battery Safeguard Overlay
# ------------------------------------------------------------------------------
if [ "$BATT_PERCENT" -le "$LOW_BATTERY_THRESHOLD" ] 2>/dev/null; then
    log "CRITICAL BATTERY: ${BATT_PERCENT}%. Setting extended sleep."
    INTERVAL="$CRITICAL_SLEEP_INTERVAL"
    if [ -n "$FOUND_FBINK" ]; then
        "$FOUND_FBINK" -q -m -b -y -2 "⚠️ CRITICAL BATTERY: ${BATT_PERCENT}% - PLEASE RECHARGE"
    fi
fi

# ------------------------------------------------------------------------------
# 9. Power OFF Wi-Fi immediately
# ------------------------------------------------------------------------------
log "Disabling Wi-Fi to preserve battery..."
lipc-set-prop com.lab126.cmd wirelessEnable 0 2>/dev/null || true

# ------------------------------------------------------------------------------
# 10. Schedule RTC Wakeup Alarm and Enter Deep Sleep
# ------------------------------------------------------------------------------
log "Scheduling RTC wake in ${INTERVAL}s and entering deep sleep..."

# Try lipc rtcWakeup first (standard across Kindle Paperwhite & modern firmware)
lipc-set-prop -i com.lab126.powerd rtcWakeup "$INTERVAL" 2>/dev/null

# Try rtcwake fallback if device node exists
if [ -e /dev/rtc1 ]; then
    rtcwake -d /dev/rtc1 -m no -s "$INTERVAL" 2>/dev/null || true
elif [ -e /dev/rtc0 ]; then
    rtcwake -d /dev/rtc0 -m no -s "$INTERVAL" 2>/dev/null || true
fi

# Suspend device to RAM (deep sleep)
echo "mem" > /sys/power/state