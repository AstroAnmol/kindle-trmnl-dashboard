#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Status & Diagnostics
# ==============================================================================

EXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Strip Windows carriage returns from all scripts
sed -i -e 's/\r$//' "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true
chmod +x "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true

# Load config
if [ -f "${EXT_DIR}/config.sh" ]; then
    . "${EXT_DIR}/config.sh"
elif [ -f "/mnt/us/extensions/kindle-trmnl/config.sh" ]; then
    . "/mnt/us/extensions/kindle-trmnl/config.sh"
fi

SERVER_URL="${SERVER_URL:-http://10.0.0.219:5055}"
LOG_FILE="${LOG_FILE:-/tmp/kindle-trmnl.log}"
PID_FILE="/tmp/kindle-trmnl.pid"

# Helper: print one line at a given eips row (max ~45 chars per line safely)
pl() {
    ROW="$1"; shift
    eips 0 "$ROW" "$*" 2>/dev/null || true
}

# ---- Gather diagnostics --------------------------------------------------

# Loop running?
LOOP_STATUS="STOPPED"
LOOP_PID="n/a"
if [ -f "$PID_FILE" ]; then
    STORED_PID="$(cat "$PID_FILE")"
    if kill -0 "$STORED_PID" 2>/dev/null; then
        LOOP_STATUS="RUNNING (PID $STORED_PID)"
    else
        LOOP_STATUS="STALE PID ($STORED_PID)"
    fi
fi

# Battery
BATT="?"
if [ -f /sys/devices/system/yoshi_battery/battery_capacity ]; then
    BATT="$(cat /sys/devices/system/yoshi_battery/battery_capacity | tr -d '\r\n')%"
elif [ -f /sys/class/power_supply/battery/capacity ]; then
    BATT="$(cat /sys/class/power_supply/battery/capacity | tr -d '\r\n')%"
elif [ -f /sys/class/power_supply/max77696-battery/capacity ]; then
    BATT="$(cat /sys/class/power_supply/max77696-battery/capacity | tr -d '\r\n')%"
fi

# Wi-Fi IP
WIFI_IP="$(ifconfig wlan0 2>/dev/null | grep -o 'inet addr:[^ ]*' | cut -d: -f2)"
if [ -z "$WIFI_IP" ]; then
    WIFI_IP="$(ifconfig wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}')"
fi
[ -z "$WIFI_IP" ] && WIFI_IP="disconnected"

# MAC address
MAC="?"
if [ -f /sys/class/net/wlan0/address ]; then
    MAC="$(cat /sys/class/net/wlan0/address | tr -d '\r\n')"
elif command -v lipc-get-prop >/dev/null 2>&1; then
    MAC="$(lipc-get-prop com.lab126.cmd macAddress 2>/dev/null | tr -d '\r\n')"
fi

# Wi-Fi signal (RSSI from /proc/net/wireless)
SIGNAL="?"
RSSI="$(awk '/wlan0/{gsub(/\./, ""); print $4}' /proc/net/wireless 2>/dev/null)"
[ -n "$RSSI" ] && SIGNAL="${RSSI} dBm"

# fbink
FBINK_PATH="not found"
if [ -x "${EXT_DIR}/bin/fbink" ]; then
    FBINK_PATH="${EXT_DIR}/bin/fbink"
elif command -v fbink >/dev/null 2>&1; then
    FBINK_PATH="$(command -v fbink)"
elif [ -x "/usr/bin/fbink" ]; then
    FBINK_PATH="/usr/bin/fbink"
elif [ -x "/mnt/us/bin/fbink" ]; then
    FBINK_PATH="/mnt/us/bin/fbink"
elif [ -x "/mnt/us/extensions/MRInstaller/bin/fbink" ]; then
    FBINK_PATH="/mnt/us/extensions/MRInstaller/bin/fbink"
fi

# Server reachability
SERVER_REACH="SKIP (no Wi-Fi)"
if [ "$WIFI_IP" != "disconnected" ]; then
    SERVER_REACH="FAIL (timeout)"
    if command -v curl >/dev/null 2>&1; then
        HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' -m 5 "${SERVER_URL}/api/health" 2>/dev/null)"
        if [ "$HTTP_CODE" = "200" ]; then
            SERVER_REACH="OK (HTTP 200)"
        else
            SERVER_REACH="FAIL (HTTP ${HTTP_CODE:-timeout})"
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q --spider -T 5 "${SERVER_URL}/api/health" 2>/dev/null; then
            SERVER_REACH="OK"
        fi
    fi
fi

# Last log entry
LAST_LOG="(no log yet)"
if [ -f "$LOG_FILE" ]; then
    LAST_LOG="$(tail -1 "$LOG_FILE" 2>/dev/null | cut -c1-44)"
fi

# ---- Render to screen ----------------------------------------------------

eips -c 2>/dev/null || true
sleep 1

pl  0 "==== KINDLE TRMNL: DIAGNOSTICS ===="
pl  1 ""
pl  2 "Loop   : ${LOOP_STATUS}"
pl  3 "Battery: ${BATT}"
pl  4 "Wi-Fi  : ${WIFI_IP}"
pl  5 "Signal : ${SIGNAL}"
pl  6 "MAC    : ${MAC}"
pl  7 ""
pl  8 "Server : ${SERVER_URL}"
pl  9 "Reach  : ${SERVER_REACH}"
pl 10 ""
pl 11 "fbink  : ${FBINK_PATH}"
pl 12 ""
pl 13 "Last log entry:"
pl 14 "  ${LAST_LOG}"
pl 15 ""
pl 16 "Full log: ${LOG_FILE}"
pl 17 ""
pl 18 "===================================="
pl 19 "Press Back or tap to return to KUAL"
