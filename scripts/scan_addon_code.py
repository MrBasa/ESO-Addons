#!/usr/bin/env python3
"""
Static scan of ESO add-on Lua/XML under live/AddOns: slash commands, events,
LAM panels, SavedVars, hook hints. Writes data/addon_code_signals.csv and
data/addon_summaries/<Folder>.txt

Env:
  ESO_ADDONS_DIR — same default as catalog_addons.py
  SIGNALS_OUT    — default data/addon_code_signals.csv
  SUMMARY_DIR    — default data/addon_summaries
"""

from __future__ import annotations

import argparse
import csv
import os
import re
import sys
from pathlib import Path

SKIP_DIR_NAMES = frozenset({".git", ".tmp.drivedownload", "node_modules"})

# Skip asset-heavy folder names when walking (optional speedup)
PRUNE_DIR_NAMES = frozenset(
    {
        "dds",
        "textures",
        "history",
        "images",
        "icons",
        "media",
        "assets",
        "fonts",
        "pc",
    }
)

MAX_FILE_BYTES = 400_000

RE_SLASH_ASSIGN = re.compile(
    r'SLASH_COMMANDS\s*\[\s*["\']([^"\']+)["\']\s*\]',
    re.IGNORECASE,
)
RE_SLASH_BRACKET = re.compile(
    r'SLASH_COMMANDS\s*\[\s*\[([^\]]+)\]\s*\]',
    re.IGNORECASE,
)
RE_REGISTER_EVENT = re.compile(
    r'EVENT_MANAGER\s*:\s*RegisterForEvent\s*\(\s*[^,]+,\s*([A-Za-z0-9_]+)\s*,',
    re.IGNORECASE,
)
RE_REGISTER_EVENT_STR = re.compile(
    r'EVENT_MANAGER\s*:\s*RegisterForEvent\s*\(\s*[^,]+,\s*["\']([^"\']+)["\']\s*,',
    re.IGNORECASE,
)
RE_LAM_PANEL = re.compile(r'LAM\s*:\s*RegisterAddonPanel\s*\(', re.IGNORECASE)
RE_SAVEDVARS = re.compile(
    r'ZO_SavedVars\s*:\s*New\s*\(\s*[^,]+,\s*[^,]+,\s*[^,]+,\s*["\']([^"\']+)["\']',
    re.IGNORECASE,
)
RE_HOOK = re.compile(r'ZO_(?:PreHook|PostHook)\s*\(', re.IGNORECASE)
RE_CREATE_CONTROL = re.compile(r'CreateControlFromVirtual\s*\(', re.IGNORECASE)

DEFAULT_ADDONS = Path.home() / (
    ".steam/steam/steamapps/compatdata/306130/pfx/drive_c/users/"
    "steamuser/Documents/Elder Scrolls Online/live/AddOns"
)


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def iter_lua_xml(root: Path):
    for dirpath, dirnames, filenames in os.walk(root, topdown=True):
        dirnames[:] = [
            d
            for d in dirnames
            if d not in SKIP_DIR_NAMES and d.lower() not in PRUNE_DIR_NAMES
        ]
        dpath = Path(dirpath)
        for fn in filenames:
            p = dpath / fn
            low = fn.lower()
            if not (low.endswith(".lua") or low.endswith(".xml")):
                continue
            try:
                if p.stat().st_size > MAX_FILE_BYTES:
                    continue
            except OSError:
                continue
            yield p


def scan_file(path: Path) -> dict:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}
    slash = set(RE_SLASH_ASSIGN.findall(text))
    slash.update(RE_SLASH_BRACKET.findall(text))
    events = set(RE_REGISTER_EVENT.findall(text))
    events.update(RE_REGISTER_EVENT_STR.findall(text))
    saved = set(RE_SAVEDVARS.findall(text))
    return {
        "slash": slash,
        "events": events,
        "saved": saved,
        "lam": bool(RE_LAM_PANEL.search(text)),
        "hooks": bool(RE_HOOK.search(text)),
        "create_control": len(RE_CREATE_CONTROL.findall(text)),
    }


def cap_join(items: set[str], limit: int = 40) -> str:
    s = sorted(items)
    if len(s) <= limit:
        return " ".join(s)
    return " ".join(s[:limit]) + f" …(+{len(s) - limit})"


def scan_addon_folder(addon_dir: Path) -> dict:
    all_slash: set[str] = set()
    all_events: set[str] = set()
    all_saved: set[str] = set()
    lam = False
    hooks = False
    create_n = 0
    lua_n = 0
    xml_n = 0
    for p in iter_lua_xml(addon_dir):
        if p.suffix.lower() == ".lua":
            lua_n += 1
        else:
            xml_n += 1
        r = scan_file(p)
        all_slash |= r.get("slash", set())
        all_events |= r.get("events", set())
        all_saved |= r.get("saved", set())
        lam = lam or r.get("lam", False)
        hooks = hooks or r.get("hooks", False)
        create_n += r.get("create_control", 0)
    return {
        "slash_commands": cap_join(all_slash),
        "event_samples": cap_join(all_events),
        "saved_vars_names": cap_join(all_saved),
        "lam_panel": "yes" if lam else "no",
        "hook_flags": "yes" if hooks else "no",
        "create_control_count": str(create_n),
        "lua_file_count": str(lua_n),
        "xml_file_count": str(xml_n),
        "_slash_set": all_slash,
        "_event_set": all_events,
        "_saved_set": all_saved,
    }


def write_summary(path: Path, folder: str, data: dict) -> None:
    lines = [
        f"# {folder}",
        "",
        f"lam_panel: {data['lam_panel']}",
        f"hook_flags: {data['hook_flags']}",
        f"lua_files: {data['lua_file_count']} xml_files: {data['xml_file_count']}",
        f"create_control_calls: {data['create_control_count']}",
        "",
        "## Slash commands",
        data["slash_commands"] or "(none detected)",
        "",
        "## SavedVars names (heuristic)",
        data["saved_vars_names"] or "(none detected)",
        "",
        "## Event name samples (literals only, capped)",
        data["event_samples"] or "(none detected)",
        "",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def merge_into_catalog(catalog_path: Path, rows_signals: list[dict[str, str]]) -> None:
    """Append short code-scan hints to functionality_notes in addon_catalog.csv."""
    if not catalog_path.is_file():
        return
    by_folder = {r["folder"]: r for r in rows_signals}

    with catalog_path.open(encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames or []
        out_rows = []
        for row in reader:
            sig = by_folder.get(row.get("folder", ""))
            if sig:
                sc = sig.get("slash_commands") or ""
                slash_n = len([t for t in sc.replace(" …", " ").split() if t and not t.startswith("(+)")])
                ev = sig.get("event_samples", "")
                ev_n = len(ev.split()) if ev else 0
                hint = (
                    f"[code-scan] LAM={sig.get('lam_panel')} hooks={sig.get('hook_flags')}"
                    f" lua={sig.get('lua_file_count')} slash_tokens~{slash_n} event_tokens~{ev_n}"
                )
                fn = (row.get("functionality_notes") or "").strip()
                fn = re.sub(r"\s*\|\s*\[code-scan\].*$", "", fn, flags=re.DOTALL).strip()
                row["functionality_notes"] = f"{fn} | {hint}".strip(" |") if fn else hint
                row["code_summary_path"] = sig.get("summary_path", row.get("code_summary_path", ""))
            out_rows.append(row)
    with catalog_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        w.writerows(out_rows)
    print(f"Merged signals into {catalog_path}")


def scan_repo_only_addon_dirs(repo: Path, addons_root: Path, scanned: set[str]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    if not repo.is_dir():
        return rows
    sum_dir = repo / "data" / "addon_summaries"
    for entry in sorted(repo.iterdir()):
        if (
            not entry.is_dir()
            or entry.name.startswith(".")
            or entry.name in scanned
            or not (entry / f"{entry.name}.txt").is_file()
        ):
            continue
        if (addons_root / entry.name).is_dir():
            continue
        data = scan_addon_folder(entry)
        summary_rel = f"data/addon_summaries/{entry.name}.txt"
        write_summary(sum_dir / f"{entry.name}.txt", entry.name, data)
        rows.append(
            {
                "folder": entry.name,
                "slash_commands": data["slash_commands"],
                "saved_vars_names": data["saved_vars_names"],
                "lam_panel": data["lam_panel"],
                "event_samples": data["event_samples"],
                "hook_flags": data["hook_flags"],
                "create_control_count": data["create_control_count"],
                "lua_file_count": data["lua_file_count"],
                "xml_file_count": data["xml_file_count"],
                "summary_path": summary_rel,
            }
        )
    return rows


def main() -> int:
    ap = argparse.ArgumentParser(description="Scan ESO add-on Lua/XML for behavioral signals")
    ap.add_argument("--addons", default=os.environ.get("ESO_ADDONS_DIR", str(DEFAULT_ADDONS)))
    ap.add_argument("--repo", default=str(repo_root()), help="Scan repo-only add-on dirs missing from --addons")
    ap.add_argument(
        "--out",
        default=os.environ.get("SIGNALS_OUT", str(repo_root() / "data" / "addon_code_signals.csv")),
    )
    ap.add_argument(
        "--summaries",
        default=os.environ.get("SUMMARY_DIR", str(repo_root() / "data" / "addon_summaries")),
    )
    ap.add_argument(
        "--merge-catalog",
        default=str(repo_root() / "data" / "addon_catalog.csv"),
        help="Path to addon_catalog.csv to enrich with code-scan line; empty string to skip",
    )
    args = ap.parse_args()

    addons_root = Path(args.addons).expanduser().resolve()
    out_csv = Path(args.out).expanduser().resolve()
    sum_dir = Path(args.summaries).expanduser().resolve()

    if not addons_root.is_dir():
        print(f"AddOns not found: {addons_root}", file=sys.stderr)
        return 1

    rows: list[dict[str, str]] = []

    for entry in sorted(addons_root.iterdir(), key=lambda p: p.name.lower()):
        if entry.name.startswith("."):
            continue
        if not entry.is_dir():
            continue
        data = scan_addon_folder(entry)
        summary_rel = f"data/addon_summaries/{entry.name}.txt"
        write_summary(sum_dir / f"{entry.name}.txt", entry.name, data)
        rows.append(
            {
                "folder": entry.name,
                "slash_commands": data["slash_commands"],
                "saved_vars_names": data["saved_vars_names"],
                "lam_panel": data["lam_panel"],
                "event_samples": data["event_samples"],
                "hook_flags": data["hook_flags"],
                "create_control_count": data["create_control_count"],
                "lua_file_count": data["lua_file_count"],
                "xml_file_count": data["xml_file_count"],
                "summary_path": summary_rel,
            }
        )

    scanned_names = {r["folder"] for r in rows}
    repo_path = Path(args.repo).expanduser().resolve()
    rows.extend(scan_repo_only_addon_dirs(repo_path, addons_root, scanned_names))

    fieldnames = [
        "folder",
        "slash_commands",
        "saved_vars_names",
        "lam_panel",
        "event_samples",
        "hook_flags",
        "create_control_count",
        "lua_file_count",
        "xml_file_count",
        "summary_path",
    ]
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    with out_csv.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(rows)

    print(f"Wrote {len(rows)} addon signal rows -> {out_csv}")
    print(f"Summaries -> {sum_dir}")
    if args.merge_catalog.strip():
        merge_into_catalog(Path(args.merge_catalog).expanduser().resolve(), rows)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
