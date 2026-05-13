#!/usr/bin/env bash
# Thin wrapper for scripts/eso_addon_health.py (bash per repo convention).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Match scripts/deploy_steam_eso_addons.sh when ESO_ADDONS is unset.
export ESO_ADDONS="${ESO_ADDONS:-$HOME/.steam/steam/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/AddOns}"
exec python3 "$SCRIPT_DIR/eso_addon_health.py" "$@"
