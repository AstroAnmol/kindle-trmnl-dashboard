#!/bin/sh
BASE_DIR="/mnt/us/kindle-trmnl-dashboard"
if [ ! -d "$BASE_DIR" ]; then
    BASE_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
fi

nohup sh "${BASE_DIR}/display.sh" >/tmp/kindle-once.log 2>&1 &