#!/usr/bin/env bash
# (Re)launch SoTreina on the iPhone with environment variables, over the
# same pymobiledevice3 userspace tunnel as screenshot.sh. Kills a running
# instance first, so every call is a cold start. The env only applies to
# this launch: opening the app from the Home Screen afterwards gets none.
# Uses the bundle ID xtool installs under (free account prefix XTL-<team>.).
# Usage: scripts/launch.sh [KEY=VALUE ...]
set -euo pipefail
source "$(dirname "$0")/usbmux.sh"
bundle="${SOTREINA_BUNDLE_ID:-XTL-KBVDP58W3Z.com.feroleto.sotreina}"
env_args=()
for kv in "$@"; do env_args+=(--env "$kv"); done
pymobiledevice3 developer dvt launch --userspace "${env_args[@]}" "$bundle"
