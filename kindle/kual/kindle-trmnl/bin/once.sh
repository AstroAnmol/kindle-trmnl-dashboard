#!/bin/sh
BASE_DIR="/mnt/us/kindle-trmnl-dashboard"
if [ ! -d "$BASE_DIR" ]; then
    BASE_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
fi

sh "${BASE_DIR}/display.sh"