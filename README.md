# ESO-Addons (BasaTools suite)

Add-ons for [The Elder Scrolls Online](https://www.elderscrollsonline.com/) (ESO).

**Usual install for friends / guild-mates:** download the latest **suite zip** from [GitHub Releases](https://github.com/MrBasa/ESO-Addons/releases) and extract it into your live `AddOns` folder.

## Suite contents

| Add-on | Role |
|--------|------|
| [BasaTools](BasaTools/) | Control panel (`/basatools`): hosts tool tabs + native UI Tweaks / HUD icon |
| [WritMatch](WritMatch/) | Reconcile sealed master writs with backpack gear (`/writmatch`) |
| [LibScanner](LibScanner/) | Scan library / dependency status (UI hosted in BasaTools) |
| [MatLog](MatLog/) | Track gathered materials, surveys, and master writs (UI hosted in BasaTools) |

Each folder is its **own** ESO add-on (modular). The release zip installs all four together. Enable them in **Settings → Add-Ons**.

## Install from GitHub Releases

1. Open [Releases](https://github.com/MrBasa/ESO-Addons/releases) and download `BasaToolsSuite-v*.zip`.
2. Extract so you get four folders next to your other add-ons (not nested inside another folder):

   - `AddOns/BasaTools/`
   - `AddOns/WritMatch/`
   - `AddOns/LibScanner/`
   - `AddOns/MatLog/`

3. Launch ESO → **Settings → Add-Ons** → enable those four (and their required libraries).
4. Type **`/basatools`** in chat (or use the optional HUD icon from the Tweaks tab).

### AddOns folder locations

| Platform | Typical path |
|----------|----------------|
| Windows | `Documents\Elder Scrolls Online\live\AddOns` |
| macOS | `~/Documents/Elder Scrolls Online/live/AddOns` |
| Steam Proton / Linux | `~/.steam/steam/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/AddOns` (this repo’s workstation also uses `~/Games/ESO/live/AddOns`) |

The game expects `AddonFolder/AddonFolder.txt` (or `.addon`) with the **same basename** as the folder.

### Libraries (Minion / ESOUI)

| Library | Needed for |
|---------|------------|
| **LibLazyCrafting** | **Required** by WritMatch |
| **LibPrice** | MatLog gold columns (optional; values blank without it) |
| **WritWorthy** | Tweaks gold-per-voucher overlay / Granny’s Eel Pie support (optional) |
| **Dolgubon’s Lazy Writ Crafter** | Better MatLog writ-coffer detection (optional) |
| **LibDebugLogger** | Structured logs / DebugLogViewer (optional; no chat nag if missing) |

On first load, BasaTools prints a short chat summary if optional tools or libraries are missing.

Official **Loot Log** from Minion remains the general loot journal; MatLog covers mats / surveys / master writs.

## Add-on details

### BasaTools

One window for **WritMatch**, **LibScanner**, and **MatLog**, plus native **Tweaks** (inventory gold-per-voucher overlay, Granny’s Eel Pie WritWorthy helpers, movable HUD icon). Tool tabs are omitted when that add-on is not loaded. Tweaks always show.

Settings (toggles, last tab, HUD position, window size) are **account-wide** via `BasaToolsSaved`. Target API: **101050**.

### WritMatch

Requires **LibLazyCrafting**. Optional: WritWorthy, Lazy Writ. Slash: `/writmatch`, `/writmatch crafts|queues|kick|orphans`.

### LibScanner

Slash: `/libscan`, `/libscanexport`, `/libscandebug`. Versions / Libraries UI lives in the BasaTools LibScanner tab when BasaTools is enabled.

### MatLog

Optional: LibPrice, Lazy Writ. Hosted as a BasaTools tab. SavedVariables: `MatLogSaved` (one-time migrate from legacy `BasaToolsSaved.matlog*` keys).

## Maintainer / local tooling

Repository layout beyond the four add-ons:

- [`.shared/`](.shared/) — LuaLS / FlatBadger eso-api (not an add-on)
- [`scripts/`](scripts/) — Steam deploy, suite packaging, catalog / health audit, eso-api refresh
- [`data/`](data/) — generated audit outputs
- [`.vscode/`](.vscode/) — editor tasks
- [`.cursor/rules/`](.cursor/rules/) — Cursor rules

### Package a release zip (dry-run)

```bash
scripts/package_basatools_suite.sh 1.3.26
# → dist/BasaToolsSuite-v1.3.26.zip
```

Pushing a `v*` tag runs [`.github/workflows/release.yml`](.github/workflows/release.yml) and attaches that zip to the GitHub Release.

VS Code / Cursor task: **Package: BasaTools suite**.

### Steam deploy (this workstation)

[`scripts/deploy_steam_eso_addons.sh`](scripts/deploy_steam_eso_addons.sh) copies repo add-on folders into the Steam Proton `AddOns` tree. Override with `ESO_ADDONS_DIR`. Task: **Deploy: Steam ESO addons**.

### Add-on catalog / health

```bash
python3 scripts/catalog_addons.py
python3 scripts/scan_addon_code.py
python3 scripts/eso_addon_health.py -o data/addon_health_report.md
```

See [`data/addon_catalog.csv`](data/addon_catalog.csv) and related files under [`data/`](data/).

### Lua language server

LuaLS uses [`.luarc.json`](.luarc.json): hand prefix [`.shared/eso-api-stubs/eso_api_prefix.lua`](.shared/eso-api-stubs/eso_api_prefix.lua) then FlatBadger [`.shared/eso-api/library`](.shared/eso-api/library). Refresh after major patches:

```bash
scripts/update_eso_api.sh --check
scripts/update_eso_api.sh
```

Details: [`.cursor/rules/ESO-LuaAPI-RULE.md`](.cursor/rules/ESO-LuaAPI-RULE.md).

## License

MIT — see [LICENSE](LICENSE).
