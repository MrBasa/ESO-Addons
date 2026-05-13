#!/usr/bin/env python3
"""
Offline ESO add-on health audit: scan live AddOns + SavedVariables on disk.

Reads manifests only (no game client). Emits a single Markdown report with:
  - Missing required dependencies; missing optional Lib* dependencies only
  - Orphaned Lib* roots (not referenced in any manifest dep line)
  - Orphaned SavedVariables .lua files (heuristic)
  - Stray artifacts (zips, non-manifest dirs)
  - Embedded Lib* under top-level non-Lib add-ons

Environment:
  ESO_ADDONS     — AddOns directory (overrides default Steam Proton path)

Caveats (see --help):
  - Optional Lib* deps missing are informational, not errors (non-Lib optional tokens are not listed in section 2).
  - Orphan Lib* / orphan SavedVars are heuristics — verify before deleting files.
  - SavedVariables file names usually match add-on folder names; mismatches can false-positive.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

# Same default tree as scripts/deploy_steam_eso_addons.sh (AddOns only).
_DEFAULT_ADDONS = (
    Path.home()
    / ".steam/steam/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/AddOns"
)

_MANIFEST_HEADER = re.compile(r"^##\s*([^:]+?)\s*:\s*(.*)$")
_TOKEN_STRIP = re.compile(r"^([^>=\(]+)")
_SKIP_TOPLEVEL_NAMES = frozenset(
    {
        ".shared",
        ".cursor",
        ".vscode",
        "docs",
        "scripts",
        "__MACOSX",
    }
)


def is_lib_dependency_name(name: str) -> bool:
    """ESO community libraries almost always use a `Lib` prefix; align report section 2 with that."""
    return name.startswith("Lib")


def strip_dep_token(raw: str) -> str | None:
    raw = raw.strip()
    if not raw:
        return None
    m = _TOKEN_STRIP.match(raw)
    return (m.group(1) if m else raw).strip() or None


def split_dep_line(line: str) -> list[str]:
    out: list[str] = []
    for tok in line.split():
        s = strip_dep_token(tok)
        if s:
            out.append(s)
    return out


def find_manifest_file(root: Path) -> Path | None:
    name = root.name
    for ext in (".txt", ".addon"):
        p = root / f"{name}{ext}"
        if p.is_file():
            try:
                txt = p.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            if "##" in txt:
                return p
    return None


def discover_addon_roots(addons_dir: Path) -> list[Path]:
    """Every directory under addons_dir that has a sibling manifest AddonName.txt/.addon (recursive)."""
    roots: list[Path] = []
    if not addons_dir.is_dir():
        return roots
    for dirpath, dirnames, _filenames in os.walk(addons_dir, followlinks=False):
        p = Path(dirpath)
        # prune obvious junk
        dirnames[:] = [
            d
            for d in dirnames
            if not d.startswith(".")
            and d not in ("__MACOSX",)
            and ".tmp.drivedownload" not in d.lower()
        ]
        mf = find_manifest_file(p)
        if mf is not None:
            roots.append(p)
    # de-duplicate (walk may not double-visit same path)
    uniq = sorted(set(roots), key=lambda x: str(x).lower())
    return uniq


@dataclass
class ManifestData:
    required_parts: list[str] = field(default_factory=list)
    optional_parts: list[str] = field(default_factory=list)
    pc_parts: list[str] = field(default_factory=list)
    saved_var_tokens: list[str] = field(default_factory=list)
    manifest_path: str = ""
    parse_warnings: list[str] = field(default_factory=list)


def parse_manifest(manifest_path: Path) -> ManifestData:
    out = ManifestData(manifest_path=str(manifest_path))
    try:
        lines = manifest_path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError as e:
        out.parse_warnings.append(f"read error: {e}")
        return out
    for line in lines:
        m = _MANIFEST_HEADER.match(line)
        if not m:
            continue
        key, val = m.group(1), m.group(2).strip()
        kl = key.lower()
        if kl == "dependson":
            out.required_parts.append(val)
        elif kl == "optionaldependson":
            out.optional_parts.append(val)
        elif kl == "pcdependson":
            out.pc_parts.append(val)
        elif kl == "savedvariables":
            for tok in val.replace(",", " ").split():
                t = tok.strip()
                if t:
                    out.saved_var_tokens.append(t)
    return out


def merged_tokens(parts: list[str]) -> list[str]:
    toks: list[str] = []
    for part in parts:
        toks.extend(split_dep_line(part))
    return toks


def parse_addon_settings_disabled(path: Path) -> set[str]:
    """Names explicitly set to 0 in #Default section (best-effort)."""
    disabled: set[str] = set()
    if not path.is_file():
        return disabled
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return disabled
    in_default = False
    for raw in text.splitlines():
        s = raw.strip()
        if not s:
            continue
        if s.startswith("#"):
            low = s.lower()
            if low in ("#default", "# default"):
                in_default = True
            else:
                in_default = False
            continue
        if not in_default:
            continue
        m = re.match(r"^(\S+)\s+([01])\s*$", s)
        if m and m.group(2) == "0":
            disabled.add(m.group(1))
    return disabled


def collect_findings(
    addons_dir: Path,
    savedvars_dir: Path | None,
    settings_path: Path | None,
) -> dict:
    roots = discover_addon_roots(addons_dir)
    root_paths = {p.resolve() for p in roots}
    root_name_to_path: dict[str, Path] = {}
    for p in roots:
        name = p.name
        if name not in root_name_to_path:
            root_name_to_path[name] = p

    all_names = set(root_name_to_path.keys())

    disabled: set[str] = set()
    if settings_path and settings_path.is_file():
        disabled = parse_addon_settings_disabled(settings_path)

    global_any_refs: set[str] = set()
    parse_notes: list[str] = []
    all_rows: list[dict] = []

    for p in sorted(roots, key=lambda x: str(x.relative_to(addons_dir)).lower()):
        name = p.name
        mf = find_manifest_file(p)
        if mf is None:
            continue
        data = parse_manifest(mf)
        if data.parse_warnings:
            parse_notes.extend([f"`{p}`: {w}" for w in data.parse_warnings])
        req = merged_tokens(data.required_parts + data.pc_parts)
        opt = merged_tokens(data.optional_parts)
        for t in req + opt:
            global_any_refs.add(t)
        man_rel = str(mf.resolve().relative_to(addons_dir.resolve()))
        all_rows.append(
            {
                "name": name,
                "path": p,
                "rel": str(p.resolve().relative_to(addons_dir.resolve())),
                "required": req,
                "optional": opt,
                "manifest": man_rel,
                "saved_var_tokens": list(data.saved_var_tokens),
            }
        )

    addon_rows = [r for r in all_rows if r["name"] not in disabled]

    missing_required: list[tuple[str, str, str]] = []
    missing_optional: list[tuple[str, str, str]] = []

    for row in addon_rows:
        for tok in row["required"]:
            if tok not in all_names:
                missing_required.append((row["name"], tok, row["manifest"]))
        for tok in row["optional"]:
            if not is_lib_dependency_name(tok):
                continue
            if tok not in all_names:
                missing_optional.append((row["name"], tok, row["manifest"]))

    orphan_libs: list[str] = []
    for name in sorted(all_names):
        if not name.startswith("Lib"):
            continue
        if name not in global_any_refs:
            orphan_libs.append(name)

    sv_declared_tables: set[str] = set()
    for row in all_rows:
        for t in row["saved_var_tokens"]:
            sv_declared_tables.add(t)

    intended_sv = addons_dir.parent / "SavedVariables"
    if savedvars_dir is not None:
        resolved_sv = savedvars_dir.expanduser().resolve()
        scanned_sv = resolved_sv if resolved_sv.is_dir() else None
        savedvars_intended = resolved_sv
    else:
        savedvars_intended = intended_sv.resolve()
        scanned_sv = intended_sv if intended_sv.is_dir() else None

    orphan_savedvars: list[str] = []
    if scanned_sv is not None:
        for f in sorted(scanned_sv.glob("*.lua")):
            stem = f.stem
            if stem in all_names:
                continue
            # Refinement: some add-ons use a SavedVariables file basename that matches a
            # declared table name but not the folder; keep if stem matches any declared table.
            if stem in sv_declared_tables:
                continue
            orphan_savedvars.append(str(f.resolve()))

    # Artifacts: top-level + lightweight tree heuristics
    artifacts: set[str] = set()
    if addons_dir.is_dir():
        for entry in sorted(addons_dir.iterdir()):
            if entry.name.startswith("."):
                continue
            if entry.name in _SKIP_TOPLEVEL_NAMES:
                continue
            if entry.is_file() and entry.suffix.lower() == ".zip":
                artifacts.add(f"Zip at top level: `{entry.name}`")
                continue
            if entry.is_dir():
                if entry.resolve() in root_paths:
                    continue
                if find_manifest_file(entry) is None:
                    artifacts.add(f"Directory without add-on manifest: `{entry.name}/`")

        junk_files = frozenset({".ds_store", "thumbs.db"})
        for dirpath, dirnames, filenames in os.walk(addons_dir, followlinks=False):
            dp = Path(dirpath)
            rel = dp.resolve().relative_to(addons_dir.resolve()).as_posix()
            if "__MACOSX" in dirnames:
                artifacts.add(f"Junk directory: `{rel}/__MACOSX/`" if rel != "." else "Junk directory: `__MACOSX/`")
                dirnames.remove("__MACOSX")
            for fn in filenames:
                if fn.lower() in junk_files:
                    prefix = f"`{rel}/{fn}`" if rel != "." else f"`{fn}`"
                    artifacts.add(f"Junk file: {prefix}")

    # Embedded nested Lib* (immediate child of top-level non-Lib folder)
    embedded: list[dict] = []
    if addons_dir.is_dir():
        standalone_libs = {n for n in all_names if n.startswith("Lib")}
        for child in sorted(addons_dir.iterdir()):
            if not child.is_dir() or child.name.startswith("."):
                continue
            if child.name.startswith("Lib"):
                continue
            try:
                subs = list(child.iterdir())
            except OSError:
                continue
            for sub in subs:
                if not sub.is_dir() or not sub.name.startswith("Lib"):
                    continue
                rel = sub.resolve().relative_to(addons_dir.resolve()).as_posix()
                has_nested_manifest = find_manifest_file(sub) is not None
                dup = sub.name in standalone_libs
                embedded.append(
                    {
                        "path": rel,
                        "lib_name": sub.name,
                        "nested_addon_root": has_nested_manifest,
                        "standalone_duplicate": dup,
                    }
                )

    return {
        "addons_dir": addons_dir.resolve(),
        "savedvars_dir": scanned_sv.resolve() if scanned_sv is not None else None,
        "savedvars_intended": savedvars_intended,
        "settings_path": settings_path.resolve() if settings_path and settings_path.is_file() else None,
        "disabled_count": len(disabled),
        "root_count": len(roots),
        "scanned_addon_count": len(addon_rows),
        "missing_required": missing_required,
        "missing_optional": missing_optional,
        "orphan_libs": orphan_libs,
        "orphan_savedvars": orphan_savedvars,
        "artifacts": sorted(artifacts),
        "embedded": embedded,
        "parse_notes": parse_notes,
        "sv_table_names_sample": sorted(sv_declared_tables)[:30],
    }


def render_markdown(data: dict) -> str:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    lines: list[str] = [
        "# ESO add-on health audit",
        "",
        f"_Generated: {now}_",
        "",
        "## Scan paths",
        "",
        f"- **AddOns:** `{data['addons_dir']}`",
    ]
    if data["savedvars_dir"]:
        lines.append(f"- **SavedVariables:** `{data['savedvars_dir']}`")
    else:
        lines.append(
            f"- **SavedVariables:** _(directory not found or not readable — expected `{data.get('savedvars_intended')}`)_"
        )
    if data["settings_path"]:
        lines.append(f"- **AddOnSettings (disable filter):** `{data['settings_path']}`")
    lines.extend(
        [
            "",
            f"- **Add-on roots discovered:** {data['root_count']}",
            f"- **Add-ons scanned (after disable filter):** {data['scanned_addon_count']}",
            f"- **Names disabled in #Default (if settings file used):** {data['disabled_count']}",
            "",
            "## 1. Missing required dependencies",
            "",
            "Required = merged `## DependsOn` + `## PCDependsOn` tokens; each must match an existing add-on root folder name under AddOns.",
            "",
        ]
    )
    if not data["missing_required"]:
        lines.append("- _(none)_")
    else:
        for addon, tok, man in sorted(data["missing_required"], key=lambda x: (x[1], x[0])):
            lines.append(f"- **`{tok}`** missing — required by **`{addon}`** (manifest `{man}`)")
    lines.extend(
        [
            "",
            "## 2. Missing optional `Lib*` dependencies",
            "",
            "Only tokens from `## OptionalDependsOn` whose names start with **`Lib`** (expected add-on folder names). "
            "Other optional tokens (UI skins, data modules, non-library add-ons) are omitted here by design.",
            "",
            "_Informational only — missing optional libraries are normal if you do not use that integration._",
            "",
        ]
    )
    if not data["missing_optional"]:
        lines.append("- _(none)_")
    else:
        for addon, tok, man in sorted(data["missing_optional"], key=lambda x: (x[1], x[0])):
            lines.append(f"- **`{tok}`** not installed — optional for **`{addon}`** (manifest `{man}`)")
    lines.extend(
        [
            "",
            "## 3. Orphaned / unused `Lib*` roots",
            "",
            "_Lib folder names starting with `Lib` that never appear in any installed manifest `DependsOn`, `OptionalDependsOn`, or `PCDependsOn` line (all add-ons on disk; not filtered by AddOnSettings)._ Not proof-safe to delete.",
            "",
        ]
    )
    if not data["orphan_libs"]:
        lines.append("- _(none)_")
    else:
        for name in data["orphan_libs"]:
            lines.append(f"- `{name}/`")
    lines.extend(
        [
            "",
            "## 4. Orphaned SavedVariables (heuristic)",
            "",
            "`.lua` files in SavedVariables whose basename is not an add-on root folder name on disk. "
        "Files whose basename matches a `## SavedVariables:` table token from any manifest are skipped (reduces some false positives). "
        "**False positives** are still possible (renamed add-ons, nonstandard file names). Cross-check manifests before deleting.",
            "",
        ]
    )
    if not data["orphan_savedvars"]:
        lines.append("- _(none)_")
    else:
        for p in data["orphan_savedvars"]:
            lines.append(f"- `{p}`")
    lines.extend(
        [
            "",
            "## 5. Other artifacts (AddOns tree)",
            "",
            "Top-level zip files and directories without a valid add-on manifest; plus `.DS_Store`, `Thumbs.db`, and `__MACOSX` under the tree.",
            "",
        ]
    )
    if not data["artifacts"]:
        lines.append("- _(none)_")
    else:
        for a in data["artifacts"]:
            lines.append(f"- {a}")
    lines.extend(
        [
            "",
            "## 6. Embedded nested `Lib*` (under top-level non-Lib add-ons)",
            "",
            "Immediate subfolders named `Lib*` under a top-level add-on whose name does **not** start with `Lib`. `nested_addon_root` means a manifest exists at `LibX/LibX.txt` (or `.addon`). `standalone_duplicate` means an add-on root with the same folder name exists at top level (or elsewhere) under AddOns.",
            "",
        ]
    )
    if not data["embedded"]:
        lines.append("- _(none found)_")
    else:
        for e in sorted(data["embedded"], key=lambda x: x["path"].lower()):
            flags = []
            if e["nested_addon_root"]:
                flags.append("nested add-on root")
            else:
                flags.append("files-only embed")
            if e["standalone_duplicate"]:
                flags.append("**standalone `Lib*` with same name exists**")
            lines.append(f"- `{e['path']}` — {', '.join(flags)}")
    lines.extend(["", "## Additional findings", ""])
    if data["parse_notes"]:
        lines.append("### Manifest parse warnings")
        lines.extend(f"- {n}" for n in data["parse_notes"])
        lines.append("")
    if data.get("sv_table_names_sample"):
        lines.append("### Sample of `## SavedVariables:` table names (first 30)")
        lines.extend(f"- `{t}`" for t in data["sv_table_names_sample"])
        lines.append("")
    if not data["parse_notes"] and not data.get("sv_table_names_sample"):
        lines.append("- _(none)_")
    lines.append("")
    return "\n".join(lines)


def default_savedvars(addons_dir: Path) -> Path | None:
    """.../live/AddOns -> .../live/SavedVariables"""
    try:
        live = addons_dir.resolve().parent
        sv = live / "SavedVariables"
        return sv if sv.is_dir() else None
    except (OSError, ValueError):
        return None


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Offline ESO add-on health audit (manifest + filesystem).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument(
        "--addons-dir",
        default=os.environ.get("ESO_ADDONS", "").strip() or str(_DEFAULT_ADDONS),
        type=Path,
        help="Path to live/AddOns (default: $ESO_ADDONS or Steam Proton default)",
    )
    ap.add_argument(
        "--savedvars-dir",
        default=None,
        type=str,
        metavar="PATH",
        help="Path to live/SavedVariables (default: sibling .../live/SavedVariables next to AddOns)",
    )
    ap.add_argument(
        "--add-on-settings",
        default=None,
        type=str,
        metavar="PATH",
        help="Optional live/AddOnSettings.txt — add-ons set to 0 under #Default are skipped for dependency sections 1-2 only",
    )
    ap.add_argument(
        "-o",
        "--output",
        default="-",
        help="Markdown report file, or '-' for stdout (default: -)",
    )
    ap.add_argument(
        "--exit-zero",
        action="store_true",
        help="Always exit 0 (ignore missing required deps for CI / scripting)",
    )
    args = ap.parse_args()

    addons_dir = args.addons_dir.expanduser().resolve()
    if args.savedvars_dir:
        savedvars_dir = Path(args.savedvars_dir).expanduser().resolve()
    else:
        d = default_savedvars(addons_dir)
        savedvars_dir = d if d is not None else None

    if args.add_on_settings:
        settings_path = Path(args.add_on_settings).expanduser().resolve()
    else:
        settings_path = None

    if not addons_dir.is_dir():
        print(f"error: AddOns directory not found: {addons_dir}", file=sys.stderr)
        return 2

    data = collect_findings(addons_dir, savedvars_dir, settings_path)
    md = render_markdown(data)

    out = args.output
    if str(out) == "-":
        sys.stdout.write(md)
        if not md.endswith("\n"):
            sys.stdout.write("\n")
    else:
        outp = Path(out).expanduser().resolve()
        outp.parent.mkdir(parents=True, exist_ok=True)
        outp.write_text(md, encoding="utf-8")

    return 0 if args.exit_zero else (1 if data["missing_required"] else 0)


if __name__ == "__main__":
    raise SystemExit(main())
