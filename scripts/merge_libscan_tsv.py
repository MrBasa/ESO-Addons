#!/usr/bin/env python3
"""
Merge LibScanner TSV (LibScannerSavedVars.lastExport) into data/addon_catalog.csv.

Paste the TSV into data/libscan_export.tsv or pass --tsv path.
Columns: folder, title, out_of_date, version, missing_deps

Example: after /libscanexport in-game, copy lastExport from
live/SavedVariables/LibScanner.lua into data/libscan_export.tsv, then run this.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def extract_tsv_from_savedvars(lua_text: str) -> str:
    """Best-effort: find lastExport = [[...]] or multiline string in SavedVariables Lua."""
    m = re.search(
        r'\["lastExport"\]\s*=\s*"(.*?)"\s*,',
        lua_text,
        re.DOTALL,
    )
    if m:
        raw = m.group(1)
        return bytes(raw, "utf-8").decode("unicode_escape")
    m2 = re.search(r"\[\'lastExport\'\]\s*=\s*\"(.*?)\"\s*,", lua_text, re.DOTALL)
    if m2:
        raw = m2.group(1)
        return bytes(raw, "utf-8").decode("unicode_escape")
    return ""


def main() -> int:
    ap = argparse.ArgumentParser(description="Merge LibScanner export TSV into addon_catalog.csv")
    ap.add_argument("--catalog", default=str(repo_root() / "data" / "addon_catalog.csv"))
    ap.add_argument(
        "--tsv",
        default="",
        help="Path to libscan_export.tsv; if omitted, try --savedvars or data/libscan_export.tsv",
    )
    ap.add_argument(
        "--savedvars",
        default="",
        help="Path to live/SavedVariables/LibScanner.lua",
    )
    args = ap.parse_args()

    catalog_path = Path(args.catalog).expanduser().resolve()
    tsv_path = Path(args.tsv).expanduser().resolve() if args.tsv else repo_root() / "data" / "libscan_export.tsv"
    sv_path = Path(args.savedvars).expanduser().resolve() if args.savedvars else None

    text = ""
    if sv_path and sv_path.is_file():
        text = extract_tsv_from_savedvars(sv_path.read_text(encoding="utf-8", errors="replace"))
    elif tsv_path.is_file():
        text = tsv_path.read_text(encoding="utf-8", errors="replace")
    else:
        print("No TSV source found. Create data/libscan_export.tsv or pass --tsv / --savedvars", file=sys.stderr)
        return 1

    rows_tsv = {}
    for line in text.strip().splitlines():
        parts = line.split("\t")
        if len(parts) < 3 or parts[0] == "folder":
            continue
        folder, _title, ood = parts[0], parts[1], parts[2]
        missing = parts[4] if len(parts) > 4 else ""
        rows_tsv[folder] = {"out_of_date": ood, "missing_deps": missing}

    with catalog_path.open(encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames or []
        out = []
        for row in reader:
            hit = rows_tsv.get(row.get("folder", ""))
            if hit:
                row["out_of_date"] = hit["out_of_date"]
                row["missing_deps"] = hit["missing_deps"]
            out.append(row)

    with catalog_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        w.writerows(out)

    print(f"Merged LibScanner data for {len(rows_tsv)} folders into {catalog_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
