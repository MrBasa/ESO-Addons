#!/usr/bin/env python3
"""
Generate the machine-derived portion of .shared/eso-api-stubs/eso_api.lua from UESP
ESO Data dumps (globals.txt + globalfuncs.txt).

LuaLS: colon definitions ``function Root:Method()`` are emitted as
``function Root.Method(self, ...)`` with ``---@param self Root`` so instance methods do not
trigger inject-field / "reference" diagnostics. Dot-only names stay as
``function Root.Method(...)``. When UESP lists both ``Root:Method`` and ``Root.Method``,
a single dot+self stub is emitted.

Preserves a hand-edited prefix in eso_api.lua up to the marker:
  -- ============================================================================
  -- BEGIN GENERATED ESO API STUBS
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

UESP_HOST = "https://esoapi.uesp.net"
INDEX_URL = f"{UESP_HOST}/index.html"
CURRENT_URL = f"{UESP_HOST}/current/index.html"

BEGIN_MARKER = (
    "-- ============================================================================\n"
    "-- BEGIN GENERATED ESO API STUBS (scripts/generate_eso_api_stubs.py)\n"
    "-- ============================================================================"
)

GLOBAL_ASSIGN_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=")
GLOBALFUNC_ASSIGN_RE = re.compile(r"^([A-Za-z0-9_.]+)\(\)\s*=\s*")
FUNC_COMMENT_RE = re.compile(r"-- function\s+([A-Za-z0-9_.:]+)\s*\(")
MANUAL_FUNCTION_RE = re.compile(r"^function\s+([A-Za-z0-9_.:]+)\s*\(")
MANUAL_ASSIGN_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=")

REPO_ROOT = Path(__file__).resolve().parent.parent
STUB_PATH = REPO_ROOT / ".shared" / "eso-api-stubs" / "eso_api.lua"
WIKI_MAP_PATH = REPO_ROOT / ".shared" / "eso-api-stubs" / "wiki_title_map.json"

# Lua 5.1 / common stdlib roots: never emit synthetic tables for these method "roots".
LUA51_GLOBAL_ROOT_SKIP = frozenset({
    "string",
    "table",
    "math",
    "io",
    "os",
    "debug",
    "coroutine",
    "package",
    "_G",
    "bit",
})

UA = "ESO-Addons-stub-generator/1.0 (+local dev)"


def fetch_text(url: str, timeout: int = 120) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="replace")


def discover_latest_version(html: str) -> int:
    found = [int(x) for x in re.findall(r"https://esoapi\.uesp\.net/(\d+)/", html)]
    if not found:
        found = [int(x) for x in re.findall(r"""href=['\"](\d+)/['\"]""", html)]
    if not found:
        raise RuntimeError("Could not parse any API version links from UESP index.")
    return max(found)


def current_page_version(html: str) -> int | None:
    m = re.search(r"ESO Data for API v(\d+)", html)
    if m:
        return int(m.group(1))
    m = re.search(r"API v(\d+)", html)
    if m:
        return int(m.group(1))
    return None


def load_wiki_map() -> dict[str, str]:
    if not WIKI_MAP_PATH.is_file():
        return {}
    data = json.loads(WIKI_MAP_PATH.read_text(encoding="utf-8"))
    return {str(k): str(v) for k, v in data.items()}


def wiki_see_line(symbol: str, wiki_map: dict[str, str]) -> str | None:
    """Phase A: only explicit map entries (avoids mass 404s from guessed wiki titles)."""
    title = wiki_map.get(symbol)
    if not title:
        return None
    url = "https://wiki.esoui.com/wiki/" + quote(title, safe=":")
    return f"---@see {url}"


def extract_manual_reserved(manual: str) -> set[str]:
    reserved: set[str] = set()
    for line in manual.splitlines():
        raw = line.lstrip()
        m = MANUAL_FUNCTION_RE.match(raw)
        if m:
            reserved.add(m.group(1))
            continue
        m = MANUAL_ASSIGN_RE.match(raw)
        if m:
            reserved.add(m.group(1))
    return reserved


def split_existing_stub(path: Path) -> tuple[str, str | None]:
    text = path.read_text(encoding="utf-8") if path.is_file() else ""
    if BEGIN_MARKER in text:
        manual, _, rest = text.partition(BEGIN_MARKER)
        return manual.rstrip() + "\n", rest
    return text.rstrip() + ("\n" if text and not text.endswith("\n") else ""), None


def parse_globals_txt(content: str) -> set[str]:
    names: set[str] = set()
    for line in content.splitlines():
        m = GLOBAL_ASSIGN_RE.match(line)
        if m:
            names.add(m.group(1))
    return names


def parse_globalfuncs_txt(content: str) -> set[str]:
    names: set[str] = set()
    for line in content.splitlines():
        m = GLOBALFUNC_ASSIGN_RE.match(line)
        if m:
            names.add(m.group(1))
            continue
        m = FUNC_COMMENT_RE.search(line)
        if m:
            names.add(m.group(1))
    return names


def is_valid_lua_function_path(name: str) -> bool:
    if not name or name[0].isdigit():
        return False
    if re.search(r"[^A-Za-z0-9_.:]", name):
        return False
    return True


def emit_globals(names: set[str], reserved: set[str], wiki_map: dict[str, str]) -> list[str]:
    lines: list[str] = []
    for name in sorted(names - reserved):
        see = wiki_see_line(name, wiki_map)
        if see:
            lines.append(see)
        lines.append(f"---@type any")
        lines.append(f"{name} = nil")
        lines.append("")
    return lines


def extract_method_roots(func_paths: set[str]) -> set[str]:
    """Roots used as `Root.method` or `Root:method` in globalfuncs; LuaLS needs Root declared."""
    roots: set[str] = set()
    for path in func_paths:
        if "." in path:
            root, _, _ = path.partition(".")
        elif ":" in path:
            root, _, _ = path.partition(":")
        else:
            continue
        if not root or root[0].isdigit():
            continue
        if not (root[0].isalpha() or root[0] == "_"):
            continue
        roots.add(root)
    return roots


def emit_method_table_shells(
    roots: set[str],
    globals_emitted: set[str],
    reserved: set[str],
    wiki_map: dict[str, str],
) -> list[str]:
    need = sorted(roots - reserved - globals_emitted - LUA51_GLOBAL_ROOT_SKIP)
    lines: list[str] = []
    if need:
        lines.append("-- Method namespaces (synthetic tables for LuaLS; missing from globals.txt)")
        lines.append("")
    for root in need:
        see = wiki_see_line(root, wiki_map)
        if see:
            lines.append(see)
        lines.append(f"---@class {root}")
        lines.append(f"{root} = {root} or {{}}")
        lines.append("")
    return lines


def expand_func_stubs_for_luals(funcs_emit: set[str]) -> list[tuple[str, str | None]]:
    """
    Build a sorted list of (lua_path, receiver_or_none).

    UESP often lists ``Root:Method`` and ``Root.Method``. Colon entries become
    ``Root.Method`` with receiver ``Root`` (emit ``self`` first). Dot-only entries
    are skipped when a colon-derived stub exists for the same path. Unrecognized
    colon shapes are emitted unchanged (receiver None, original name).
    """
    colon_by_dot: dict[str, str] = {}
    passthrough: list[str] = []

    for name in funcs_emit:
        if ":" not in name:
            passthrough.append(name)
            continue
        recv, _, meth = name.partition(":")
        if not recv or not meth:
            passthrough.append(name)
            continue
        if "." in meth:
            # e.g. odd paths; keep original
            passthrough.append(name)
            continue
        dot_path = f"{recv}.{meth}"
        if not is_valid_lua_function_path(dot_path):
            passthrough.append(name)
            continue
        colon_by_dot[dot_path] = recv

    merged_dots = set(colon_by_dot.keys())
    out: list[tuple[str, str | None]] = []

    for name in sorted(passthrough):
        if not is_valid_lua_function_path(name):
            continue
        if name in merged_dots:
            continue
        out.append((name, None))

    for dot_path in sorted(merged_dots):
        out.append((dot_path, colon_by_dot[dot_path]))

    out.sort(key=lambda x: x[0])
    return out


def emit_functions(names: set[str], reserved: set[str], wiki_map: dict[str, str]) -> list[str]:
    lines: list[str] = []
    expanded = expand_func_stubs_for_luals(names - reserved)
    for name, receiver in expanded:
        see = wiki_see_line(name, wiki_map)
        if see:
            lines.append(see)
        if receiver is not None:
            lines.append(f"---@param self {receiver}")
            lines.append(f"function {name}(self, ...) end")
        else:
            lines.append(f"function {name}(...) end")
        lines.append("")
    return lines


def build_generated_block(
    version: int,
    urls: tuple[str, str],
    globals_names: set[str],
    func_names: set[str],
    reserved: set[str],
    wiki_map: dict[str, str],
) -> str:
    # Names that appear as functions in UESP are emitted as `function X(...) end` only,
    # not also as `X = nil` (avoids duplicate definitions for the same identifier).
    globals_emit_set = globals_names - reserved - func_names
    funcs_emit = func_names - reserved
    method_roots = extract_method_roots(funcs_emit)
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    banner = f"""--[[
  UESP ESO Data machine stubs
  UESP API version: {version}
  Generated at (UTC): {now}
  Sources:
    {urls[0]}
    {urls[1]}
  Your add-on ## APIVersion in manifest.txt may be newer than this dump; see .cursor/rules/ESO-LuaAPI-RULE.md.
]]"""

    parts: list[str] = [
        "",
        BEGIN_MARKER,
        banner,
        "",
        "-- Global values/constants/objects (from globals.txt)",
        "",
    ]
    parts.extend(emit_globals(globals_emit_set, set(), wiki_map))
    parts.extend(
        emit_method_table_shells(method_roots, globals_emit_set, reserved, wiki_map)
    )
    parts.append("-- Global functions / methods (from globalfuncs.txt)")
    parts.append("")
    parts.extend(emit_functions(funcs_emit, set(), wiki_map))
    return "\n".join(parts).rstrip() + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--pin-version",
        type=int,
        metavar="N",
        help=f"Use UESP API folder N instead of latest from {INDEX_URL}",
    )
    args = ap.parse_args()

    try:
        index_html = fetch_text(INDEX_URL)
        if args.pin_version is not None:
            version = args.pin_version
            print(f"Using pinned UESP API version: {version}", file=sys.stderr)
        else:
            version = discover_latest_version(index_html)
            print(f"Latest UESP API version from index: {version}", file=sys.stderr)

        try:
            cur_html = fetch_text(CURRENT_URL)
            cur_v = current_page_version(cur_html)
            if cur_v is not None and cur_v != version:
                print(
                    f"Warning: /current/index.html reports v{cur_v}, index max link was v{version}.",
                    file=sys.stderr,
                )
            elif cur_v is not None:
                print(f"Cross-check: /current/index.html matches v{cur_v}.", file=sys.stderr)
        except urllib.error.URLError as e:
            print(f"Warning: could not fetch /current for cross-check: {e}", file=sys.stderr)

        g_url = f"{UESP_HOST}/{version}/globals.txt"
        f_url = f"{UESP_HOST}/{version}/globalfuncs.txt"
        print(f"Fetching {g_url}", file=sys.stderr)
        globals_body = fetch_text(g_url)
        print(f"Fetching {f_url}", file=sys.stderr)
        funcs_body = fetch_text(f_url)

        globals_set = parse_globals_txt(globals_body)
        funcs_set = parse_globalfuncs_txt(funcs_body)

        manual, _ = split_existing_stub(STUB_PATH)
        reserved = extract_manual_reserved(manual)
        wiki_map = load_wiki_map()

        generated = build_generated_block(
            version,
            (g_url, f_url),
            globals_set,
            funcs_set,
            reserved,
            wiki_map,
        )

        out = manual.rstrip() + "\n\n" + generated

        STUB_PATH.parent.mkdir(parents=True, exist_ok=True)
        STUB_PATH.write_text(out, encoding="utf-8")

        print(f"Wrote {STUB_PATH}", file=sys.stderr)
        print(
            f"Done: UESP v{version}, {len(globals_set)} globals, {len(funcs_set)} function stubs "
            f"(after skipping {len(reserved)} manual symbols).",
            file=sys.stderr,
        )
        return 0

    except (urllib.error.URLError, RuntimeError, OSError) as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
