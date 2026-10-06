#!/bin/sh
##############################################################################
# KOReader TRMNL Plugin Installer
#
# Copies trmnl.koplugin to KOReader's plugins folder on your Kindle.
##############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_SRC="${SCRIPT_DIR}/plugins/trmnl.koplugin"

echo "=========================================================="
echo "         KOReader TRMNL Dashboard Plugin Installer        "
echo "=========================================================="
echo ""
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

    TARGET_PLUGINS="${KINDLE_MOUNT}/koreader/plugins"
    if [ ! -d "${TARGET_PLUGINS}" ]; then
        mkdir -p "${TARGET_PLUGINS}"
    fi

    TARGET="${TARGET_PLUGINS}/trmnl.koplugin"
    echo "Installing plugin to ${TARGET}..."
    rm -rf "${TARGET}"
    cp -r "${PLUGIN_SRC}" "${TARGET}"

    # Ensure screensavers directory exists
    mkdir -p "${KINDLE_MOUNT}/koreader/screensavers"

    echo ""
    echo "Done! The plugin is installed."
    echo ""
    echo "Next steps:"
    echo "  1. Safely eject the Kindle drive and unplug USB."
    echo "  2. Open KOReader on your Kindle."
    echo "  3. Tap the top menu ➜ Tools (gear/wrench) ➜ 'TRMNL Dashboard'."
    echo "  4. Tap 'Update Dashboard Now'."
    echo "  5. Put your Kindle to sleep to see your dashboard!"
    echo ""

elif [ "$METHOD" = "2" ]; then
    printf "Enter Kindle IP address (e.g. 10.0.0.x): "
    read -r KINDLE_IP
    if [ -z "$KINDLE_IP" ]; then
        echo "Error: Kindle IP cannot be empty." >&2
        exit 1
    fi

    echo "Copying plugin via scp to root@${KINDLE_IP}:/mnt/us/koreader/plugins/trmnl.koplugin ..."
    ssh "root@${KINDLE_IP}" "mkdir -p /mnt/us/koreader/plugins /mnt/us/koreader/screensavers"
    scp -r "${PLUGIN_SRC}" "root@${KINDLE_IP}:/mnt/us/koreader/plugins/"

    echo ""
    echo "Done! Installed over Wi-Fi."
    echo ""
    echo "Next steps:"
    echo "  1. Open (or restart) KOReader on your Kindle."
    echo "  2. Tap top menu ➜ Tools ➜ 'TRMNL Dashboard'."
    echo "  3. Tap 'Update Dashboard Now'."
    echo "  4. Put your Kindle to sleep to verify the dashboard sleep screen!"
    echo ""
else
    echo "Invalid choice. Exiting."
    exit 1
fi
