#!/bin/sh
BASE_DIR="/mnt/us/kindle-trmnl-dashboard"
if [ ! -d "$BASE_DIR" ]; then
    BASE_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
fi
. "${BASE_DIR}/config.sh"

BATT="N/A"
if [ -f /sys/devices/system/yoshi_battery/battery_capacity ]; then
    BATT="$(cat /sys/devices/system/yoshi_battery/battery_capacity)"
elif [ -f /sys/class/power_supply/battery/capacity ]; then
    BATT="$(cat /sys/class/power_supply/battery/capacity)"
fi

IP="$(ifconfig wlan0 2>/dev/null | grep -o 'inet addr:[^ ]*' | cut -d: -f2)"
[ -z "$IP" ] && IP="Disconnected"

PING_STATUS="Offline"
if curl -s -m 3 "$SERVER_URL/api/setup" >/dev/null 2>&1; then
    PING_STATUS="Connected"
fi

MSG="Battery: ${BATT}% | Wi-Fi IP: ${IP} | Server: ${PING_STATUS}"

if command -v fbink >/dev/null 2>&1; then
    fbink -q -m -b -y -2 "$MSG"
elif [ -x "${BASE_DIR}/bin/fbink" ]; then
    "${BASE_DIR}/bin/fbink" -q -m -b -y -2 "$MSG"
else
    echo "$MSG"
fi