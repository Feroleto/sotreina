#!/usr/bin/env bash
# Screenshot the iPhone over the cable. iOS 17+ dropped lockdown's
# screenshotr service (idevicescreenshot fails), so this goes through the
# Instruments DVT service over a CoreDevice tunnel, using pymobiledevice3's
# pure-Python userspace tunnel: no root, no manual Developer Disk Image mount.
#   python3 -m venv ~/.local/share/pymobiledevice3
#   ~/.local/share/pymobiledevice3/bin/pip install pymobiledevice3
#   ln -s ~/.local/share/pymobiledevice3/bin/pymobiledevice3 ~/.local/bin/
# Usage: scripts/screenshot.sh [out.png]   (native 1179x2556, ~1.7s)
set -euo pipefail
source "$(dirname "$0")/usbmux.sh"
out="${1:-screenshot-$(date +%Y%m%d-%H%M%S).png}"
mkdir -p "$(dirname "$out")"
pymobiledevice3 developer dvt screenshot --userspace "$out"
echo "$out"
