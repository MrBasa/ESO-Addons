#!/usr/bin/env bash
# Copy repo add-ons with valid manifests into the Steam Proton live/AddOns tree.
# VS Code task: "Deploy: Steam ESO addons".
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST_ROOT="${ESO_ADDONS_DIR:-${ESO_ADDONS:-$HOME/.steam/steam/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/AddOns}}"
# LootLogCustom: keep in repo only until you explicitly remove it from this skip list.
SKIP_NAMES=".shared .cursor .vscode docs scripts LootLogCustom"

# shellcheck source=lib/mocha.sh
source "${SCRIPT_DIR}/lib/mocha.sh"

MOCHA_TAG="deploy-eso-addons"

skip_member() {
  local d="$1"
  case " $d " in
    *"/../"*|*"/./"*) return 0 ;;
  esac
  case " $SKIP_NAMES " in
    *" $d "*) return 0 ;;
  esac
  [[ "$d" == .* ]] && return 0
  return 1
}

cd "$REPO"

mocha_begin "Deploy: Steam ESO addons" \
  "repo add-ons → ${DEST_ROOT}"

trap 'rc=$?; mocha_finish "${rc}"; exit "${rc}"' EXIT

copied=0
for dir in */; do
  name="${dir%/}"
  skip_member "$name" && continue
  # ESO addon manifest should match folder name: <AddonName>.txt or .addon.
  # Keep manifest.txt fallback for older local folders.
  [[ -f "$name/$name.txt" || -f "$name/$name.addon" || -f "$name/manifest.txt" ]] || continue
  dest="$DEST_ROOT/$name"
  log "${C_PEACH}${name}${C_RST} ${C_SUB}→ ${dest}${C_RST}"
  mkdir -p "$dest"
  cp -a "$name"/. "$dest/"
  log_ok "${name}"
  copied=$((copied + 1))
done

if ((copied == 0)); then
  MOCHA_WARN=1
  log_warn "no add-ons with valid manifests"
else
  log_ok "${C_PEACH}${copied}${C_RST} ${C_SUB}add-on(s) copied${C_RST}"
fi
