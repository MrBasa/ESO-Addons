#!/usr/bin/env bash
# Shared Catppuccin Mocha status helpers for operator-facing bash scripts.
# Source this file; do not execute it.
# Honors NO_COLOR. Colors when stdout is a TTY, or FORCE_COLOR is set and not 0
# (VS Code / Cursor task terminals often are not a TTY but still render ANSI).

if [[ -n "${_MOCHA_LOADED:-}" ]]; then
  return 0 2>/dev/null || true
fi
_MOCHA_LOADED=1

MOCHA_TAG="${MOCHA_TAG:-task}"
MOCHA_TITLE="${MOCHA_TITLE:-}"
MOCHA_STARTED_AT="${MOCHA_STARTED_AT:-0}"
MOCHA_WARN="${MOCHA_WARN:-0}"
_MOCHA_FINISHED=0

if [[ -n "${NO_COLOR:-}" ]]; then
  _mocha_color=0
elif [[ -t 1 ]]; then
  _mocha_color=1
elif [[ -n "${FORCE_COLOR:-}" && "${FORCE_COLOR}" != "0" ]]; then
  _mocha_color=1
else
  _mocha_color=0
fi

if ((_mocha_color)); then
  C_RST=$'\033[0m'
  C_MAUVE=$'\033[38;2;203;166;247m'    # #cba6f7
  C_BLUE=$'\033[38;2;137;180;250m'     # #89b4fa
  C_TEAL=$'\033[38;2;148;226;213m'     # #94e2d5
  C_GREEN=$'\033[38;2;166;227;161m'    # #a6e3a1
  C_PEACH=$'\033[38;2;250;179;135m'    # #fab387
  C_RED=$'\033[38;2;243;139;168m'      # #f38ba8
  C_YELLOW=$'\033[38;2;249;226;175m'   # #f9e2af
  C_LAVENDER=$'\033[38;2;180;190;254m' # #b4befe
  C_TEXT=$'\033[38;2;205;214;244m'     # #cdd6f4
  C_SUB=$'\033[38;2;166;173;200m'      # #a6adc8
else
  C_RST="" C_MAUVE="" C_BLUE="" C_TEAL="" C_GREEN="" C_PEACH=""
  C_RED="" C_YELLOW="" C_LAVENDER="" C_TEXT="" C_SUB=""
fi

_mocha_rule() {
  printf '%s────────────────────────────────────────%s\n' "${C_MAUVE}" "${C_RST}"
}

_mocha_elapsed() {
  local s=0
  if ((MOCHA_STARTED_AT > 0)); then
    s=$(($(date +%s) - MOCHA_STARTED_AT))
  fi
  if ((s < 60)); then
    printf '%ss' "${s}"
  else
    printf '%dm %02ds' $((s / 60)) $((s % 60))
  fi
}

log() { printf '%s[%s]%s %s\n' "${C_MAUVE}" "${MOCHA_TAG}" "${C_RST}" "$*"; }
log_ok() { printf '%s[%s]%s %s✔%s %s\n' "${C_MAUVE}" "${MOCHA_TAG}" "${C_RST}" "${C_GREEN}" "${C_RST}" "$*"; }
log_warn() { printf '%s[%s]%s %s⚠%s %s\n' "${C_MAUVE}" "${MOCHA_TAG}" "${C_RST}" "${C_YELLOW}" "${C_RST}" "$*"; }
log_err() { printf '%s[%s]%s %s✖%s %s\n' "${C_MAUVE}" "${MOCHA_TAG}" "${C_RST}" "${C_RED}" "${C_RST}" "$*" >&2; }

mocha_begin() {
  MOCHA_TITLE="$1"
  local detail="${2:-}"
  MOCHA_STARTED_AT="$(date +%s)"
  MOCHA_WARN=0
  _MOCHA_FINISHED=0
  printf '\n'
  _mocha_rule
  printf '%s  ▶  %s%s%s\n' "${C_MAUVE}" "${C_TEXT}" "${MOCHA_TITLE}" "${C_RST}"
  if [[ -n "${detail}" ]]; then
    printf '     %s%s%s\n' "${C_SUB}" "${detail}" "${C_RST}"
  fi
  printf '     %s%s%s\n' "${C_SUB}" "$(date '+%Y-%m-%d %H:%M:%S')" "${C_RST}"
  _mocha_rule
  printf '\n'
}

mocha_finish() {
  local rc="${1:-0}"
  if ((_MOCHA_FINISHED)); then
    return "${rc}"
  fi
  _MOCHA_FINISHED=1
  local elapsed
  elapsed="$(_mocha_elapsed)"
  local title="${MOCHA_TITLE:-${MOCHA_TAG}}"
  printf '\n'
  _mocha_rule
  if ((rc != 0)); then
    printf '%s  ✖  %s failed%s  %s(exit %s, %s)%s\n' \
      "${C_RED}" "${title}" "${C_RST}" "${C_SUB}" "${rc}" "${elapsed}" "${C_RST}"
  elif ((MOCHA_WARN)); then
    printf '%s  ⚠  %s finished with warnings%s  %s(%s)%s\n' \
      "${C_YELLOW}" "${title}" "${C_RST}" "${C_SUB}" "${elapsed}" "${C_RST}"
  else
    printf '%s  ✔  %s complete%s  %s(%s)%s\n' \
      "${C_GREEN}" "${title}" "${C_RST}" "${C_SUB}" "${elapsed}" "${C_RST}"
  fi
  _mocha_rule
  printf '\n'
  return "${rc}"
}

# Quiet rsync: list only transferred/deleted names. Label is the status line.
# Usage: mocha_rsync "label" rsync-args...
mocha_rsync() {
  local label="$1"
  shift
  local out rc=0 n=0
  log "${C_BLUE}${label}${C_RST} ${C_SUB}…${C_RST}"
  out="$(rsync "$@" 2>&1)" || rc=$?
  if ((rc != 0)); then
    log_err "${label} failed (exit ${rc})"
    [[ -n "${out}" ]] && printf '%s\n' "${out}" >&2
    return "${rc}"
  fi
  if [[ -z "${out}" ]]; then
    log_ok "${C_SUB}up to date${C_RST}"
    return 0
  fi
  n="$(printf '%s\n' "${out}" | grep -c '.' || true)"
  log_ok "${C_PEACH}${n}${C_RST} ${C_SUB}changed${C_RST}"
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    printf '     %s%s%s\n' "${C_SUB}" "${line}" "${C_RST}"
  done <<<"${out}"
}
