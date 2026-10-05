#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Status & Diagnostics
# ==============================================================================
EXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

CONFIG_SCRIPT=""
if [ -f "${EXT_DIR}/config.sh" ]; then
    CONFIG_SCRIPT="${EXT_DIR}/config.sh"
elif [ -f "/mnt/us/extensions/kindle-trmnl/config.sh" ]; then
    CONFIG_SCRIPT="/mnt/us/extensions/kindle-trmnl/config.sh"
elif [ -f "/mnt/us/kindle-trmnl-dashboard/kindle/config.sh" ]; then
    CONFIG_SCRIPT="/mnt/us/kindle-trmnl-dashboard/kindle/config.sh"
elif [ -f "/mnt/us/kindle-trmnl-dashboard/config.sh" ]; then
    CONFIG_SCRIPT="/mnt/us/kindle-trmnl-dashboard/config.sh"
fi

SERVER_URL="http://10.0.0.219:5055"
if [ -n "$CONFIG_SCRIPT" ]; then
    . "$CONFIG_SCRIPT"
fi

BATT="N/A"
if [ -f /sys/devices/system/yoshi_battery/battery_capacity ]; then
    BATT="$(cat /sys/devices/system/yoshi_battery/battery_capacity | tr -d '\r\n')"
elif [ -f /sys/class/power_supply/battery/capacity ]; then
    BATT="$(cat /sys/class/power_supply/battery/capacity | tr -d '\r\n')"
elif [ -f /sys/class/power_supply/max77696-battery/capacity ]; then
    BATT="$(cat /sys/class/power_supply/max77696-battery/capacity | tr -d '\r\n')"
fi

IP="$(ifconfig wlan0 2>/dev/null | grep -o 'inet addr:[^ ]*' | cut -d: -f2)"
[ -z "$IP" ] && IP="Disconnected"

PING_STATUS="Offline"
if command -v curl >/dev/null 2>&1; then
    if curl -s -m 3 "$SERVER_URL/api/setup" >/dev/null 2>&1; then
        PING_STATUS="Connected"
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget -q -O - -T 3 "$SERVER_URL/api/setup" >/dev/null 2>&1; then
        PING_STATUS="Connected"
    fi
fi

PID_FILE="/tmp/kindle-trmnl.pid"
LOOP_STATUS="Stopped"
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    LOOP_STATUS="Running (PID $(cat "$PID_FILE"))"
fi

MSG1="Batt: ${BATT}% | Wi-Fi: ${IP}"
MSG2="Server: ${PING_STATUS} | Loop: ${LOOP_STATUS}"

if command -v fbink >/dev/null 2>&1; then
    fbink -q -m -b -y -3 "$MSG1"
    fbink -q -m -b -y -2 "$MSG2"
elif [ -x "${EXT_DIR}/bin/fbink" ]; then
    "${EXT_DIR}/bin/fbink" -q -m -b -y -3 "$MSG1"
    "${EXT_DIR}/bin/fbink" -q -m -b -y -2 "$MSG2"
elif command -v eips >/dev/null 2>&1; then
    eips 0 38 "$MSG1" 2>/dev/null || true
    eips 0 39 "$MSG2" 2>/dev/null || true
else
    echo "$MSG1"
    echo "$MSG2"
fi
