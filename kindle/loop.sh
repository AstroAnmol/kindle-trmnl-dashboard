#!/bin/sh
# ==============================================================================
# Kindle Continuous Background Loop: kindle-trmnl-dashboard
# Run in background on Kindle or via KUAL extension
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="/tmp/kindle-trmnl.pid"

echo $$ > "$PID_FILE"

cleanup() {
    echo "Stopping Kindle TRMNL dashboard loop..."
    rm -f "$PID_FILE"
    lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null || true
    lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null || true
    exit 0
}

trap cleanup INT TERM HUP

echo "Starting Kindle TRMNL Dashboard loop (PID: $$)..."

while true; do
    sh "${SCRIPT_DIR}/display.sh" --sleep
    sleep 2
done
