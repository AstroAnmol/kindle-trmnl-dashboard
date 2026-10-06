#!/bin/sh
# shellcheck disable=SC2034
#############################################################################
### KNDL-ONLINE-SCREENSAVER CONFIGURATION SETTINGS
#############################################################################

# Interval in MINUTES in which to update the screensaver by default.
DEFAULTINTERVAL=15

# Schedule for updating the screensaver.
# Format: STARTHOUR:STARTMINUTE-ENDHOUR:ENDMINUTE=INTERVAL_IN_MINUTES
# Between midnight and 7am: refresh every 60 min
# Between 7am and 10pm: refresh every 15 min
# Between 10pm and midnight: refresh every 30 min
SCHEDULE="00:00-07:00=60 07:00-22:00=15 22:00-24:00=30"

# URL of screensaver image endpoint on your home server (10.0.0.219:5055)
IMAGE_URI="http://10.0.0.219:5055/api/display/image"

# Auto-detect device model, screen resolution, and screensaver filename.
if [ -e "device.sh" ]; then
	# shellcheck disable=SC1091
	. ./device.sh
	get_device_info
fi

# Fallback for Kindle WP63GW (7th Gen Basic): 600x800 portrait
W=${W:-600}
H=${H:-800}

# Also persist the image to SCREENSAVERFILE on the FAT32 partition if linkss is installed.
# 0 = paint directly via eips without writing FAT partition (safe, saves flash wear)
# 1 = also write to /mnt/us/linkss/screensavers/bg_ss00.png
WRITE_SCREENSAVER=0

# folder that holds the screensavers (if NiLuJe linkss is installed)
SCREENSAVERFOLDER=/mnt/us/linkss/screensavers
SCREENSAVERFILE=${SCREENSAVERFOLDER}/${SCREENSAVER_BASENAME:-bg_ss00.png}

# Whether to append ?w=WIDTH&h=HEIGHT query parameters to IMAGE_URI (0=no, 1=yes)
REQUEST_RESIZE=0

# Whether to disable WiFi after the script has finished updating (1=yes, 0=no).
# Highly recommended for multi-week battery life!
DISABLE_WIFI=1

# Domain/IP to ping to test network connectivity.
# Uses local server IP or fallback 8.8.8.8
TEST_DOMAIN="10.0.0.219"

# How long (in seconds) to wait for an internet connection to be established
NETWORK_TIMEOUT=58

# RTC device index (usually 0 on Kindle)
RTC=0

#############################################################################
# LOGGING (Optional)
#############################################################################

# Whether to create log output (1=yes, 0=no)
LOGGING=0

# Where to log to (buffered in /tmp and flushed safely)
LOGFILE=/mnt/us/extensions/onlinescreensaver/log/onlinescreensaver.log
