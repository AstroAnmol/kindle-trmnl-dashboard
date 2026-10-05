#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Status & Diagnostics
# ==============================================================================
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
fi

IP="$(ifconfig wlan0 2>/dev/null | grep -o 'inet addr:[^ ]*' | cut -d: -f2)"
if [ -z "$IP" ]; then
    IP="$(ifconfig wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}')"
fi
[ -z "$IP" ] && IP="Disconnected"

PING_STATUS="Offline"
if command -v curl >/dev/null 2>&1; then
    if curl -s -m 3 "$SERVER_URL/api/setup" >/dev/null 2>&1; then
        PING_STATUS="Connected"
    fi
else
    if wget -q -O /dev/null "$SERVER_URL/api/setup" >/dev/null 2>&1; then
        PING_STATUS="Connected"
    fi
fi

LAST_LOG=""
if [ -f /tmp/kindle-trmnl.log ]; then
    LAST_LOG="$(tail -n 1 /tmp/kindle-trmnl.log | cut -c 20-55)"
fi

if command -v eips >/dev/null 2>&1; then
    eips 0 37 "TRMNL: Batt: ${BATT}% | Wi-Fi: ${IP}" 2>/dev/null || true
    eips 0 38 "TRMNL: Server: ${PING_STATUS} (${SERVER_URL})" 2>/dev/null || true
    if [ -n "$LAST_LOG" ]; then
        eips 0 39 "Last: $LAST_LOG" 2>/dev/null || true
    fi
fi
