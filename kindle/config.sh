#!/bin/sh
# ==============================================================================
# Kindle Client Configuration: kindle-trmnl-dashboard
# Edit this file with your server details before copying to Kindle
# ==============================================================================

# Server URL (IP address of your Docker host machine)
SERVER_URL="http://192.168.1.100:5055"

# Optional: Device Access Token (defaults to Kindle MAC address if empty)
API_TOKEN=""

# Default sleep interval between updates in seconds (if not returned by server)
# 900 = 15 minutes, 1800 = 30 minutes, 3600 = 1 hour
DEFAULT_INTERVAL=900

# Screen orientation for fbink:
# 0 = normal (portrait or landscape native), 1 = 90 deg, 2 = 180 deg, 3 = 270 deg
# Alternatively for fbink: -r 0, -r 1, -r 2, -r 3
FBINK_ROTATION=0

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