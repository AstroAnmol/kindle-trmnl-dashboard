#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Refresh Screen Once
# Connects to Wi-Fi, fetches the dashboard image, renders it to the screen,
# and leaves it displayed. Touching the screen brings back the KUAL menu.
# ==============================================================================

EXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Strip Windows carriage returns from all scripts
sed -i -e 's/\r$//' "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true
chmod +x "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true

eips 0 37 "=== Kindle TRMNL ===" 2>/dev/null || true
eips 0 38 "Refreshing display..." 2>/dev/null || true
eips 0 39 "Please wait 5-10 seconds..." 2>/dev/null || true

# Run display.sh directly
DISPLAY_SCRIPT="${EXT_DIR}/display.sh"
if [ ! -f "$DISPLAY_SCRIPT" ]; then
    DISPLAY_SCRIPT="/mnt/us/extensions/kindle-trmnl/display.sh"
fi

if [ -f "$DISPLAY_SCRIPT" ]; then
    sh "$DISPLAY_SCRIPT"
    RC=$?
    if [ $RC -ne 0 ]; then
        eips 0 38 "TRMNL: Refresh failed (exit $RC)" 2>/dev/null || true
        eips 0 39 "Check /tmp/kindle-trmnl.log" 2>/dev/null || true
    fi
else
    eips 0 38 "TRMNL Error: display.sh not found!" 2>/dev/null || true
fi
