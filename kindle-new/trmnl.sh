#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Dashboard Display Loop
# Based on dashink architecture for Kindle 7th Gen (KT2, WP63GW).
# Stops lab126_gui, fetches PNG from dashboard server, draws with native eips,
# and provides an input event escape hatch (power button / screen touch) to exit.
# ==============================================================================

set -u

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
export PATH

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ------------------------------------------------------------------------------
# 1. Configuration Loading
# ------------------------------------------------------------------------------
# Check multiple possible locations for trmnl.conf, preferring user root
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
INTERVAL="${INTERVAL:-900}"
FULL_REFRESH_EVERY="${FULL_REFRESH_EVERY:-12}"
LOW_BATTERY_THRESHOLD="${LOW_BATTERY_THRESHOLD:-10}"
ENABLE_ESCAPE_HATCH="${ENABLE_ESCAPE_HATCH:-1}"

OUT_TMP="/tmp/trmnl.png.tmp"
OUT="/tmp/trmnl.png"
LOG_FILE="/tmp/trmnl.log"
LOCK="/tmp/trmnl.pid"

# ------------------------------------------------------------------------------
# 2. Locate Restore Script
# ------------------------------------------------------------------------------
RESTORE_SCRIPT=""
for r in "${SCRIPT_DIR}/restore.sh" \
         /mnt/us/kindle-new/restore.sh \
         /mnt/us/extensions/kindle-trmnl/restore.sh \
         /mnt/us/restore.sh; do
    if [ -x "$r" ] || [ -f "$r" ]; then
        RESTORE_SCRIPT="$r"
        break
    fi
done

# ------------------------------------------------------------------------------
# 3. Singleton Process Check
# ------------------------------------------------------------------------------
if [ -f "$LOCK" ]; then
    OLD_PID="$(cat "$LOCK" 2>/dev/null)"
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') Already running (PID $OLD_PID). Exiting." >> "$LOG_FILE"
        exit 0
    fi
fi
echo $$ > "$LOCK"

echo "$(date '+%Y-%m-%d %H:%M:%S') [TRMNL] Starting loop. URL: $DASHBOARD_URL, Interval: ${INTERVAL}s" >> "$LOG_FILE"

# ------------------------------------------------------------------------------
# 4. Stop Reader UI and Prevent Screensaver
# ------------------------------------------------------------------------------
# Stopping lab126_gui gives full control of framebuffer to eips without GUI fight
if command -v stop >/dev/null 2>&1; then
    stop lab126_gui >/dev/null 2>&1 || true
elif [ -x /sbin/stop ]; then
    /sbin/stop lab126_gui >/dev/null 2>&1 || true
fi

lipc-set-prop com.lab126.powerd preventScreenSaver 1 >/dev/null 2>&1 || true

# ------------------------------------------------------------------------------
# 5. Hardware Input Escape Hatch
# ------------------------------------------------------------------------------
# When lab126_gui is stopped, touchscreen does not navigate the reader UI.
# We listen directly to Linux kernel input events (/dev/input/event0 = power button,
# /dev/input/event1 = touchscreen) in the background so pressing power or touching
# the screen automatically triggers restore.sh to bring back the reader UI!
if [ "$ENABLE_ESCAPE_HATCH" = "1" ] && [ -n "$RESTORE_SCRIPT" ]; then
    rm -f /tmp/trmnl_watchers.pid
    (
        # Wait 3 seconds so initial tap on KUAL doesn't immediately trigger escape
        sleep 3
        for ev in /dev/input/event0 /dev/input/event1; do
            if [ -e "$ev" ]; then
                (
                    dd if="$ev" bs=16 count=1 >/dev/null 2>&1
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [ESCAPE] Input detected on $ev, restoring UI..." >> "$LOG_FILE"
                    sh "$RESTORE_SCRIPT"
                ) &
                echo $! >> /tmp/trmnl_watchers.pid
            fi
        done
    ) &
fi

# ------------------------------------------------------------------------------
# 6. Helper Functions
# ------------------------------------------------------------------------------
fetch_image() {
    local target="$1"
    rm -f "$target"
    if command -v curl >/dev/null 2>&1; then
        curl -fs -m 20 -o "$target" "$DASHBOARD_URL" 2>/dev/null
    else
        wget -q -T 20 -O "$target" "$DASHBOARD_URL" 2>/dev/null
    fi
}

get_battery() {
    if [ -f /sys/devices/system/yoshi_battery/battery_capacity ]; then
        cat /sys/devices/system/yoshi_battery/battery_capacity 2>/dev/null
    elif [ -f /sys/class/power_supply/battery/capacity ]; then
        cat /sys/class/power_supply/battery/capacity 2>/dev/null
    elif [ -f /sys/class/power_supply/max77696-battery/capacity ]; then
        cat /sys/class/power_supply/max77696-battery/capacity 2>/dev/null
    else
        echo 100
    fi
}

# ------------------------------------------------------------------------------
# 7. Main Rendering Loop
# ------------------------------------------------------------------------------
COUNT=0

while true; do
    # Check battery level
    BATT="$(get_battery | tr -d '\r\n')"
    if [ -n "$BATT" ] && [ "$BATT" -lt "$LOW_BATTERY_THRESHOLD" ] 2>/dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [TRMNL] Battery low (${BATT}%). Exiting loop." >> "$LOG_FILE"
        if command -v eips >/dev/null 2>&1; then
            eips 0 38 "TRMNL: Low Battery (${BATT}%). Dashboard paused." 2>/dev/null || true
            eips 0 39 "Please connect Kindle to charger." 2>/dev/null || true
        fi
        if [ -n "$RESTORE_SCRIPT" ]; then
            sh "$RESTORE_SCRIPT"
        fi
        exit 0
    fi

    # Attempt download
    fetch_image "$OUT_TMP"

    # If fetch failed, attempt Wi-Fi reconnection and retry once
    if [ ! -s "$OUT_TMP" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [TRMNL] Fetch failed. Reconnecting Wi-Fi..." >> "$LOG_FILE"
        lipc-set-prop com.lab126.cmd ensureConnection wifi >/dev/null 2>&1 || true
        sleep 5
        fetch_image "$OUT_TMP"
    fi

    # Render image if download succeeded
    if [ -s "$OUT_TMP" ]; then
        mv "$OUT_TMP" "$OUT"
        
        # Periodic full refresh to clear e-ink ghosting
        if [ "$FULL_REFRESH_EVERY" -gt 0 ] && [ $((COUNT % FULL_REFRESH_EVERY)) -eq 0 ]; then
            eips -c
            sleep 1
        fi

        eips -g "$OUT"
        COUNT=$((COUNT + 1))
        echo "$(date '+%Y-%m-%d %H:%M:%S') [TRMNL] Rendered cycle #$COUNT" >> "$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [TRMNL] Warning: Unable to fetch image from $DASHBOARD_URL" >> "$LOG_FILE"
    fi

    sleep "$INTERVAL"
done
