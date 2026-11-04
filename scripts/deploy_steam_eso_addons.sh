#!/usr/bin/env bash
# Copy repo add-ons with valid manifests into the Steam Proton live/AddOns tree.
# VS Code task: "Deploy: Steam ESO addons".
# Default: additive cp -a (does not delete stale files).
# Opt-in prune: --prune or DEPLOY_PRUNE=1 removes files under each deployed
# folder that are not present in the matching repo folder.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST_ROOT="${ESO_ADDONS_DIR:-${ESO_ADDONS:-$HOME/.steam/steam/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/AddOns}}"
SKIP_NAMES=".shared .cursor .vscode docs scripts data dist"
PRUNE=0

# shellcheck source=lib/mocha.sh
source "${SCRIPT_DIR}/lib/mocha.sh"

MOCHA_TAG="deploy-eso-addons"

usage() {
  cat <<'EOF'
Usage: deploy_steam_eso_addons.sh [--prune] [--help]

  Copies repo add-on folders into the Steam Proton live/AddOns tree.
  Default is additive (cp -a); stale files are left in place.

  --prune          After copy, delete files under each deployed folder that
                   are not present in the matching repo folder.
  DEPLOY_PRUNE=1   Same as --prune (env).

  ESO_ADDONS_DIR / ESO_ADDONS override the destination root.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --prune) PRUNE=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "${DEPLOY_PRUNE:-0}" == "1" ]]; then
  PRUNE=1
fi

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

# Remove live files under $dest that have no counterpart under $src.
# Requires $dest/$name.txt (or .addon / manifest.txt) so we never prune a
# wrong/empty destination. Only files; empty dirs left behind are harmless.
prune_orphans() {
  local name="$1"
  local src="$2"
  local dest="$3"
  local removed=0

  if [[ ! -d "$dest" ]]; then
    log_warn "prune skip ${name}: dest missing"
    return 0
  fi
  if [[ ! -f "$dest/$name.txt" && ! -f "$dest/$name.addon" && ! -f "$dest/manifest.txt" ]]; then
    MOCHA_WARN=1
    log_warn "prune refused ${name}: no manifest in dest (${dest})"
    return 0
  fi

  while IFS= read -r -d '' live_file; do
    local rel="${live_file#"$dest"/}"
    if [[ ! -e "$src/$rel" ]]; then
      log "${C_YELLOW}prune${C_RST} ${C_SUB}${name}/${rel}${C_RST}"
      rm -f "$live_file"
      removed=$((removed + 1))
    fi
  done < <(find "$dest" -type f -print0)

  if ((removed > 0)); then
    log_ok "pruned ${C_PEACH}${removed}${C_RST} ${C_SUB}orphan(s) from ${name}${C_RST}"
  fi
}

cd "$REPO"

mocha_begin "Deploy: Steam ESO addons" \
  "repo add-ons → ${DEST_ROOT}"

trap 'rc=$?; mocha_finish "${rc}"; exit "${rc}"' EXIT

if ((PRUNE)); then
  log "${C_LAVENDER}prune enabled${C_RST} ${C_SUB}(--prune / DEPLOY_PRUNE=1)${C_RST}"
fi

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
  if ((PRUNE)); then
    prune_orphans "$name" "$REPO/$name" "$dest"
  fi
  log_ok "${name}"
  copied=$((copied + 1))
done

if ((copied == 0)); then
  MOCHA_WARN=1
  log_warn "no add-ons with valid manifests"
else
  log_ok "${C_PEACH}${copied}${C_RST} ${C_SUB}add-on(s) copied${C_RST}"
fi
