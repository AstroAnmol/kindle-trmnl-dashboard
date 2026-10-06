#!/bin/sh
# ==============================================================================
# Kindle TRMNL - KUAL Action: Status & Diagnostics
# ==============================================================================

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
export PATH

EXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Locate info.sh
INFO_SCRIPT=""
for s in "${EXT_DIR}/info.sh" \
         "${EXT_DIR}/../../info.sh" \
         /mnt/us/kindle-new/info.sh \
         /mnt/us/info.sh; do
    if [ -x "$s" ] || [ -f "$s" ]; then
        INFO_SCRIPT="$s"
        break
    fi
done

if [ -n "$INFO_SCRIPT" ]; then
    chmod +x "$INFO_SCRIPT" 2>/dev/null || true
    sh "$INFO_SCRIPT"
else
    if command -v eips >/dev/null 2>&1; then
        eips 0 38 "TRMNL Error: info.sh not found!" 2>/dev/null || true
    fi
fi

exit 0
