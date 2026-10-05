#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Refresh Screen Once
# ==============================================================================

EXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Self-heal: strip Windows carriage returns from all scripts
sed -i -e 's/\r$//' "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true
chmod +x "${EXT_DIR}"/*.sh "${EXT_DIR}/bin"/*.sh 2>/dev/null || true

eips 0 36 "==== KINDLE TRMNL ====" 2>/dev/null || true
eips 0 37 "Refresh Screen Once" 2>/dev/null || true
eips 0 38 "Locating display.sh..." 2>/dev/null || true
eips 0 39 "(please wait)" 2>/dev/null || true

DISPLAY_SCRIPT=""
if [ -f "${EXT_DIR}/display.sh" ]; then
    DISPLAY_SCRIPT="${EXT_DIR}/display.sh"
elif [ -f "/mnt/us/extensions/kindle-trmnl/display.sh" ]; then
    DISPLAY_SCRIPT="/mnt/us/extensions/kindle-trmnl/display.sh"
elif [ -f "/mnt/us/kindle-trmnl-dashboard/kindle/kual/kindle-trmnl/display.sh" ]; then
    DISPLAY_SCRIPT="/mnt/us/kindle-trmnl-dashboard/kindle/kual/kindle-trmnl/display.sh"
elif [ -f "/mnt/us/kindle-trmnl-dashboard/kindle/display.sh" ]; then
    DISPLAY_SCRIPT="/mnt/us/kindle-trmnl-dashboard/kindle/display.sh"
elif [ -f "/mnt/us/display.sh" ]; then
    DISPLAY_SCRIPT="/mnt/us/display.sh"
fi

if [ -n "$DISPLAY_SCRIPT" ]; then
    eips 0 38 "Found: ${DISPLAY_SCRIPT}" 2>/dev/null || true
    eips 0 39 "Starting... (10-20s for Wi-Fi)" 2>/dev/null || true
    # Run SYNCHRONOUSLY so progress is visible and dashboard renders before KUAL exits
    sh "$DISPLAY_SCRIPT"
    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        eips 0 38 "TRMNL: display.sh exited with error $EXIT_CODE" 2>/dev/null || true
        eips 0 39 "Check /tmp/kindle-trmnl.log for details" 2>/dev/null || true
    fi
else
    eips 0 37 "ERROR: display.sh not found!" 2>/dev/null || true
    eips 0 38 "Expected path:" 2>/dev/null || true
    eips 0 39 "${EXT_DIR}/display.sh" 2>/dev/null || true
fi
