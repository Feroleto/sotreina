#!/usr/bin/env bash
# Build + sign + install SoTreina on the iPhone. Run weekly: a free Apple ID
# signature expires after 7 days and the app won't open until reinstalled
# (installing over it keeps the app's data). Extra args go to `xtool dev run`
# (e.g. --udid <id>, -c release).
set -euo pipefail
cd "$(dirname "$0")/.."
exec xtool dev run "$@"
