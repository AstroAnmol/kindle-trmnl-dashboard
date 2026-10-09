#!/bin/sh
##############################################################################
# KOReader Kindle Dashboard Plugin Installer
# Tailored for Amazon Kindle WP63GW (7th Gen Basic, firmware 5.12.2.2)
#
# Supports:
#   1) USB Mass Storage (auto-detects /Volumes/Kindle on macOS or /media on Linux)
#   2) Wi-Fi / SSH (copies directly via SCP over local network)
##############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_SRC="${SCRIPT_DIR}/plugins/dashboard.koplugin"

echo "=========================================================="
echo "    Kindle Dashboard Plugin Installer for KOReader        "
echo "=========================================================="
echo ""

if [ ! -d "${PLUGIN_SRC}" ]; then
    echo "Error: Plugin source not found at '${PLUGIN_SRC}'" >&2
    exit 1
fi

echo "Select installation method:"
echo "  1) USB Cable (Kindle mounted as drive)"
echo "  2) Wi-Fi / SSH (Copy via SCP)"
printf "Enter choice [1-2, default: 1]: "
read -r METHOD
METHOD="${METHOD:-1}"

if [ "$METHOD" = "1" ]; then
    DEFAULT_MOUNT=""
    if [ -d "/Volumes/Kindle" ]; then
        DEFAULT_MOUNT="/Volumes/Kindle"
    elif [ -d "/run/media/${USER}/Kindle" ]; then
        DEFAULT_MOUNT="/run/media/${USER}/Kindle"
    elif [ -d "/media/kindle" ]; then
        DEFAULT_MOUNT="/media/kindle"
    fi

    printf "Kindle USB Mount Path [%s]: " "${DEFAULT_MOUNT}"
    read -r KINDLE_MOUNT
    KINDLE_MOUNT="${KINDLE_MOUNT:-${DEFAULT_MOUNT}}"

    if [ -z "$KINDLE_MOUNT" ] || [ ! -d "$KINDLE_MOUNT" ]; then
        echo "Error: Directory not found: '$KINDLE_MOUNT'" >&2
        echo "Please connect your Kindle via USB and ensure it appears as a drive." >&2
        exit 1
    fi

    DEST_PLUGINS="${KINDLE_MOUNT}/koreader/plugins"
    DEST_SCREENSAVERS="${KINDLE_MOUNT}/koreader/screensavers/dashboard"
    TARGET_PLUGIN="${DEST_PLUGINS}/dashboard.koplugin"

    echo "Ensuring KOReader directories exist..."
    mkdir -p "${DEST_PLUGINS}"
    mkdir -p "${DEST_SCREENSAVERS}"

    # Remove any old flagged/crashed trmnl plugin
    if [ -d "${DEST_PLUGINS}/trmnl.koplugin" ]; then
        echo "Removing obsolete trmnl.koplugin..."
        rm -rf "${DEST_PLUGINS}/trmnl.koplugin"
    fi

    echo "Copying dashboard.koplugin to ${TARGET_PLUGIN}..."
    rm -rf "${TARGET_PLUGIN}"
    cp -r "${PLUGIN_SRC}" "${TARGET_PLUGIN}"

    echo ""
    echo "✅ 'Kindle Dashboard' successfully installed to Kindle USB storage!"
    echo ""
    echo "Next steps on your Kindle:"
    echo "  1. Safely Eject the Kindle drive from your computer."
    echo "  2. Unplug the USB cable."
    echo "  3. Open (or restart) KOReader on your Kindle."
    echo "  4. Tap the top menu bar -> Tools (wrench icon) -> 'Kindle Dashboard'."
    echo "  5. Tap 'Update & Display on Screen Now' to test live rendering!"
    echo "  6. Put your Kindle to sleep to verify the screensaver."
    echo ""

elif [ "$METHOD" = "2" ]; then
    printf "Enter Kindle IP address (e.g. 192.168.1.50): "
    read -r KINDLE_IP
    if [ -z "$KINDLE_IP" ]; then
        echo "Error: Kindle IP cannot be empty." >&2
        exit 1
    fi

    echo "Ensuring remote directories exist via SSH..."
    ssh "root@${KINDLE_IP}" "mkdir -p /mnt/us/koreader/plugins /mnt/us/koreader/screensavers/dashboard && rm -rf /mnt/us/koreader/plugins/trmnl.koplugin"

    echo "Copying plugin via SCP to root@${KINDLE_IP}:/mnt/us/koreader/plugins/dashboard.koplugin ..."
    scp -r "${PLUGIN_SRC}" "root@${KINDLE_IP}:/mnt/us/koreader/plugins/"
    ssh "root@${KINDLE_IP}" "chmod +x /mnt/us/koreader/plugins/dashboard.koplugin/*.sh"

    echo ""
    echo "✅ 'Kindle Dashboard' successfully transferred over Wi-Fi!"
    echo ""
    echo "Next steps on your Kindle:"
    echo "  1. Restart KOReader on your Kindle."
    echo "  2. Tap Tools (wrench icon) -> 'Kindle Dashboard'."
    echo "  3. Tap 'Update & Display on Screen Now' to test!"
    echo ""
else
    echo "Invalid choice. Exiting."
    exit 1
fi
