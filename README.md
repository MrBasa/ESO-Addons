# ESO-Addons

A collection of add-ons for [The Elder Scrolls Online](https://www.elderscrollsonline.com/) (ESO), plus shared assets for local Lua editing.

## Add-ons

| Add-on | Description |
|--------|-------------|
| [LibScanner](LibScanner/) | Scans library dependencies and shows add-on version / dependency status in a UI window. |
| [LootLogCustom](LootLogCustom/) | Custom fork of Loot Log (ILikeMoneyEdition); distinct `SavedVariables` and load name `LootLogCustom`. |

Documentation pattern: every add-on listed above has a detailed subsection under [Add-on details](#add-on-details). When you add a new add-on to the repo, add a table row here and a new `###` section there using the same structure as LibScanner (purpose and usage; installation is covered once below).

## Installation

These steps are the same for every add-on folder in this repository (for example [`LibScanner`](LibScanner/) or any future add-on at the repo root):

1. Copy the **entire** add-on folder (the directory that contains that add-on's manifest, usually `AddonName.txt`) into your live client's **`AddOns`** directory — for example `Documents/Elder Scrolls Online/live/AddOns` on Windows, or the `live/AddOns` path your launcher uses on Linux/macOS.
2. Launch ESO and open **Settings → Add-Ons**.
3. Enable the add-on (and satisfy any **Required dependencies** the game lists for it).

Treat this like any other community add-on: one folder per add-on, names must match what the manifest expects, and libraries your add-on depends on must be installed separately.

## Add-on details

### LibScanner

**Purpose.** Surfaces dependency and version information from ESO's **Add-On Manager**: which **enabled, non-library** add-ons are up to date, which have **missing dependencies**, which **library** dependencies are missing **globally**, and which installed libraries appear **unused** (no enabled add-on lists them as a dependency).

**Usage.** After you install the folder with [Installation](#installation), type **`/libscan`** in chat. Each time you open the window this way, LibScanner re-runs its scan. **`/libscanexport`** runs the same scan and persists a TSV snapshot to **`LibScannerSavedVars.lastExport`** (SavedVariables file under `live/SavedVariables/`) for merging into the repo catalog via `scripts/merge_libscan_tsv.py`.

The UI has two tabs:

- **Versions** — Sortable list of enabled add-ons that are **not** libraries (titles are shown with ESO color codes stripped). Each row shows the add-on name, a **Yes/No** up-to-date indicator, the manifest `## Version` string, and—when the API reports gaps—a **Missing:** line listing dependencies that are not present.
- **Libraries** — Text panel with two lists: **Missing libraries** that enabled add-ons require but that are not installed, and **Unused libraries** that are installed and marked as libraries by the game but are not required by any currently enabled add-on. For a dependency that is **not** installed, LibScanner only counts it toward the library views when its name **looks like** a library (heuristic: name starts with `Lib`), consistent with limited metadata for absent add-ons.

**Target game build.** Declared in [`LibScanner/LibScanner.txt`](LibScanner/LibScanner.txt): `APIVersion` **101049**.

## Repository layout

- **Add-on folders** — One folder per add-on at the repo root (e.g. `LibScanner/`).
- **[`.shared/`](.shared/)** — Not an add-on. Holds editor / language-server support files, including the ESO API stub used by LuaLS.
- **[`scripts/`](scripts/)** — Maintenance scripts (stub generation, add-on catalog / code scan).
- **[`data/`](data/)** — Generated audit outputs; see [Add-on catalog (audit baseline)](#add-on-catalog-audit-baseline) below.
- **[`.vscode/`](.vscode/)** — Editor tasks and workspace settings.
- **[`.cursor/rules/`](.cursor/rules/)** — Cursor rules for working in this repo.

## Add-on catalog (audit baseline)

**Primary result.** Open [`data/addon_catalog.csv`](data/addon_catalog.csv) in a spreadsheet or editor: one row per add-on with manifest fields, offline **`enabled`** (from `live/AddOnSettings.txt`), **`purpose_tags`**, merged **`functionality_notes`** (description + optional `[code-scan]` line), **`enablement_steps`** where filled, and placeholders for ESOUI / LibScanner columns.

**Supporting files in [`data/`](data/):**

| File | Role |
|------|------|
| [`addon_code_signals.csv`](data/addon_code_signals.csv) | Slash / events / LAM / SavedVars heuristics per folder |
| [`addon_summaries/<Folder>.txt`](data/addon_summaries) | Human-readable signal dump per add-on |
| [`addon_embedded_libs.csv`](data/addon_embedded_libs.csv) | Nested `Lib*` under a non-lib add-on |
| [`esoui_stub.csv`](data/esoui_stub.csv) | Fill `esoui_url` / category manually after ESOUI search |
| [`audit_remediation.md`](data/audit_remediation.md) | Watchlist goals and enablement templates |
| [`libscan_export.tsv`](data/libscan_export.tsv) | Paste LibScanner TSV for `merge_libscan_tsv.py` |

Regenerate (defaults use the same Steam Proton `live/AddOns` path as `scripts/deploy_steam_eso_addons.sh`; override with `ESO_ADDONS_DIR` / `ESO_LIVE_DIR`):

```bash
python3 scripts/catalog_addons.py
python3 scripts/scan_addon_code.py
```

Optional: merge LibScanner TSV after exporting in-game — copy from `LibScanner.lua` SavedVariables into `data/libscan_export.tsv` or pass `--savedvars`:

```bash
python3 scripts/merge_libscan_tsv.py --savedvars "$HOME/.../live/SavedVariables/LibScanner.lua"
```

**Steam deploy.** [`scripts/deploy_steam_eso_addons.sh`](scripts/deploy_steam_eso_addons.sh) copies repo add-ons that have a matching manifest. **`LootLogCustom` is currently skipped** (repo-only fork); remove it from `SKIP_NAMES` in that script when you want it deployed.

## Lua language server

The game exposes a large global API at runtime. This repo includes a LuaLS / EmmyLua stub ([`.shared/eso-api-stubs/eso_api.lua`](.shared/eso-api-stubs/eso_api.lua)) so those globals are not reported as undefined. Editor configuration lives in [`.luarc.json`](.luarc.json).

Regenerate the machine-generated portion of the stub from UESP ESO API dumps:

```bash
python3 scripts/generate_eso_api_stubs.py
```

## License

MIT — see [LICENSE](LICENSE).
