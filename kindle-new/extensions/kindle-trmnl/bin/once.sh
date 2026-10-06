#!/bin/sh
# ==============================================================================
# Kindle TRMNL - KUAL Action: Refresh Screen Once
# Fetches current dashboard and displays it once.
# Leaves lab126_gui running so touching the screen returns directly to KUAL.
# ==============================================================================

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
export PATH

EXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Load configuration
CONF_FILE=""
for p in /mnt/us/trmnl.conf \
         /mnt/us/kindle-new/trmnl.conf \
         "${EXT_DIR}/trmnl.conf" \
         "${EXT_DIR}/../../trmnl.conf"; do
    if [ -r "$p" ]; then
        CONF_FILE="$p"
        break
    fi
done

if [ -n "$CONF_FILE" ]; then
    eval "$(tr -d '\r' < "$CONF_FILE")"
fi

DASHBOARD_URL="${DASHBOARD_URL:-http://10.0.0.219:5055/api/display/image}"
TMP_PNG="/tmp/trmnl_once.png"

if command -v eips >/dev/null 2>&1; then
    eips 0 38 "TRMNL: Fetching dashboard image..." 2>/dev/null || true
fi

rm -f "$TMP_PNG"
if command -v curl >/dev/null 2>&1; then
    curl -fs -m 15 -o "$TMP_PNG" "$DASHBOARD_URL" 2>/dev/null
else
    wget -q -T 15 -O "$TMP_PNG" "$DASHBOARD_URL" 2>/dev/null
fi

if [ -s "$TMP_PNG" ]; then
    if command -v eips >/dev/null 2>&1; then
        eips -g "$TMP_PNG"
    fi
else
    # Try ensuring wifi and retrying once
    lipc-set-prop com.lab126.cmd ensureConnection wifi >/dev/null 2>&1 || true
    sleep 3
    if command -v curl >/dev/null 2>&1; then
        curl -fs -m 15 -o "$TMP_PNG" "$DASHBOARD_URL" 2>/dev/null
    else
        wget -q -T 15 -O "$TMP_PNG" "$DASHBOARD_URL" 2>/dev/null
    fi

    if [ -s "$TMP_PNG" ]; then
        if command -v eips >/dev/null 2>&1; then
            eips -g "$TMP_PNG"
        fi
    else
        if command -v eips >/dev/null 2>&1; then
            eips 0 38 "TRMNL Error: Failed to fetch image!" 2>/dev/null || true
            eips 0 39 "Check $DASHBOARD_URL" 2>/dev/null || true
        fi
    fi
fi

exit 0
