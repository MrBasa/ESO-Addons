# ESO-Addons

A collection of add-ons for [The Elder Scrolls Online](https://www.elderscrollsonline.com/) (ESO), plus shared assets for local Lua editing.

## Add-ons

| Add-on | Description |
|--------|-------------|
| [LibScanner](LibScanner/) | Scans library dependencies and shows add-on version / dependency status in a UI window. |

Documentation pattern: every add-on listed above has a detailed subsection under [Add-on details](#add-on-details). When you add a new add-on to the repo, add a table row here and a new `###` section there using the same structure as LibScanner (purpose and usage; installation is covered once below).

## Installation

These steps are the same for every add-on folder in this repository (for example [`LibScanner`](LibScanner/) or any future add-on at the repo root):

1. Copy the **entire** add-on folder (the directory that contains that add-on's `manifest.txt`) into your live client's **`AddOns`** directory — for example `Documents/Elder Scrolls Online/live/AddOns` on Windows, or the `live/AddOns` path your launcher uses on Linux/macOS.
2. Launch ESO and open **Settings → Add-Ons**.
3. Enable the add-on (and satisfy any **Required dependencies** the game lists for it).

Treat this like any other community add-on: one folder per add-on, names must match what the manifest expects, and libraries your add-on depends on must be installed separately.

## Add-on details

### LibScanner

**Purpose.** Surfaces dependency and version information from ESO's **Add-On Manager**: which **enabled, non-library** add-ons are up to date, which have **missing dependencies**, which **library** dependencies are missing **globally**, and which installed libraries appear **unused** (no enabled add-on lists them as a dependency).

**Usage.** After you install the folder with [Installation](#installation), type **`/libscan`** in chat. Each time you open the window this way, LibScanner re-runs its scan.

The UI has two tabs:

- **Versions** — Sortable list of enabled add-ons that are **not** libraries (titles are shown with ESO color codes stripped). Each row shows the add-on name, a **Yes/No** up-to-date indicator, the manifest `## Version` string, and—when the API reports gaps—a **Missing:** line listing dependencies that are not present.
- **Libraries** — Text panel with two lists: **Missing libraries** that enabled add-ons require but that are not installed, and **Unused libraries** that are installed and marked as libraries by the game but are not required by any currently enabled add-on. For a dependency that is **not** installed, LibScanner only counts it toward the library views when its name **looks like** a library (heuristic: name starts with `Lib`), consistent with limited metadata for absent add-ons.

**Target game build.** Declared in [`LibScanner/manifest.txt`](LibScanner/manifest.txt): **Update 49.0** (`APIVersion` **101049**).

## Repository layout

- **Add-on folders** — One folder per add-on at the repo root (e.g. `LibScanner/`).
- **[`.shared/`](.shared/)** — Not an add-on. Holds editor / language-server support files, including the ESO API stub used by LuaLS.
- **[`scripts/`](scripts/)** — Maintenance scripts (e.g. stub generation).
- **[`.vscode/`](.vscode/)** — Editor tasks and workspace settings.
- **[`.cursor/rules/`](.cursor/rules/)** — Cursor rules for working in this repo.

## Lua language server

The game exposes a large global API at runtime. This repo includes a LuaLS / EmmyLua stub ([`.shared/eso-api-stubs/eso_api.lua`](.shared/eso-api-stubs/eso_api.lua)) so those globals are not reported as undefined. Editor configuration lives in [`.luarc.json`](.luarc.json).

Regenerate the machine-generated portion of the stub from UESP ESO API dumps:

```bash
python3 scripts/generate_eso_api_stubs.py
```

## License

MIT — see [LICENSE](LICENSE).
