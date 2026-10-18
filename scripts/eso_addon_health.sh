#!/usr/bin/env bash
# Thin wrapper for scripts/eso_addon_health.py (bash per repo convention).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Prefer ESO_ADDONS_DIR (catalog/scan/deploy); keep ESO_ADDONS as legacy alias.
_DEFAULT_ADDONS="$HOME/.steam/steam/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/AddOns"
export ESO_ADDONS_DIR="${ESO_ADDONS_DIR:-${ESO_ADDONS:-$_DEFAULT_ADDONS}}"
export ESO_ADDONS="$ESO_ADDONS_DIR"
exec python3 "$SCRIPT_DIR/eso_addon_health.py" "$@"
