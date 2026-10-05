#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Refresh Screen Once
# ==============================================================================
eips 0 38 "TRMNL: Refreshing display..." 2>/dev/null || true
eips 0 39 "Please wait 5-8 seconds..." 2>/dev/null || true

EXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

sed -i -e 's/\r$//' "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true
chmod +x "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true

DISPLAY_SCRIPT=""
if [ -f "${EXT_DIR}/display.sh" ]; then
    DISPLAY_SCRIPT="${EXT_DIR}/display.sh"
elif [ -f "/mnt/us/extensions/kindle-trmnl/display.sh" ]; then
    DISPLAY_SCRIPT="/mnt/us/extensions/kindle-trmnl/display.sh"
elif [ -f "/mnt/us/kindle-trmnl-dashboard/kindle/display.sh" ]; then
    DISPLAY_SCRIPT="/mnt/us/kindle-trmnl-dashboard/kindle/display.sh"
elif [ -f "/mnt/us/display.sh" ]; then
    DISPLAY_SCRIPT="/mnt/us/display.sh"
fi

if [ -n "$DISPLAY_SCRIPT" ]; then
    nohup sh "$DISPLAY_SCRIPT" >/tmp/kindle-once.log 2>&1 &
else
    eips 0 39 "TRMNL Error: display.sh not found!" 2>/dev/null || true
fi
