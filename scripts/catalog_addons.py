#!/usr/bin/env python3
"""
Walk ESO live/AddOns: parse each add-on manifest (## headers), merge enabled state
from live/AddOnSettings.txt, write data/addon_catalog.csv.

Env:
  ESO_ADDONS_DIR — default: Steam Proton path used in deploy_steam_eso_addons.sh
  ESO_LIVE_DIR   — parent of AddOns; default: dirname(ESO_ADDONS_DIR)
  CATALOG_OUT    — default: repo data/addon_catalog.csv
  EMBEDDED_OUT   — optional second CSV for nested Lib* under non-Lib top-level folders

AddOnSettings.txt (high level):
  - #Version / #AddOnsEnabled / other #Known* lines at top
  - Character sections: lines starting with "#" that are not known globals (e.g. #NA-Megaserver-Name)
  - Under a section, lines like: AddonFolderName<TAB>0|1 or AddonFolderName 0|1
If there are no character sections and #AddOnsEnabled is 1, every on-disk folder is treated enabled.
If an add-on never appears under a character section, it inherits global (#AddOnsEnabled): enabled when 1.
If it appears with 0 in at least one section and never with 1, it is disabled.
Mixed 0/1 across characters -> enabled_partial.
"""

from __future__ import annotations

import argparse
import csv
import os
import re
import sys
from pathlib import Path

RE_MANIFEST_LINE = re.compile(r"^##\s*([^:]+):\s*(.*)\s*$")

KNOWN_GLOBAL_HEADERS = frozenset(
    {
        "version",
        "addonenabled",
        "addonsenabled",
        "savedversion",
        "apiversion",
    }
)

SKIP_TOPLEVEL_DIRS = frozenset({".tmp.drivedownload"})

DEFAULT_ADDONS = Path.home() / (
    ".steam/steam/steamapps/compatdata/306130/pfx/drive_c/users/"
    "steamuser/Documents/Elder Scrolls Online/live/AddOns"
)


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def looks_like_library(folder: str, manifest: dict[str, str]) -> bool:
    il = (manifest.get("IsLibrary") or "").strip().lower()
    if il in ("1", "true", "yes"):
        return True
    if folder.lower().startswith("lib"):
        return True
    return False


def find_manifest(addon_dir: Path) -> Path | None:
    name = addon_dir.name
    primary = addon_dir / f"{name}.txt"
    if primary.is_file():
        return primary
    alt = addon_dir / "manifest.txt"
    if alt.is_file():
        return alt
    for p in sorted(addon_dir.glob("*.txt")):
        try:
            head = p.read_text(encoding="utf-8", errors="replace")[:2048]
        except OSError:
            continue
        if "## Title:" in head or "##Title:" in head:
            return p
    return None


def parse_manifest(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return out
    for line in text.splitlines():
        m = RE_MANIFEST_LINE.match(line.strip())
        if not m:
            continue
        key = m.group(1).strip()
        val = m.group(2).strip()
        out[key] = val
    return out


def normalize_api_version(v: str) -> str:
    return re.sub(r"\s+", " ", (v or "").strip())


def parse_addon_settings(path: Path | None) -> tuple[int | None, dict[str, set[int]]]:
    """
    Returns (global_addons_enabled_0_or_1_or_None, addon_name -> set of states {0,1} seen).
    """
    if path is None or not path.is_file():
        return None, {}

    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return None, {}

    global_on: int | None = None
    states: dict[str, set[int]] = {}
    in_char_section = False

    def feed_state(name: str, bit: int) -> None:
        name = name.strip()
        if not name or name.startswith("#"):
            return
        states.setdefault(name, set()).add(bit)

    for raw in lines:
        line = raw.strip()
        if not line:
            continue
        if line.startswith("#"):
            key = line[1:].strip()
            low = key.lower().replace(" ", "")
            if low.startswith("version"):
                parts = line.split(None, 1)
                if len(parts) >= 2 and parts[0].lower() == "#version":
                    continue
            if low.startswith("addonsenabled"):
                parts = line.split()
                if len(parts) >= 2:
                    try:
                        global_on = int(parts[-1])
                    except ValueError:
                        pass
                continue
            low_key = key.split()[0].lower() if key.split() else ""
            if low_key in KNOWN_GLOBAL_HEADERS or low.startswith("savedversion"):
                continue
            # Character (or account) section header
            in_char_section = True
            continue

        if in_char_section:
            # Try tab-separated
            if "\t" in line:
                parts = line.split("\t")
                if len(parts) >= 2 and parts[-1].strip() in ("0", "1"):
                    try:
                        feed_state(parts[0], int(parts[-1]))
                    except ValueError:
                        pass
                    continue
            # Space: last token 0/1, rest is name
            toks = line.split()
            if len(toks) >= 2 and toks[-1] in ("0", "1"):
                feed_state(" ".join(toks[:-1]), int(toks[-1]))
            elif len(toks) == 1 and toks[0]:
                # Unknown single token — ignore
                pass

    return global_on, states


def purpose_tags_for_folder(folder: str) -> str:
    """Lightweight taxonomy hints for audit tagging (expand over time)."""
    f = folder.lower()
    tags: list[str] = []
    if f.startswith("lib"):
        tags.append("library")
    if any(x in f for x in ("map", "harvest", "pin", "compass")):
        tags.append("maps_navigation")
    if any(x in f for x in ("merchant", "trade", "ttc", "guild", "price", "lootlog")):
        tags.append("economy_tracking")
    if any(x in f for x in ("craft", "writ", "alchemy", "recipe")):
        tags.append("crafting")
    if any(x in f for x in ("combat", "raid", "crutch", "alert", "bandit")):
        tags.append("combat_ui")
    if any(x in f for x in ("housing", "essentialhousing")):
        tags.append("housing")
    if any(x in f for x in ("achievement", "lore", "quest", "characterknowledge", "motif")):
        tags.append("collectibles_knowledge")
    if any(x in f for x in ("iifa", "inventory", "dustman", "filter", "bag")):
        tags.append("inventory")
    if any(x in f for x in ("chat", "pcat")):
        tags.append("chat")
    return " ".join(tags) if tags else "misc_or_unclassified"


def enabled_for_folder(folder: str, global_on: int | None, st: dict[str, set[int]]) -> str:
    if global_on == 0:
        return "no"
    if not st:
        return "yes" if global_on == 1 else "unknown"

    if folder not in st:
        return "yes" if global_on == 1 else "unknown"

    bits = st[folder]
    if bits == {1}:
        return "yes"
    if bits == {0}:
        return "no"
    return "partial"


def collect_embedded_libs(addons_root: Path, top_name: str) -> list[str]:
    """Nested Lib* directories one level under a non-Lib top-level add-on."""
    if top_name.lower().startswith("lib"):
        return []
    base = addons_root / top_name
    if not base.is_dir():
        return []
    found = []
    for child in base.iterdir():
        if child.is_dir() and child.name.lower().startswith("lib"):
            found.append(child.name)
    return sorted(found)


def append_repo_only_addons(repo: Path, addons_root: Path, rows: list[dict[str, str]], seen_folders: set[str]) -> None:
    """Add rows for repo add-on folders not yet deployed into live/AddOns (e.g. LootLogCustom)."""
    if not repo.is_dir():
        return
    for entry in sorted(repo.iterdir()):
        if not entry.is_dir() or entry.name.startswith("."):
            continue
        if entry.name in SKIP_TOPLEVEL_DIRS or entry.name in seen_folders:
            continue
        man = entry / f"{entry.name}.txt"
        if not man.is_file():
            man = entry / "manifest.txt"
        if not man.is_file():
            continue
        meta = parse_manifest(man)
        title = meta.get("Title", "")
        desc = meta.get("Description", "")
        deps = meta.get("DependsOn", "")
        is_lib = "yes" if looks_like_library(entry.name, meta) else "no"
        summary_stub = repo / "data" / "addon_summaries" / f"{entry.name}.txt"
        code_summary_path = ""
        try:
            code_summary_path = str(summary_stub.relative_to(repo))
        except ValueError:
            code_summary_path = f"data/addon_summaries/{entry.name}.txt"
        note_parts = [desc] if desc else []
        note_parts.append("[repo-only: not present under live/AddOns; deploy via scripts/deploy_steam_eso_addons.sh]")
        purpose = purpose_tags_for_folder(entry.name)
        rows.append(
            {
                "folder": entry.name,
                "title": title,
                "version": meta.get("Version", ""),
                "api_version": normalize_api_version(meta.get("APIVersion", "")),
                "is_library": is_lib,
                "depends_on": deps,
                "optional_depends_on": meta.get("OptionalDependsOn", ""),
                "description": desc,
                "manifest_path": str(man.relative_to(repo)),
                "esoui_url": "",
                "esoui_category": "",
                "code_summary_path": code_summary_path,
                "functionality_notes": " | ".join(note_parts),
                "enabled": "unknown",
                "enablement_steps": "",
                "out_of_date": "",
                "missing_deps": "",
                "purpose_tags": purpose,
                "vanilla_status": "unknown",
                "source": "repo_only",
            }
        )


def main() -> int:
    ap = argparse.ArgumentParser(description="Build ESO add-on catalog CSV from manifests + AddOnSettings.txt")
    ap.add_argument(
        "--addons",
        default=os.environ.get("ESO_ADDONS_DIR", str(DEFAULT_ADDONS)),
        help="Path to live/AddOns",
    )
    ap.add_argument(
        "--repo",
        default=str(repo_root()),
        help="Repo root: append catalog rows for add-ons that exist only here (have FolderName/FolderName.txt)",
    )
    ap.add_argument(
        "--live",
        default=os.environ.get("ESO_LIVE_DIR", ""),
        help="Path to live (parent of AddOns). Default: parent of --addons",
    )
    ap.add_argument(
        "--out",
        default=os.environ.get("CATALOG_OUT", str(repo_root() / "data" / "addon_catalog.csv")),
    )
    ap.add_argument(
        "--embedded-out",
        default=os.environ.get("EMBEDDED_OUT", str(repo_root() / "data" / "addon_embedded_libs.csv")),
    )
    args = ap.parse_args()

    addons_root = Path(args.addons).expanduser().resolve()
    live_dir = Path(args.live).expanduser().resolve() if args.live else addons_root.parent
    settings_path = live_dir / "AddOnSettings.txt"
    out_path = Path(args.out).expanduser().resolve()
    embedded_path = Path(args.embedded_out).expanduser().resolve()

    if not addons_root.is_dir():
        print(f"AddOns directory not found: {addons_root}", file=sys.stderr)
        return 1

    global_on, st = parse_addon_settings(settings_path)

    rows: list[dict[str, str]] = []
    embedded_rows: list[dict[str, str]] = []

    for entry in sorted(addons_root.iterdir(), key=lambda p: p.name.lower()):
        name = entry.name
        if name.startswith("."):
            continue
        if name in SKIP_TOPLEVEL_DIRS:
            continue
        if entry.is_file():
            if name.lower().endswith(".zip"):
                rows.append(
                    {
                        "folder": name,
                        "title": "",
                        "version": "",
                        "api_version": "",
                        "is_library": "",
                        "depends_on": "",
                        "optional_depends_on": "",
                        "description": "archive on disk; not a folder add-on",
                        "manifest_path": "",
                        "esoui_url": "",
                        "esoui_category": "",
                        "code_summary_path": "",
                        "functionality_notes": "",
                        "enabled": "",
                        "enablement_steps": "",
                        "out_of_date": "",
                        "missing_deps": "",
                        "purpose_tags": "archive_custom_fork_pending_deploy",
                        "vanilla_status": "unknown",
                        "source": "archive",
                    }
                )
            continue
        if not entry.is_dir():
            continue

        man = find_manifest(entry)
        manifest_path_rel = ""
        meta: dict[str, str] = {}
        if man:
            meta = parse_manifest(man)
            try:
                manifest_path_rel = str(man.relative_to(addons_root))
            except ValueError:
                manifest_path_rel = str(man)

        title = meta.get("Title", "")
        desc = meta.get("Description", "")
        deps = meta.get("DependsOn", "")

        is_lib = "yes" if looks_like_library(name, meta) else "no"
        en = enabled_for_folder(name, global_on, st)

        summary_stub = (repo_root() / "data" / "addon_summaries" / f"{name}.txt")
        code_summary_path = str(summary_stub.relative_to(repo_root())) if summary_stub else ""

        note_parts = []
        if desc:
            note_parts.append(desc)
        purpose = purpose_tags_for_folder(name)
        rows.append(
            {
                "folder": name,
                "title": title,
                "version": meta.get("Version", ""),
                "api_version": normalize_api_version(meta.get("APIVersion", "")),
                "is_library": is_lib,
                "depends_on": deps,
                "optional_depends_on": meta.get("OptionalDependsOn", ""),
                "description": desc,
                "manifest_path": manifest_path_rel,
                "esoui_url": "",
                "esoui_category": "",
                "code_summary_path": code_summary_path,
                "functionality_notes": " | ".join(note_parts) if note_parts else "",
                "enabled": en,
                "enablement_steps": "",
                "out_of_date": "",
                "missing_deps": "",
                "purpose_tags": purpose,
                "vanilla_status": "unknown",
                "source": "folder",
            }
        )

        for emb in collect_embedded_libs(addons_root, name):
            embedded_rows.append({"parent_folder": name, "embedded_lib_folder": emb})

    fieldnames = [
        "folder",
        "title",
        "version",
        "api_version",
        "is_library",
        "depends_on",
        "optional_depends_on",
        "description",
        "manifest_path",
        "esoui_url",
        "esoui_category",
        "code_summary_path",
        "functionality_notes",
        "enabled",
        "enablement_steps",
        "out_of_date",
        "missing_deps",
        "purpose_tags",
        "vanilla_status",
        "source",
    ]

    seen_folders = {r["folder"] for r in rows}
    append_repo_only_addons(Path(args.repo).expanduser().resolve(), addons_root, rows, seen_folders)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)

    embedded_path.parent.mkdir(parents=True, exist_ok=True)
    with embedded_path.open("w", encoding="utf-8", newline="") as f:
        ew = csv.DictWriter(f, fieldnames=["parent_folder", "embedded_lib_folder"])
        ew.writeheader()
        ew.writerows(embedded_rows)

    print(f"Wrote {len(rows)} rows -> {out_path}")
    print(f"Wrote {len(embedded_rows)} embedded lib rows -> {embedded_path}")
    print(f"AddOnSettings: {settings_path} global_on={global_on} tracked_addons={len(st)}")

    stub = out_path.parent / "esoui_stub.csv"
    with stub.open("w", encoding="utf-8", newline="") as f:
        sw = csv.DictWriter(f, fieldnames=["folder", "title", "esoui_url", "esoui_category"])
        sw.writeheader()
        for r in rows:
            if r.get("source") == "archive":
                continue
            sw.writerow(
                {
                    "folder": r["folder"],
                    "title": r.get("title", ""),
                    "esoui_url": "",
                    "esoui_category": "",
                }
            )
    print(f"Wrote ESOUI stub -> {stub}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
