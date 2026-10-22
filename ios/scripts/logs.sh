#!/usr/bin/env bash
# Stream the app's logs (os.Logger) from the iPhone. xtool has no log
# command — this uses libimobiledevice's idevicesyslog over usbmuxd.
#   sudo apt-get install libimobiledevice-utils
# Matches on the line text, so it catches both the app and the
# SoTreinaLiveActivity extension process.
set -euo pipefail
source "$(dirname "$0")/usbmux.sh"
exec idevicesyslog --match SoTreina "$@"
