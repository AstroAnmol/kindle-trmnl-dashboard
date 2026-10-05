#!/bin/sh
# ==============================================================================
# Kindle Client Configuration: kindle-trmnl-dashboard
# Optimized for: Kindle WP63GW (7th Gen Basic - KT2 / Touch 2)
# ==============================================================================

# Server URL (IP address of your Docker host machine: 10.0.0.219:5055)
SERVER_URL="http://10.0.0.219:5055"

# Optional: Device Access Token (defaults to Kindle MAC address if empty)
API_TOKEN=""

# Default sleep interval between updates in seconds (if not returned by server)
# 900 = 15 minutes, 1800 = 30 minutes, 3600 = 1 hour
DEFAULT_INTERVAL=900

# Screen orientation for fbink:
# On Kindle WP63GW (portrait 600x800 physical panel):
# 1 = Landscape (rotated 90° clockwise - 800x600 display)
# 3 = Landscape (rotated 270° / inverted landscape)
# 0 = Portrait (native 600x800)
FBINK_ROTATION=1

# Seconds to wait for Wi-Fi association before giving up
WIFI_TIMEOUT=20

# Low battery threshold percentage (shows low-battery screen and sleeps longer)
LOW_BATTERY_THRESHOLD=10

# Extended sleep duration when battery is critically low (24 hours = 86400)
CRITICAL_SLEEP_INTERVAL=86400

# Path to fbink binary (leave empty to auto-detect)
FBINK_BIN=""

# Log file path
LOG_FILE="/tmp/kindle-trmnl.log"