#!/usr/bin/env bash
# Build BasaToolsSuite-vX.Y.Z.zip for GitHub Releases (top-level AddOns folders).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="${DIST_DIR:-$REPO/dist}"
ADDONS=(BasaTools WritMatch LibScanner MatLog)

# shellcheck source=lib/mocha.sh
source "${SCRIPT_DIR}/lib/mocha.sh"

MOCHA_TAG="package-basatools-suite"

manifest_version() {
  local folder="$1"
  local manifest="$REPO/$folder/$folder.txt"
  if [[ ! -f "$manifest" ]]; then
    manifest="$REPO/$folder/$folder.addon"
  fi
  [[ -f "$manifest" ]] || return 1
  awk -F': *' '/^## Version:/{print $2; exit}' "$manifest" | tr -d '\r'
}

resolve_version() {
  if [[ -n "${1:-}" ]]; then
    echo "${1#v}"
    return
  fi
  if [[ -n "${GITHUB_REF_NAME:-}" && "$GITHUB_REF_NAME" == v* ]]; then
    echo "${GITHUB_REF_NAME#v}"
    return
  fi
  local tag
  tag="$(git -C "$REPO" describe --tags --abbrev=0 2>/dev/null || true)"
  if [[ -n "$tag" ]]; then
    echo "${tag#v}"
    return
  fi
  local bt
  bt="$(manifest_version BasaTools || true)"
  if [[ -n "$bt" ]]; then
    echo "$bt"
    return
  fi
  echo "0.0.0"
}

VERSION="$(resolve_version "${1:-}")"
ZIP_NAME="BasaToolsSuite-v${VERSION}.zip"
STAGE="$DIST_DIR/stage-$$"
OUT="$DIST_DIR/$ZIP_NAME"

mocha_begin "Package: BasaTools suite" "v${VERSION} → ${OUT}"
trap 'rc=$?; rm -rf "$STAGE"; mocha_finish "${rc}"; exit "${rc}"' EXIT

mkdir -p "$DIST_DIR"
rm -rf "$STAGE"
mkdir -p "$STAGE"

for name in "${ADDONS[@]}"; do
  if [[ ! -d "$REPO/$name" ]]; then
    log_err "missing add-on folder: $name"
    exit 1
  fi
  if [[ ! -f "$REPO/$name/$name.txt" && ! -f "$REPO/$name/$name.addon" ]]; then
    log_err "missing manifest: $name/$name.txt"
    exit 1
  fi
  ver="$(manifest_version "$name" || true)"
  if [[ -z "$ver" ]]; then
    log_err "unreadable ## Version in $name"
    exit 1
  fi
  log "${C_PEACH}${name}${C_RST} ${C_SUB}## Version ${ver}${C_RST}"
  cp -a "$REPO/$name" "$STAGE/$name"
done

cp -a "$REPO/LICENSE" "$STAGE/LICENSE"

rm -f "$OUT"
(
  cd "$STAGE"
  if command -v zip >/dev/null 2>&1; then
    zip -qr "$OUT" "${ADDONS[@]}" LICENSE
  else
    python3 - "$OUT" "${ADDONS[@]}" <<'PY'
import sys
import zipfile
from pathlib import Path

out = Path(sys.argv[1])
names = sys.argv[2:]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
    for name in names:
        root = Path(name)
        for path in root.rglob("*"):
            if path.is_file():
                zf.write(path, path.as_posix())
    lic = Path("LICENSE")
    if lic.is_file():
        zf.write(lic, "LICENSE")
PY
  fi
)

log_ok "$OUT"
log_ok "$(du -h "$OUT" | awk '{print $1}') packaged"
