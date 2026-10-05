#!/bin/sh
# ==============================================================================
# Kindle Initial Setup Script: kindle-trmnl-dashboard
# Optimized for: Kindle WP63GW (7th Gen Basic - KT2 / Touch 2)
# Run once on your jailbroken Kindle: sh /mnt/us/kindle-trmnl-dashboard/setup.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/config.sh"

echo "=================================================="
echo "🔧 Configuring Kindle TRMNL Dashboard Display"
echo "   Target Device: Kindle WP63GW (7th Gen Basic)"
echo "   Server URL:    ${SERVER_URL}"
echo "=================================================="

# 1. Make all helper scripts executable
chmod +x "${SCRIPT_DIR}"/*.sh 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/bin"/* 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/kual/kindle-trmnl/bin"/* 2>/dev/null || true

# 2. Check for fbink binary
FOUND_FBINK=""
if [ -n "$FBINK_BIN" ] && [ -x "$FBINK_BIN" ]; then
    FOUND_FBINK="$FBINK_BIN"
elif [ -x "${SCRIPT_DIR}/bin/fbink" ]; then
    FOUND_FBINK="${SCRIPT_DIR}/bin/fbink"
elif command -v fbink >/dev/null 2>&1; then
    FOUND_FBINK="$(command -v fbink)"
elif [ -x "/usr/bin/fbink" ]; then
    FOUND_FBINK="/usr/bin/fbink"
elif [ -x "/mnt/us/bin/fbink" ]; then
    FOUND_FBINK="/mnt/us/bin/fbink"
fi

if [ -n "$FOUND_FBINK" ]; then
    echo "✅ Found fbink at: $FOUND_FBINK"
else
    echo "⚠️  fbink binary not found in standard paths!"
    echo "   Please download the NiLuJe FBInk binary for your Kindle model and copy it to:"
    echo "   ${SCRIPT_DIR}/bin/fbink"
fi

# 3. Disable screensaver and power down timers
echo "🔌 Disabling Kindle screensaver timeout..."
lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null || true

# 4. Frontlight Handling:
# WP63GW does not have a frontlight (unlike Paperwhite). Check before calling.
if [ -d /sys/class/backlight ] && [ -n "$(ls -A /sys/class/backlight 2>/dev/null)" ]; then
    echo "💡 Frontlight detected, dimming to 0 to save battery..."
    lipc-set-prop -i com.lab126.powerd flAsynchronouseLevel 0 2>/dev/null || true
    echo 0 > /sys/class/backlight/*/brightness 2>/dev/null || true
else
    echo "💡 No frontlight hardware detected (Kindle WP63GW Basic). Skipping frontlight adjustment."
fi

# 5. Disable background indexing to prevent unwanted battery drain
echo "🛑 Unloading background book indexer..."
lipc-set-prop com.lab126.blanket unload 2>/dev/null || true

# 6. Auto-install KUAL Extension to /mnt/us/extensions/kindle-trmnl
if [ -d "/mnt/us/extensions" ]; then
    echo "📦 Installing KUAL extension to /mnt/us/extensions/kindle-trmnl..."
    mkdir -p /mnt/us/extensions/kindle-trmnl/bin
    cp -f "${SCRIPT_DIR}/kual/kindle-trmnl/config.xml" /mnt/us/extensions/kindle-trmnl/
    cp -f "${SCRIPT_DIR}/kual/kindle-trmnl/menu.json" /mnt/us/extensions/kindle-trmnl/
    cp -f "${SCRIPT_DIR}/kual/kindle-trmnl/bin/"*.sh /mnt/us/extensions/kindle-trmnl/bin/
    chmod +x /mnt/us/extensions/kindle-trmnl/bin/*.sh 2>/dev/null || true
    echo "✅ KUAL extension installed! You will see 'Kindle TRMNL' in your KUAL menu."
else
    echo "ℹ️  /mnt/us/extensions directory not found. Please ensure KUAL is installed."
fi

# 7. Test connection to server
echo "🌐 Testing connection to server: $SERVER_URL/api/setup ..."
lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null || true
sleep 4

SETUP_STATUS=$(curl -s -m 8 "$SERVER_URL/api/setup" 2>/dev/null || wget -q -O - "$SERVER_URL/api/setup" 2>/dev/null)

if echo "$SETUP_STATUS" | grep -q "Connected to self-hosted TRMNL"; then
    echo "✅ Successfully connected to self-hosted TRMNL server at $SERVER_URL!"
else
    echo "⚠️  Could not reach server at $SERVER_URL. Please verify your Wi-Fi and SERVER_URL in config.sh."
fi

# Turn Wi-Fi back off
lipc-set-prop com.lab126.cmd wirelessEnable 0 2>/dev/null || true

echo "=================================================="
echo "🎉 Setup complete! You can now launch the dashboard via KUAL"
echo "   or run: sh ${SCRIPT_DIR}/display.sh"
echo "=================================================="