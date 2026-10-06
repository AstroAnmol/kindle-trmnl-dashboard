#!/bin/sh
# ==============================================================================
# Kindle TRMNL - KUAL Action: Stop Dashboard Loop
# ==============================================================================

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
export PATH

EXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Locate restore.sh
RESTORE_SCRIPT=""
for r in "${EXT_DIR}/restore.sh" \
         "${EXT_DIR}/../../restore.sh" \
         /mnt/us/kindle-new/restore.sh \
         /mnt/us/restore.sh; do
    if [ -x "$r" ] || [ -f "$r" ]; then
        RESTORE_SCRIPT="$r"
        break
    fi
done

if [ -n "$RESTORE_SCRIPT" ]; then
    chmod +x "$RESTORE_SCRIPT" 2>/dev/null || true
    sh "$RESTORE_SCRIPT"
else
    # Fallback cleanup if restore.sh not located
    for d in /proc/[0-9]*; do
        [ -r "$d/cmdline" ] || continue
        case "$(cat "$d/cmdline" 2>/dev/null | tr '\0' ' ')" in
            *trmnl.sh*|*dashink.sh*)
                pid="${d#/proc/}"
                [ "$pid" != "$$" ] && kill -9 "$pid" 2>/dev/null || true
                ;;
        esac
    done
    rm -f /tmp/trmnl.pid /tmp/trmnl_watchers.pid
    lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null || true
    if command -v start >/dev/null 2>&1; then
        start lab126_gui 2>/dev/null || true
    fi
    if command -v eips >/dev/null 2>&1; then
        eips 0 38 "TRMNL: Dashboard loop stopped." 2>/dev/null || true
    fi
fi

exit 0
