# ESO-Addons

A collection of add-ons for [The Elder Scrolls Online](https://www.elderscrollsonline.com/) (ESO), plus shared assets for local Lua editing.

## Add-ons

| Add-on | Description |
|--------|-------------|
| [BasaTools](BasaTools/) | Control panel for *our* custom tools (WritMatch, LibScanner) plus UI Tweaks and MatLog. Slash `/basatools`. |
| [LibScanner](LibScanner/) | Scans library dependencies; Versions and Libraries lists are hosted in BasaTools. |
| [WritMatch](WritMatch/) | Reconciles sealed master writs with backpack gear; flags LLC/WritWorthy/Lazy Writ complete, queues leftover improvement, lists orphaned queue jobs. |
| [LootLogCustom](LootLogCustom/) | **Archived** ILikeMoneyEdition fork of Loot Log. Not deployed. Gathered mats/surveys/writs live in BasaTools MatLog. |

Documentation pattern: every add-on listed above has a detailed subsection under [Add-on details](#add-on-details). When you add a new add-on to the repo, add a table row here and a new `###` section there using the same structure as LibScanner (purpose and usage; installation is covered once below).

## Installation

These steps are the same for every add-on folder in this repository (for example [`LibScanner`](LibScanner/) or any future add-on at the repo root):

1. Copy the **entire** add-on folder into your live client's **`AddOns`** directory. On this Steam Proton setup the game loads **`~/Games/ESO/live/AddOns`** (also reachable as `~/.steam/steam/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/AddOns` — that `live` entry is a symlink to `~/Games/ESO/live`). The manifest **must** live at **`AddonFolder/AddonFolder.txt`** or **`AddonFolder/AddonFolder.addon`** (same basename as the folder, e.g. [`LibScanner/LibScanner.txt`](LibScanner/LibScanner.txt)). Many current ESOUI packages ship **only** `.addon`. The client **does not** load arbitrary names such as `manifest.txt`; if the filename does not match the folder, the add-on will not appear or run.
2. Launch ESO and open **Settings → Add-Ons**.
3. Enable the add-on (and satisfy any **Required dependencies** the game lists for it).

Treat this like any other community add-on: one folder per add-on, names must match what the manifest expects, and libraries your add-on depends on must be installed separately. Optional `manifest.txt` (or similar) in-repo is **non-runtime** documentation only unless you rename it to match the game’s rule above.

## Add-on details

### BasaTools

**Purpose.** One window for the custom tools in this repo (**WritMatch**, **LibScanner**) plus native **Tweaks** (inventory gold-per-voucher overlay, HUD icon) and **MatLog** (gathered materials, surveys, master writs). Hosted tools stay in their own add-ons; each BasaTools tab is its own module (`RegisterTab`). Keep official Loot Log from Minion; [`LootLogCustom/`](LootLogCustom/) is an archive.

**Usage.** After you install the folder with [Installation](#installation), enable **BasaTools** plus the tools you want (they are `OptionalDependsOn`). Type **`/basatools`** to toggle the window. WritMatch / LibScanner tabs are omitted when that add-on is not loaded. Tweaks and MatLog are always shown. Hover an operation button for a short tooltip.

- **WritMatch** — Match writs, Show LLC queue, Clear LLC queue, Kick improve, Drop orphan jobs (same slash tokens as `/writmatch` …). **Help** shows a colored Action / Slash / Effect table.
- **LibScanner** — Scan add-ons (same as `/libscan`), Export TSV, Debug checkbox. Versions and Libraries lists are **in this tab**. Select text in Libraries to copy.
- **Tweaks** — One column of account-wide checkboxes: gold-per-voucher on sealed master writs (needs **WritWorthy**; does not replace sell price) and a movable **HUD icon** (custom BasaTools roundel; same as `/basatools`). No Help button or output pane on this tab.
- **MatLog** — Single enable checkbox. Records gathered materials, survey reports, and master writs for three daily-reset days. **Full** shows one row per item per character, with quantity, LibPrice gold (inventory-style stack total + unit, with coin icon), and source category: **Writ** (daily-writ coffer contents, including LWC auto-loot of surveys and sealed writs), **Hireling** (hireling mail, including Take all into the craft bag — player mail is skipped; a mixed System-mail Take all may include guild-store attachments), or **World** (loot). Filter by day, character, and that category; footer totals follow the filters. **Summary** stacks by item. Click a column header to sort (Gold sorts by stack total). Uses game `ZO_SortHeader` arrows.

Settings (toggles, last tab, HUD position, MatLog filters) are **account-wide**, not per character.

The WritMatch output pane is a selectable **EditBox** with per-line color (`|c` markup). It starts empty and only shows WritMatch (or Help) text. Item links become plain names there; chat still gets the original lines (including links). Copy may include color codes. The window is **resizable** (bottom-right edge; size is remembered). Help uses a single-line Action / Slash / Effect table; if Effect is wider than the pane, a **horizontal scrollbar** appears under the list.

Existing slash commands (`/writmatch`, `/libscan`, `/libscanexport`, `/libscandebug`) still work.

**Target game build.** Declared in [`BasaTools/BasaTools.txt`](BasaTools/BasaTools.txt): `APIVersion` **101050**.

### LibScanner

**Purpose.** Surfaces dependency and version information from ESO's **Add-On Manager**: which **enabled, non-library** add-ons are up to date, which have **missing dependencies**, which **library** dependencies are missing **globally**, and which installed libraries appear **unused** (no enabled add-on lists them as a dependency).

**Usage.** After you install the folder with [Installation](#installation), type **`/libscan`** in chat (opens the BasaTools LibScanner tab when BasaTools is loaded). **`/libscanexport`** runs the same scan and persists a TSV snapshot to **`LibScannerSavedVars.lastExport`** (SavedVariables file under `live/SavedVariables/`) for merging into the repo catalog via `scripts/merge_libscan_tsv.py`.

The UI (inside BasaTools) has two inner tabs:

- **Versions** — Sortable list of enabled add-ons that are **not** libraries (titles are shown with ESO color codes stripped). Each row shows the add-on name, a **Yes/No** up-to-date indicator, the manifest `## Version` string, and—when the API reports gaps—a **Missing:** line listing dependencies that are not present.
- **Libraries** — Selectable text panel with broken dependencies, optional-only `Lib*`, and unused `Lib*`. For a dependency that is **not** installed, LibScanner only counts it toward the library views when its name **looks like** a library (heuristic: name starts with `Lib`). On live clients manifests cannot be read; the report includes a **WARNING**.

**Target game build.** Declared in [`LibScanner/LibScanner.txt`](LibScanner/LibScanner.txt): `APIVersion` **101050**.

### WritMatch

**Purpose.** After a master-writ queue is interrupted (full bag, left the station, manual improve), WritWorthy / Lazy Writ / Master Writ Inventory Marker only show a green check if LibLazyCrafting finished the job. WritMatch scans the backpack, pairs each sealed smithing writ with a matching player-crafted piece (1:1), and updates those addons plus the LLC queue.

**Usage.** After you install the folder with [Installation](#installation), enable it (requires **LibLazyCrafting**; WritWorthy and Dolgubon's Lazy Writ Crafter are optional). In chat:

- **`/writmatch crafts`** — clear WritWorthy **queued** flags and drop all craft-new LLC jobs, including provisioning/alchemy/enchanting (keeps improvement). Does **not** stop daily auto-craft by itself.
- **`/writmatch queues`** — dump every LibLazyCrafting job (addon, station, type, item). Paste this if something unexpected crafts.
- **`/writmatch kick`** — at a station, start the next improve job if LLC stopped after one.
- **`/writmatch`** — apply: mark turn-in-ready writs complete, convert under-quality matches into **WritMatch** LLC improve jobs (and dequeue those writs from WritWorthy so they cannot craft-new again), list unmatched writs and orphaned queue rows. Unmatched writs that are already queued in WritWorthy stay queued.
- **`/writmatch orphans`** — cancel those orphaned LLC jobs.

Chat is grouped (Complete / Improve / Unmatched / Orphans) with clickable item links. Unmatched lines include the wanted set, item, trait, style, and quality. v1 is backpack + smithing only (blacksmith, clothier, woodworking, jewelry).

**Target game build.** Declared in [`WritMatch/WritMatch.txt`](WritMatch/WritMatch.txt): `APIVersion` **101050**.

### LootLogCustom

**Purpose.** Archive of an ILikeMoneyEdition v02 overlay on Loot Log 4.8.3.1 (gold journal tab, LibPrice columns). It is **not** installed by the Steam deploy script. Use **official Loot Log** from Minion plus **BasaTools MatLog** for gathered materials, surveys, and master writs.

**Target game build.** Historical only: [`LootLogCustom/LootLogCustom.txt`](LootLogCustom/LootLogCustom.txt) (`APIVersion` **101046**).

## Repository layout

- **Add-on folders** — One folder per add-on at the repo root (e.g. `LibScanner/`).
- **[`.shared/`](.shared/)** — Not an add-on. Holds editor / language-server support: the live-checked LuaLS prefix and vendored FlatBadger eso-api.
- **[`scripts/`](scripts/)** — Maintenance scripts (add-on catalog / code scan, Steam deploy, FlatBadger eso-api refresh).
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
| [`audit_remediation.md`](data/audit_remediation.md) | Watchlist goals and enablement steps |
| [`addon_health_report.md`](data/addon_health_report.md) | Latest offline health Markdown (optional regenerate) |
| [`libscan_export.tsv`](data/libscan_export.tsv) | Paste LibScanner TSV for `merge_libscan_tsv.py` |

Regenerate (defaults follow the Steam Proton `live/AddOns` path above, which resolves to `~/Games/ESO/live/AddOns`; override with `ESO_ADDONS_DIR` / `ESO_LIVE_DIR`):

```bash
python3 scripts/catalog_addons.py
python3 scripts/scan_addon_code.py
```

`catalog_addons.py` recognizes **`.txt` and `.addon`** manifests and **preserves** filled `esoui_url` / `esoui_category` values in [`data/esoui_stub.csv`](data/esoui_stub.csv) across regenerations.

Optional: merge LibScanner TSV after exporting in-game — copy from `LibScanner.lua` SavedVariables into `data/libscan_export.tsv` or pass `--savedvars`:

```bash
python3 scripts/merge_libscan_tsv.py --savedvars "$HOME/Games/ESO/live/SavedVariables/LibScanner.lua"
```

**Steam deploy.** [`scripts/deploy_steam_eso_addons.sh`](scripts/deploy_steam_eso_addons.sh) copies repo add-ons (repo root is derived from the script location) when it finds **`AddonName/AddonName.txt`** or **`.addon`**. Destination defaults to the Steam Proton AddOns path; override with **`ESO_ADDONS_DIR`**. **`LootLogCustom` stays in `SKIP_NAMES`** (archived fork; use BasaTools MatLog + official Loot Log).

**Minion (Flatpak `gg.minion.Minion`):** config `~/.var/app/gg.minion.Minion/.minion/minion.xml` — game `ESO-1` `addon-path` should stay on the Steam Proton AddOns path (symlink into `~/Games/ESO/live/AddOns`). Minion’s detector still probes `FolderName.txt`; packages that ship only `.addon` may show as undetected until reinstalled. Do not point Minion at `compatdata/306130.tmp` or `*.prewipe*` trees.

### Add-on health audit (CLI)

Offline check of your **live** `AddOns` and `SavedVariables` trees (manifest + folders only; no game client). Writes one **Markdown** report: missing required dependencies, missing optional **`Lib*`** dependencies only, `Lib*` roots not referenced in any manifest dep line, orphan `.lua` SavedVariables files (heuristic), stray artifacts (zips, junk paths), and nested `Lib*` folders under top-level non-`Lib` add-ons.

```bash
python3 scripts/eso_addon_health.py -o data/addon_health_report.md
# or: bash scripts/eso_addon_health.sh -o data/addon_health_report.md
```

Defaults: `--addons-dir` from **`ESO_ADDONS_DIR`** (preferred) or legacy **`ESO_ADDONS`**, else the Steam Proton `live/AddOns` path; SavedVariables defaults to `../SavedVariables` next to that `AddOns` folder. **`--exit-zero`** avoids a non-zero exit when required deps are missing (useful in CI). Caveats are in **`python3 scripts/eso_addon_health.py --help`** (missing optional `Lib*` deps are informational; orphan lists are not safe-delete guarantees; Windows/Wine paths may differ in casing).

## Lua language server

The game exposes a large global API at runtime. This repo does **not** keep a UESP-generated dump. LuaLS uses two libraries, in this order ([`.luarc.json`](.luarc.json), Lua 5.1):

1. **Prefix** ([`.shared/eso-api-stubs/eso_api_prefix.lua`](.shared/eso-api-stubs/eso_api_prefix.lua)) — small hand-written overrides for live-checked arities (AddOnManager six-return `GetAddOnInfo` / `GetAddOnDependencyInfo`, `EVENT_MANAGER`, `SLASH_COMMANDS`, `ZO_ScrollList_*`). This file wins when FlatBadger disagrees. Edit it only when live ESO or an installed reference addon (LibDebugLogger, WritWorthy) disagrees.
2. **FlatBadger eso-api** ([`.shared/eso-api/library`](.shared/eso-api/library)) — breadth plus real constant values (e.g. `CRAFTING_TYPE_WOODWORKING = 6`). Vendored from [ESOUI info4074](https://www.esoui.com/downloads/info4074-ESOluaAPIintellisenseforVisualStudioCode.html) (package `eso-api-update-51`, API near 101050–101051). See [`.shared/eso-api/SOURCE.txt`](.shared/eso-api/SOURCE.txt).

The ESOUI zip **is** FlatBadger’s package (same project as GitHub; ESOUI is usually newer). After a major ESO patch, refresh the vendor:

```bash
scripts/update_eso_api.sh --check
scripts/update_eso_api.sh
```

Cursor / VS Code task: **update:eso-api**. Do **not** add a second full API corpus. If a symbol is missing, add it to the prefix. Details: [`.cursor/rules/ESO-LuaAPI-RULE.md`](.cursor/rules/ESO-LuaAPI-RULE.md).

Never invent `CRAFTING_TYPE_*` integer maps. Use the game globals or `GetString("SI_TRADESKILLTYPE", station)` after wiki + a reference addon.

## License

MIT — see [LICENSE](LICENSE).
