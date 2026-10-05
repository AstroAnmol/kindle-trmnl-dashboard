#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Status & Diagnostics
# ==============================================================================
eips 0 36 "=== TRMNL Status Check ===" 2>/dev/null || true

EXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

sed -i -e 's/\r$//' "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true
chmod +x "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true

if [ -f "${EXT_DIR}/config.sh" ]; then
    . "${EXT_DIR}/config.sh"
fi

SERVER_URL="${SERVER_URL:-http://10.0.0.219:5055}"

BATT="N/A"
if [ -f /sys/devices/system/yoshi_battery/battery_capacity ]; then
    BATT="$(cat /sys/devices/system/yoshi_battery/battery_capacity | tr -d '\r\n')"
elif [ -f /sys/class/power_supply/battery/capacity ]; then
    BATT="$(cat /sys/class/power_supply/battery/capacity | tr -d '\r\n')"
elif [ -f /sys/class/power_supply/max77696-battery/capacity ]; then
    BATT="$(cat /sys/class/power_supply/max77696-battery/capacity | tr -d '\r\n')"
fi

IP="$(ifconfig wlan0 2>/dev/null | grep -o 'inet addr:[^ ]*' | cut -d: -f2)"
if [ -z "$IP" ]; then
    IP="$(ifconfig wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}')"
fi
[ -z "$IP" ] && IP="Disconnected"

eips 0 37 "Batt: ${BATT}% | Wi-Fi: ${IP}" 2>/dev/null || true

if [ "$IP" = "Disconnected" ]; then
    eips 0 38 "Server: Wi-Fi is OFF or not connected" 2>/dev/null || true
    eips 0 39 "Connect Kindle to Wi-Fi first!" 2>/dev/null || true
else
    eips 0 38 "Connecting to ${SERVER_URL}..." 2>/dev/null || true
    PING_STATUS="Offline"
    if command -v curl >/dev/null 2>&1; then
        if curl -s -m 3 "$SERVER_URL/api/setup" >/dev/null 2>&1; then
            PING_STATUS="Connected"
        fi
    else
        if wget -q -O /dev/null -t 1 "$SERVER_URL/api/setup" 2>/dev/null; then
            PING_STATUS="Connected"
        fi
    fi
    eips 0 38 "Server: ${PING_STATUS}" 2>/dev/null || true
    eips 0 39 "${SERVER_URL}" 2>/dev/null || true
fi
