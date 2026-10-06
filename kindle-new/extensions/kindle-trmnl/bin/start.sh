#!/bin/sh
# ==============================================================================
# Kindle TRMNL - KUAL Action: Start Dashboard Loop
# ==============================================================================

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
export PATH

EXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Locate trmnl.sh
TRMNL_SCRIPT=""
for s in "${EXT_DIR}/trmnl.sh" \
         "${EXT_DIR}/../../trmnl.sh" \
         /mnt/us/kindle-new/trmnl.sh \
         /mnt/us/trmnl.sh; do
    if [ -x "$s" ] || [ -f "$s" ]; then
        TRMNL_SCRIPT="$s"
        break
    fi
done

if [ -z "$TRMNL_SCRIPT" ]; then
    if command -v eips >/dev/null 2>&1; then
        eips 0 38 "TRMNL Error: trmnl.sh not found!" 2>/dev/null || true
    fi
    exit 1
fi

if command -v eips >/dev/null 2>&1; then
    eips 0 37 "=== Kindle TRMNL ===" 2>/dev/null || true
    eips 0 38 "Starting Dashboard Loop..." 2>/dev/null || true
    eips 0 39 "Touch screen or press power to exit." 2>/dev/null || true
fi

# Ensure executable bit
chmod +x "$TRMNL_SCRIPT" 2>/dev/null || true

# Launch trmnl.sh in background
sh "$TRMNL_SCRIPT" >/tmp/trmnl.log 2>&1 &

exit 0
