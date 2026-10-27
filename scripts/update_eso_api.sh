#!/usr/bin/env bash
# Refresh the vendored FlatBadger eso-api tree (LuaLS breadth library).
#
# The ESOUI zip *is* FlatBadger's release (info4074). Same project as
# github.com/Flat-Badger-1971/eso-api; ESOUI is usually newer than GitHub tags.
# Does not touch .shared/eso-api-stubs/eso_api_prefix.lua.
#
# Usage:
#   scripts/update_eso_api.sh              # download latest ESOUI zip, replace vendor
#   scripts/update_eso_api.sh --check      # print current vs latest, do not write
#   scripts/update_eso_api.sh --from-zip PATH.zip
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST="$REPO/.shared/eso-api"
PREFIX="$REPO/.shared/eso-api-stubs/eso_api_prefix.lua"
ESOUI_INFO_URL="https://www.esoui.com/downloads/info4074-ESOluaAPIintellisenseforVisualStudioCode.html"
ESOUI_FILE_ID="4074"

if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
    C_RST="" C_MAUVE="" C_GREEN="" C_PEACH="" C_RED="" C_YELLOW="" C_SUB=""
else
    C_RST=$'\033[0m'
    C_MAUVE=$'\033[38;2;203;166;247m'
    C_GREEN=$'\033[38;2;166;227;161m'
    C_PEACH=$'\033[38;2;250;179;135m'
    C_RED=$'\033[38;2;243;139;168m'
    C_YELLOW=$'\033[38;2;249;226;175m'
    C_SUB=$'\033[38;2;166;173;200m'
fi

log() { printf '%s[eso-api]%s %s\n' "${C_MAUVE}" "${C_RST}" "$*"; }
log_ok() { printf '%s[eso-api]%s %s✔%s %s\n' "${C_MAUVE}" "${C_RST}" "${C_GREEN}" "${C_RST}" "$*"; }
log_warn() { printf '%s[eso-api]%s %s⚠%s %s\n' "${C_MAUVE}" "${C_RST}" "${C_YELLOW}" "${C_RST}" "$*"; }
log_err() { printf '%s[eso-api]%s %s✖%s %s\n' "${C_MAUVE}" "${C_RST}" "${C_RED}" "${C_RST}" "$*" >&2; }

usage() {
    cat <<'EOF'
Refresh vendored FlatBadger eso-api from ESOUI (info4074).

  scripts/update_eso_api.sh
  scripts/update_eso_api.sh --check
  scripts/update_eso_api.sh --from-zip /path/to/eso-api-update-NN.zip

The prefix (.shared/eso-api-stubs/eso_api_prefix.lua) is never overwritten.
EOF
}

MODE="update"
FROM_ZIP=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check) MODE="check"; shift ;;
        --from-zip)
            FROM_ZIP="${2:-}"
            [[ -n "$FROM_ZIP" ]] || { log_err "--from-zip needs a path"; exit 2; }
            shift 2
            ;;
        -h|--help) usage; exit 0 ;;
        *) log_err "unknown arg: $1"; usage >&2; exit 2 ;;
    esac
done

current_package() {
    if [[ -f "$DEST/SOURCE.txt" ]]; then
        grep -oE 'eso-api-update-[0-9]+\.zip' "$DEST/SOURCE.txt" | head -1 || true
    fi
}

fetch_esoui_listing() {
    # Prints: <zip-basename> <cdn-url>
    # The info page shows "Version: update-N" (not the zip filename).
    # The CDN path is file4074/eso-api-update-N.zip — do not probe other N values;
    # unknown names still return HTTP 200 with the current zip bytes.
    local html version zip_name
    html="$(curl -fsSL --max-time 45 "$ESOUI_INFO_URL")" || return 1
    version="$(printf '%s\n' "$html" | grep -oE 'Version:[[:space:]]*update-[0-9]+' | head -1 | grep -oE 'update-[0-9]+' || true)"
    if [[ -z "$version" ]]; then
        version="$(printf '%s\n' "$html" | grep -oE 'id="version">Version:[[:space:]]*update-[0-9]+' | grep -oE 'update-[0-9]+' | head -1 || true)"
    fi
    if [[ -z "$version" ]]; then
        return 1
    fi
    zip_name="eso-api-${version}.zip"
    printf '%s\thttps://cdn.esoui.com/downloads/file%s/%s\n' "$zip_name" "$ESOUI_FILE_ID" "$zip_name"
}

woodworking_line() {
    local globals="$1"
    grep -E '^CRAFTING_TYPE_WOODWORKING[[:space:]]*=' "$globals" | head -1 || true
}

verify_extract() {
    local root="$1"
    local globals="$root/library/globals.lua"
    if [[ ! -f "$root/config.json" ]] || [[ ! -f "$globals" ]]; then
        log_err "extract is not a FlatBadger eso-api tree (need config.json + library/globals.lua)"
        return 1
    fi
    local line
    line="$(woodworking_line "$globals")"
    if [[ -z "$line" ]]; then
        log_err "CRAFTING_TYPE_WOODWORKING missing from library/globals.lua"
        return 1
    fi
    if [[ "$line" =~ =[[:space:]]*nil ]]; then
        log_err "CRAFTING_TYPE_WOODWORKING is nil (refusing this package)"
        return 1
    fi
    if [[ ! "$line" =~ =[[:space:]]*6[[:space:]]*$ ]]; then
        log_warn "CRAFTING_TYPE_WOODWORKING is not 6: ${C_PEACH}${line}${C_RST}"
    else
        log_ok "CRAFTING_TYPE_WOODWORKING = 6"
    fi
    return 0
}

write_source_txt() {
    local dest="$1"
    local package="$2"
    local extra="$3"
    {
        printf '%s\n' \
            'Vendored FlatBadger eso-api (LuaLS / VS Code IntelliSense).' \
            "ESOUI: ${ESOUI_INFO_URL}" \
            "Package: ${package}" \
            "Fetched: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        if [[ -n "$extra" ]]; then
            printf '%s\n' "$extra"
        fi
        printf '%s\n' \
            'GitHub (often lags ESOUI): https://github.com/Flat-Badger-1971/eso-api' \
            'Do not regenerate from UESP. Run scripts/update_eso_api.sh after a major ESO update.'
    } > "$dest/SOURCE.txt"
}

install_tree() {
    local extracted="$1"
    local package="$2"
    local extra="$3"
    if [[ ! -f "$PREFIX" ]]; then
        log_err "prefix missing (refusing to continue): $PREFIX"
        return 1
    fi
    local staging
    staging="$(mktemp -d "${TMPDIR:-/tmp}/eso-api-stage.XXXXXX")"
    cp -a "$extracted"/. "$staging/"
    write_source_txt "$staging" "$package" "$extra"
    rm -rf "$DEST"
    mkdir -p "$(dirname "$DEST")"
    mv "$staging" "$DEST"
    log_ok "installed ${C_PEACH}${package}${C_RST} -> ${C_SUB}.shared/eso-api${C_RST}"
}

[[ -f "$PREFIX" ]] || { log_err "prefix missing: $PREFIX"; exit 1; }

CURRENT="$(current_package || true)"
log "current vendor: ${C_SUB}${CURRENT:-none}${C_RST}"

if [[ -n "$FROM_ZIP" ]]; then
    FROM_ZIP="$(readlink -f "$FROM_ZIP")"
    [[ -f "$FROM_ZIP" ]] || { log_err "zip not found: $FROM_ZIP"; exit 1; }
    PACKAGE="$(basename "$FROM_ZIP")"
    if [[ "$MODE" == "check" ]]; then
        log "local zip: ${C_PEACH}${PACKAGE}${C_RST}"
        exit 0
    fi
    work="$(mktemp -d "${TMPDIR:-/tmp}/eso-api-zip.XXXXXX")"
    trap 'rm -rf "$work"' EXIT
    unzip -q "$FROM_ZIP" -d "$work/extract"
    # Zip root is usually eso-api-update-N/ or eso-api/
    inner="$(find "$work/extract" -mindepth 1 -maxdepth 2 -type f -name config.json | head -1)"
    [[ -n "$inner" ]] || { log_err "no config.json in zip"; exit 1; }
    root="$(dirname "$inner")"
    verify_extract "$root"
    install_tree "$root" "$PACKAGE" "Source zip: ${FROM_ZIP}"
    exit 0
fi

listing="$(fetch_esoui_listing)" || {
    log_err "could not read ESOUI listing (${ESOUI_INFO_URL})"
    log_err "pass --from-zip if you already downloaded the package"
    exit 1
}
LATEST_ZIP="$(printf '%s\n' "$listing" | cut -f1)"
LATEST_URL="$(printf '%s\n' "$listing" | cut -f2)"
log "latest ESOUI package: ${C_PEACH}${LATEST_ZIP}${C_RST}"

if [[ "$MODE" == "check" ]]; then
    if [[ "$CURRENT" == "$LATEST_ZIP"* ]] || [[ "$CURRENT" == "$LATEST_ZIP" ]]; then
        log_ok "vendor already matches latest"
        exit 0
    fi
    log_warn "vendor is behind; run scripts/update_eso_api.sh (no --check) to refresh"
    exit 0
fi

if [[ "$CURRENT" == "$LATEST_ZIP" ]]; then
    log_ok "already at ${LATEST_ZIP}"
    exit 0
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/eso-api-zip.XXXXXX")"
trap 'rm -rf "$work"' EXIT
log "downloading ${C_SUB}${LATEST_URL}${C_RST}"
curl -fL --max-time 120 -o "$work/pkg.zip" "$LATEST_URL"
unzip -q "$work/pkg.zip" -d "$work/extract"
inner="$(find "$work/extract" -mindepth 1 -maxdepth 2 -type f -name config.json | head -1)"
[[ -n "$inner" ]] || { log_err "no config.json in downloaded zip"; exit 1; }
root="$(dirname "$inner")"
verify_extract "$root"
install_tree "$root" "$LATEST_ZIP" "CDN: ${LATEST_URL}"
log "prefix unchanged: ${C_SUB}.shared/eso-api-stubs/eso_api_prefix.lua${C_RST}"
