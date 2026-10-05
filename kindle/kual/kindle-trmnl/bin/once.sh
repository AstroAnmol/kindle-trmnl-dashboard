#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Refresh Screen Once
# ==============================================================================
EXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if command -v eips >/dev/null 2>&1; then
    eips 0 39 "TRMNL: Refreshing screen..." 2>/dev/null || true
fi

DISPLAY_SCRIPT=""
if [ -f "${EXT_DIR}/display.sh" ]; then
    DISPLAY_SCRIPT="${EXT_DIR}/display.sh"
elif [ -f "/mnt/us/extensions/kindle-trmnl/display.sh" ]; then
    DISPLAY_SCRIPT="/mnt/us/extensions/kindle-trmnl/display.sh"
elif [ -f "/mnt/us/kindle-trmnl-dashboard/kindle/display.sh" ]; then
    DISPLAY_SCRIPT="/mnt/us/kindle-trmnl-dashboard/kindle/display.sh"
elif [ -f "/mnt/us/kindle-trmnl-dashboard/display.sh" ]; then
    DISPLAY_SCRIPT="/mnt/us/kindle-trmnl-dashboard/display.sh"
elif [ -f "/mnt/us/kindle/display.sh" ]; then
    DISPLAY_SCRIPT="/mnt/us/kindle/display.sh"
elif [ -f "/mnt/us/display.sh" ]; then
    DISPLAY_SCRIPT="/mnt/us/display.sh"
fi

if [ -n "$DISPLAY_SCRIPT" ]; then
    nohup sh "$DISPLAY_SCRIPT" >/tmp/kindle-once.log 2>&1 &
else
    if command -v eips >/dev/null 2>&1; then
        eips 0 39 "TRMNL Error: display.sh not found!" 2>/dev/null || true
    fi
fi
