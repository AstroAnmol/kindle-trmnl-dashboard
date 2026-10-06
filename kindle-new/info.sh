#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Status & Diagnostics
# Safe, read-only test script. Does NOT stop lab126_gui.
# Checks Wi-Fi, battery, tests server connection, and renders a test frame.
# ==============================================================================

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
export PATH

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load configuration if available
CONF_FILE=""
for p in /mnt/us/trmnl.conf \
         /mnt/us/kindle-new/trmnl.conf \
         /mnt/us/extensions/kindle-trmnl/trmnl.conf \
         "${SCRIPT_DIR}/trmnl.conf"; do
    if [ -r "$p" ]; then
        CONF_FILE="$p"
        break
    fi
done

if [ -n "$CONF_FILE" ]; then
    eval "$(tr -d '\r' < "$CONF_FILE")"
fi

DASHBOARD_URL="${DASHBOARD_URL:-http://10.0.0.219:5055/api/display/image}"
TEST_FILE="/tmp/trmnl_test.png"

# Gather device info
MODEL="Kindle KT2 (WP63GW)"
if [ -f /proc/cpuinfo ]; then
    HW="$(grep -m 1 "Hardware" /proc/cpuinfo | awk '{print $3}')"
    [ -n "$HW" ] && MODEL="$MODEL ($HW)"
fi

# Wi-Fi IP address
IP="$(ifconfig wlan0 2>/dev/null | grep -o 'inet addr:[0-9.]*' | cut -d: -f2)"
if [ -z "$IP" ]; then
    IP="$(ifconfig wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}')"
fi
[ -z "$IP" ] && IP="Disconnected"

# Battery level
BATT="N/A"
if [ -f /sys/devices/system/yoshi_battery/battery_capacity ]; then
    BATT="$(cat /sys/devices/system/yoshi_battery/battery_capacity | tr -d '\r\n')%"
elif [ -f /sys/class/power_supply/battery/capacity ]; then
    BATT="$(cat /sys/class/power_supply/battery/capacity | tr -d '\r\n')%"
elif [ -f /sys/class/power_supply/max77696-battery/capacity ]; then
    BATT="$(cat /sys/class/power_supply/max77696-battery/capacity | tr -d '\r\n')%"
fi

# Display text diagnostics on screen
if command -v eips >/dev/null 2>&1; then
    eips 0 32 "==========================================" 2>/dev/null || true
    eips 0 33 "      KINDLE TRMNL DIAGNOSTICS" 2>/dev/null || true
    eips 0 34 "==========================================" 2>/dev/null || true
    eips 0 35 "Model  : $MODEL" 2>/dev/null || true
    eips 0 36 "Wi-Fi  : $IP" 2>/dev/null || true
    eips 0 37 "Battery: $BATT" 2>/dev/null || true
    eips 0 38 "Server : $DASHBOARD_URL" 2>/dev/null || true
    eips 0 39 "Testing download from server..." 2>/dev/null || true
fi

echo "=========================================="
echo "Kindle TRMNL Diagnostics"
echo "Model  : $MODEL"
echo "Wi-Fi  : $IP"
echo "Battery: $BATT"
echo "Server : $DASHBOARD_URL"
echo "=========================================="

# Test image download
rm -f "$TEST_FILE"
FETCH_OK=0

if command -v curl >/dev/null 2>&1; then
    curl -fs -m 15 -o "$TEST_FILE" "$DASHBOARD_URL" 2>/dev/null
    [ $? -eq 0 ] && [ -s "$TEST_FILE" ] && FETCH_OK=1
else
    wget -q -T 15 -O "$TEST_FILE" "$DASHBOARD_URL" 2>/dev/null
    [ $? -eq 0 ] && [ -s "$TEST_FILE" ] && FETCH_OK=1
fi

if [ $FETCH_OK -eq 1 ]; then
    SIZE="$(wc -c < "$TEST_FILE" | tr -d ' ')"
    echo "SUCCESS: Fetched $SIZE bytes from server."
    if command -v eips >/dev/null 2>&1; then
        eips 0 39 "SUCCESS ($SIZE bytes)! Drawing test frame..." 2>/dev/null || true
        sleep 2
        eips -g "$TEST_FILE"
    fi
else
    echo "ERROR: Failed to connect or download image from $DASHBOARD_URL"
    if command -v eips >/dev/null 2>&1; then
        eips 0 39 "ERROR: Could not download image!" 2>/dev/null || true
        eips 0 40 "Check Wi-Fi and server IP." 2>/dev/null || true
    fi
fi

exit 0
