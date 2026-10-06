#!/bin/sh
##############################################################################
# Kindle Online Screensaver Installer
#
# Supports:
#   1) USB Mass Storage (auto-detects /Volumes/Kindle on macOS or /media on Linux)
#   2) Network Transfer via SCP (copy directly over Wi-Fi / SSH)
##############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXT_DIR="${SCRIPT_DIR}/extensions/onlinescreensaver"

echo "=========================================================="
echo "      Kindle Online Screensaver Extension Installer       "
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

    TARGET="${KINDLE_MOUNT}/extensions/onlinescreensaver"
    echo "Installing extension to ${TARGET}..."
    mkdir -p "${KINDLE_MOUNT}/extensions"
    rm -rf "${TARGET}"
    cp -r "${EXT_DIR}" "${TARGET}"

    # Also ensure linkss screensavers folder exists in case NiLuJe hack is used
    mkdir -p "${KINDLE_MOUNT}/linkss/screensavers" 2>/dev/null || true

    echo ""
    echo "Files successfully copied to Kindle USB drive!"
    echo ""
    echo "Next steps:"
    echo "  1. Safely eject the Kindle drive from your computer."
    echo "  2. Unplug the USB cable."
    echo "  3. Open KUAL on your Kindle."
    echo "  4. Tap 'Online Screensaver' -> 'Enable auto-download'."
    echo "  5. Tap 'Update now' or put your Kindle to sleep to verify the display!"
    echo ""

elif [ "$METHOD" = "2" ]; then
    printf "Enter Kindle IP address (e.g. 10.0.0.x): "
    read -r KINDLE_IP
    if [ -z "$KINDLE_IP" ]; then
        echo "Error: Kindle IP cannot be empty." >&2
        exit 1
    fi

    echo "Copying files via scp to root@${KINDLE_IP}:/mnt/us/extensions/onlinescreensaver ..."
    ssh "root@${KINDLE_IP}" "mkdir -p /mnt/us/extensions"
    scp -r "${EXT_DIR}" "root@${KINDLE_IP}:/mnt/us/extensions/"
    ssh "root@${KINDLE_IP}" "chmod +x /mnt/us/extensions/onlinescreensaver/bin/*.sh"

    echo ""
    echo "Files successfully copied over Wi-Fi!"
    echo ""
    echo "Next steps:"
    echo "  1. Open KUAL on your Kindle."
    echo "  2. Tap 'Online Screensaver' -> 'Enable auto-download'."
    echo "  3. Put your Kindle to sleep to verify the display!"
    echo ""
else
    echo "Invalid choice. Exiting."
    exit 1
fi
