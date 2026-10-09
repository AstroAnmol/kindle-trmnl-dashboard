#!/bin/sh
##############################################################################
# Background Active Sleep Scheduler for Kindle WP63GW & KOReader
# Handles hardware RTC wakeup alarms and e-ink redraws while Kindle is asleep.
##############################################################################

PIDFILE="/tmp/kindle_dashboard_scheduler.pid"
CONF_DIR="/mnt/us/koreader/settings"
CONFIG_FILE="${CONF_DIR}/dashboard_config.env"
SCREENSAVER_DIR="/mnt/us/koreader/screensavers/dashboard"
SCREENSAVER_FILE="${SCREENSAVER_DIR}/dashboard.png"
ROOT_SCREENSAVER="/mnt/us/koreader/screensavers/dashboard.png"
TMP_IMG="/tmp/dashboard_fetch.png"
LOG_FILE="/tmp/dashboard_scheduler.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${LOG_FILE}"
}

# Ensure single instance
if [ -f "${PIDFILE}" ]; then
    OLD_PID=$(cat "${PIDFILE}" 2>/dev/null)
    if [ -n "${OLD_PID}" ] && kill -0 "${OLD_PID}" 2>/dev/null; then
        if [ "$1" = "stop" ] || [ "$1" = "restart" ]; then
            log "Stopping previous scheduler (PID ${OLD_PID})..."
            kill "${OLD_PID}" 2>/dev/null
            rm -f "${PIDFILE}"
            [ "$1" = "stop" ] && exit 0
        else
            log "Scheduler already running (PID ${OLD_PID}). Exiting."
            exit 0
        fi
    fi
fi

if [ "$1" = "stop" ]; then
    rm -f "${PIDFILE}"
    exit 0
fi

echo "$$" > "${PIDFILE}"
log "Scheduler started with PID $$"

# Ensure directories exist
mkdir -p "${SCREENSAVER_DIR}" 2>/dev/null

currentTime() {
    date +%s
}

load_config() {
    INTERVAL=900
    URL="http://10.0.0.219:5055/api/display/image"
    if [ -f "${CONFIG_FILE}" ]; then
        # shellcheck disable=SC1090
        . "${CONFIG_FILE}"
    fi
}

set_rtc_alarm() {
    DELAY=${1:-900}
    log "Setting hardware RTC wakeup alarm in ${DELAY}s..."
    lipc-set-prop -i com.lab126.powerd rtcWakeup "${DELAY}" 2>/dev/null
    echo "+${DELAY}" > /sys/class/rtc/rtc0/wakealarm 2>/dev/null || true
}

fetch_and_draw() {
    log "Executing background fetch and draw cycle..."
    load_config

    # Hold suspend for 120s so powerd doesn't sleep while downloading
    lipc-set-prop -i com.lab126.powerd deferSuspend 120 2>/dev/null

    # Power up Wi-Fi radio
    lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null

    # Wait for Wi-Fi connection (up to 25s)
    WIFI_OK=0
    for _ in $(seq 1 25); do
        STATE=$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null || echo "")
        if [ "$STATE" = "CONNECTED" ]; then
            WIFI_OK=1
            break
        fi
        sleep 1
    done

    if [ "$WIFI_OK" -eq 1 ]; then
        log "Wi-Fi connected. Fetching image from: ${URL}"

        # Collect battery level & charging status
        BATTERY=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null || cat /sys/devices/system/yoshi_battery/battery_capacity 2>/dev/null || echo "")
        IS_CHARGING=$(lipc-get-prop com.lab126.powerd isCharging 2>/dev/null || echo "0")

        FETCH_URL="${URL}"
        if [ -n "${BATTERY}" ]; then
            case "${FETCH_URL}" in
                *"?"*) FETCH_URL="${FETCH_URL}&batteryLevel=${BATTERY}&isCharging=${IS_CHARGING}" ;;
                *)     FETCH_URL="${FETCH_URL}?batteryLevel=${BATTERY}&isCharging=${IS_CHARGING}" ;;
            esac
        fi

        rm -f "${TMP_IMG}"
        if which wget >/dev/null 2>&1; then
            wget -q -T 20 -O "${TMP_IMG}" "${FETCH_URL}" 2>/dev/null || true
        elif which curl >/dev/null 2>&1; then
            curl -s -m 20 -o "${TMP_IMG}" "${FETCH_URL}" 2>/dev/null || true
        fi

        # Check if valid image downloaded (> 1000 bytes)
        if [ -f "${TMP_IMG}" ]; then
            SIZE=$(wc -c < "${TMP_IMG}" 2>/dev/null || echo 0)
            if [ "${SIZE}" -gt 1000 ]; then
                log "Successfully downloaded new image (${SIZE} bytes)."
                cp "${TMP_IMG}" "${SCREENSAVER_FILE}" 2>/dev/null || true
                cp "${TMP_IMG}" "${ROOT_SCREENSAVER}" 2>/dev/null || true

                # Check if device is in screen saver / sleep
                STATUS=$(lipc-get-prop com.lab126.powerd status 2>/dev/null || echo "Screen Saver")
                log "Device status: ${STATUS}. Repainting e-ink screen with eips..."
                /usr/sbin/eips -f -g "${SCREENSAVER_FILE}" 2>/dev/null || true
            else
                log "Downloaded image too small (${SIZE} bytes). Skipping paint."
            fi
            rm -f "${TMP_IMG}"
        else
            log "Failed to download image."
        fi
    else
        log "Wi-Fi connection timed out. Skipping update."
    fi

    # Release suspend lock
    lipc-set-prop -i com.lab126.powerd deferSuspend 0 2>/dev/null
    log "Update cycle finished."
}

# Main event loop
load_config

while true; do
    load_config
    if [ "${INTERVAL:-900}" -le 0 ]; then
        log "Periodic interval is 0 (Off). Sleeping 60s before re-checking config..."
        sleep 60
        continue
    fi

    DEVICE_STATUS=$(lipc-get-prop com.lab126.powerd status 2>/dev/null || echo "Screen Saver")
    log "Current device state: ${DEVICE_STATUS}"

    case "${DEVICE_STATUS}" in
        *"Screen Saver"*|*"Suspended"*|*"Ready"*)
            # Wait for next update window
            ENDTIME=$(( $(currentTime) + INTERVAL ))
            set_rtc_alarm "${INTERVAL}"

            while true; do
                NOW=$(currentTime)
                REMAINING=$(( ENDTIME - NOW ))
                if [ "${REMAINING}" -le 0 ]; then
                    break
                fi

                # Listen for Kindle powerd state events
                EVENT=$(lipc-wait-event -s "${REMAINING}" com.lab126.powerd readyToSuspend,wakeupFromSuspend,resuming 2>/dev/null)
                log "Powerd event: ${EVENT:-timeout}"

                case "${EVENT}" in
                    readyToSuspend*)
                        REMAINING=$(( ENDTIME - $(currentTime) ))
                        if [ "${REMAINING}" -gt 0 ]; then
                            set_rtc_alarm "${REMAINING}"
                        fi
                        ;;
                    wakeupFromSuspend*|resuming*)
                        # Woke up! Check if time has arrived
                        if [ $(currentTime) -ge "${ENDTIME}" ]; then
                            break
                        fi
                        ;;
                esac
            done

            # Trigger fetch and eips draw
            fetch_and_draw
            ;;
        *"Active"*)
            # User is reading or interacting with KOReader
            log "Device is Active. Waiting for goingToScreenSaver event..."
            lipc-wait-event -s 120 com.lab126.powerd goingToScreenSaver 2>/dev/null || sleep 30
            ;;
        *)
            sleep 30
            ;;
    esac
    sleep 2
done
