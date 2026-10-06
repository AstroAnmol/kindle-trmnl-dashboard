#!/bin/sh
# ==============================================================================
# Kindle TRMNL - Restore Kindle Reader UI
# Stops the dashboard loop and brings back the reader interface & touchscreen.
# Can be run via KUAL, SSH, or triggered automatically by the escape hatch.
# ==============================================================================

set -u

# Ensure essential binary paths are present (start/stop are in /sbin)
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
export PATH

LOG_FILE=/tmp/trmnl.log
echo "$(date '+%Y-%m-%d %H:%M:%S') [RESTORE] Stopping dashboard and restoring UI..." >> "$LOG_FILE" 2>/dev/null

# 1. Kill any running trmnl.sh dashboard loop processes
for d in /proc/[0-9]*; do
    [ -r "$d/cmdline" ] || continue
    cmd="$(cat "$d/cmdline" 2>/dev/null | tr '\0' ' ')"
    case "$cmd" in
        *trmnl.sh*|*dashink.sh*)
            pid="${d#/proc/}"
            if [ "$pid" != "$$" ]; then
                kill -9 "$pid" 2>/dev/null || true
            fi
            ;;
    esac
done

# 2. Kill background input watcher processes if any
if [ -f /tmp/trmnl_watchers.pid ]; then
    for wpid in $(cat /tmp/trmnl_watchers.pid 2>/dev/null); do
        kill -9 "$wpid" 2>/dev/null || true
    done
    rm -f /tmp/trmnl_watchers.pid
fi

# 3. Clean up PID and lock files
rm -f /tmp/trmnl.pid /tmp/dashink.pid

# 4. Re-enable screensaver
lipc-set-prop com.lab126.powerd preventScreenSaver 0 >/dev/null 2>&1 || true

# 5. Clear display to remove dashboard frame
if command -v eips >/dev/null 2>&1; then
    eips -c
fi

# 6. Restart the Kindle reader GUI
if command -v start >/dev/null 2>&1; then
    start lab126_gui >/dev/null 2>&1 || true
elif [ -x /sbin/start ]; then
    /sbin/start lab126_gui >/dev/null 2>&1 || true
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') [RESTORE] lab126_gui restarted." >> "$LOG_FILE" 2>/dev/null

if command -v eips >/dev/null 2>&1; then
    eips 0 39 "TRMNL: Reader UI restored" 2>/dev/null || true
fi

exit 0
