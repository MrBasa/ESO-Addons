#!/usr/bin/env python3
"""
Merge LibScanner TSV (LibScannerSavedVars.lastExport / lastExportChunks) into
data/addon_catalog.csv.

Paste the TSV into data/libscan_export.tsv or pass --tsv / --savedvars.
Columns: folder, title, out_of_date, version, missing_deps

Example:
  python3 scripts/merge_libscan_tsv.py \\
    --savedvars "$HOME/Games/ESO/live/SavedVariables/LibScanner.lua"
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def _unescape_lua_string(raw: str) -> str:
    return bytes(raw, "utf-8").decode("unicode_escape")


def extract_tsv_from_savedvars(lua_text: str) -> str:
    """Reassemble TSV from lastExportChunks (v2) or legacy lastExport string."""
    # Preferred: lastExportChunks = { [1] = "...", [2] = "...", }
    chunk_block = re.search(
        r'\["lastExportChunks"\]\s*=\s*\{(.*?)\n\s*\},',
        lua_text,
        re.DOTALL,
    )
    if chunk_block:
        parts = re.findall(
            r'\[\d+\]\s*=\s*"(.*?)"\s*,',
            chunk_block.group(1),
            re.DOTALL,
        )
        if parts:
            return "\n".join(_unescape_lua_string(p) for p in parts)

    # Legacy single string (often nil once >2000 chars)
    m = re.search(
        r'\["lastExport"\]\s*=\s*"(.*?)"\s*,',
        lua_text,
        re.DOTALL,
    )
    if m:
        raw = m.group(1)
        # Skip short status marker from chunked exporter
        if raw.startswith("chunks:"):
            return ""
        return _unescape_lua_string(raw)
    m2 = re.search(r"\['lastExport'\]\s*=\s*\"(.*?)\"\s*,", lua_text, re.DOTALL)
    if m2:
        raw = m2.group(1)
        if raw.startswith("chunks:"):
            return ""
        return _unescape_lua_string(raw)
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
    source = ""
    if sv_path and sv_path.is_file():
        text = extract_tsv_from_savedvars(sv_path.read_text(encoding="utf-8", errors="replace"))
        source = str(sv_path)
    if (not text.strip()) and tsv_path.is_file():
        candidate = tsv_path.read_text(encoding="utf-8", errors="replace")
        # Ignore empty / header-only stubs
        data_lines = [
            ln
            for ln in candidate.splitlines()
            if ln.strip() and not ln.startswith("folder\t")
        ]
        if data_lines:
            text = candidate
            source = str(tsv_path)
    if not text.strip() or not any(
        ln.strip() and not ln.startswith("folder\t") for ln in text.splitlines()
    ):
        print(
            "No usable TSV found.\n"
            "  Current SavedVariables likely hit ESO's 2000-char string limit "
            "(lastExport=nil). Redeploy LibScanner (chunked export), run "
            "/libscanexport + /reloadui, then re-run this script with --savedvars.",
            file=sys.stderr,
        )
        return 1

    # Always refresh data/libscan_export.tsv for inspection
    out_tsv = repo_root() / "data" / "libscan_export.tsv"
    out_tsv.write_text(text if text.endswith("\n") else text + "\n", encoding="utf-8")

    rows_tsv: dict[str, dict[str, str]] = {}
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

    print(f"Merged LibScanner data for {len(rows_tsv)} folders from {source} into {catalog_path}")
    print(f"Wrote TSV copy -> {out_tsv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
