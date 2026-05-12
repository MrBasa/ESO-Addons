#!/usr/bin/env bash
set -euo pipefail

HOME_DIR=~
DEST_ROOT="$HOME_DIR/.steam/steam/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/AddOns"
REPO="$HOME_DIR/Dev/ESO-Addons"
# LootLogCustom: keep in repo only until you explicitly remove it from this skip list.
SKIP_NAMES=".shared .cursor .vscode docs scripts LootLogCustom"

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
echo "Deploying ESO add-ons..."
for dir in */; do
  name="${dir%/}"
  skip_member "$name" && continue
  # ESO addon manifest should match folder name: <AddonName>.txt.
  # Keep manifest.txt fallback for older local folders.
  [[ -f "$name/$name.txt" || -f "$name/manifest.txt" ]] || continue
  dest="$DEST_ROOT/$name"
  echo "Deploying add-on: $name -> $dest"
  mkdir -p "$dest"
  cp -a "$name"/. "$dest/"
done

echo "Deployed add-ons with valid manifests into $DEST_ROOT"
