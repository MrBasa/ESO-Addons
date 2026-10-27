## Purpose

LuaLS / EmmyLua metadata for **Elder Scrolls Online (ESO)** add-on Lua. It improves diagnostics and completions in the editor; it is **not** a runtime substitute for the game.

Two layers, in this order (do **not** run a second full API corpus beside FlatBadger):

1. **Prefix (wins on conflict)** — [`.shared/eso-api-stubs/eso_api_prefix.lua`](../../.shared/eso-api-stubs/eso_api_prefix.lua). Small, hand-written, live-checked arities we verified (AddOnManager six-return `GetAddOnInfo` / `GetAddOnDependencyInfo`, `EVENT_MANAGER`, `SLASH_COMMANDS`, `ZO_ScrollList_*`).
2. **FlatBadger (breadth + constant values)** — [`.shared/eso-api/`](../../.shared/eso-api/) (`library/globals.lua`, `api.lua`, `classes.lua`, …). Vendored [eso-api](https://github.com/Flat-Badger-1971/eso-api) / [ESOUI info4074](https://www.esoui.com/downloads/info4074-ESOluaAPIintellisenseforVisualStudioCode.html). This is where `CRAFTING_TYPE_WOODWORKING = 6` (and the rest of the enum) comes from.

- **Agent contract:** Before unpacking multi-return ESO APIs (especially **Add-On Manager**), read the **prefix**. That file is this repo’s **default source of truth** for those signatures. If you confirm the live client differs, **update the prefix** (and this rule if the lesson is general). Do **not** “fix” FlatBadger in place; the next vendor refresh would overwrite it.
- **What the prefix is:** A short human-written EmmyLua file. It exists because wiki pages and FlatBadger still get **arity wrong** on a few APIs we actually unpack (FlatBadger’s `AddOnManager:GetAddOnInfo` is still an eight-return annotation). It is **not** generated.
- **How the prefix stays current:** Only when a live client or installed reference add-on (LibDebugLogger, WritWorthy, etc.) disagrees. Then edit the prefix. Never regenerate it from UESP.
- **Constants:** Use the game globals `CRAFTING_TYPE_*` in Lua, or `GetString("SI_TRADESKILLTYPE", station)` / `SI_*` after checking [ESOUI wiki](https://wiki.esoui.com/) **and** an installed reference addon (e.g. CharacterKnowledge). **Never invent** `1=blacksmith …` maps from memory — a hand-built table already swapped wood (6) / provision (5) / enchant (3) when the old UESP dump emitted `= nil`.
- If FlatBadger is **missing a symbol we hit**, add it to the **prefix**. Do **not** revive `scripts/generate_eso_api_stubs.py` or fetch `esoapi.uesp.net`.
- **ESO** means *Elder Scrolls Online*.
- When you change this tooling or stubs, follow the **linting requirement** in [`ESO-Global-RULE.md`](ESO-Global-RULE.md) on the files you edit.

## Primary human documentation

**[ESOUI wiki](https://wiki.esoui.com/)** is the main **community-maintained** API reference (functions, events, objects, tutorials). It is **not** hosted by Zenimax/Bethesda, but it is what most authors treat as the canonical *readable* documentation.

## FlatBadger vs live client

**Stubs vs live:** The **prefix** documents live-aligned patterns; FlatBadger is machine-derived from the game API dump and may still disagree on edge symbols.

Example: `AddOnManager:GetAddOnInfo(i)` in live builds commonly returns **`name, title, author, description, enabled, state`** (six values, `state` is `ADDON_STATE_*`) as used in add-ons such as **LibDebugLogger**—do not assume a seventh `isLibrary` / `isOutOfDate` split unless verified against **wiki + live** or **installed reference add-ons**. **`GetAddOnDependencyInfo`** commonly returns **six** values on live: `dependencyName`, `dependencyExists`, `dependencyActive`, `dependencyMinVersion`, `dependencyVersion`, and **`isLibrary`** (boolean per ESOUI `ESOUIDocumentation.txt`)—the sixth is **not** “optional vs required”; optional deps remain manifest-only. Prefer **cross-checking** with [`scripts/deploy_steam_eso_addons.sh`](../../scripts/deploy_steam_eso_addons.sh) target `AddOns` trees or ESOUI examples over trusting a library annotation alone.

Your add-on `## APIVersion:` in the add-on’s **`.txt` / `.addon` manifest** (see [`ESO-Global-RULE.md`](ESO-Global-RULE.md)) may be **newer** than the vendored FlatBadger tree. See [`.shared/eso-api/SOURCE.txt`](../../.shared/eso-api/SOURCE.txt) for the package that is checked in.

## Updating FlatBadger after a major ESO patch

The ESOUI zip **is** FlatBadger’s release ([info4074](https://www.esoui.com/downloads/info4074-ESOluaAPIintellisenseforVisualStudioCode.html), package names like `eso-api-update-51.zip`). [GitHub `Flat-Badger-1971/eso-api`](https://github.com/Flat-Badger-1971/eso-api) is the same project and often lags. After a live `## APIVersion` bump, refresh the vendor:

```bash
# Terminal (from the ESO-Addons repo root)
scripts/update_eso_api.sh --check
scripts/update_eso_api.sh
```

Or the VS Code / Cursor task **update:eso-api** (check-only variant: **update:eso-api (check only)**). The script downloads the latest ESOUI zip, replaces [`.shared/eso-api/`](../../.shared/eso-api/), rewrites `SOURCE.txt`, and refuses a package where `CRAFTING_TYPE_WOODWORKING` is `nil`. It never touches the prefix. Offline: `scripts/update_eso_api.sh --from-zip /path/to/eso-api-update-NN.zip`.

Then confirm `.luarc.json` still lists **prefix first**, then `./.shared/eso-api/library`. If a needed symbol is missing, add it to the prefix.

Optional load-time tradeoff (upstream): `library/zoclasses.lua` is large. To use the min cut, rename `zoclasses.lua` → `zoclasses.max` and `zoclasses.min` → `zoclasses.lua`.

There is **no** UESP generator in this repo. Do not add one.

## Local configuration

- [`.luarc.json`](../../.luarc.json) — `workspace.library` is **prefix, then FlatBadger** (Lua 5.1). Optional `diagnostics.globals` lists names created only from XML (e.g. top-level controls).
- [`.vscode/settings.json`](../../.vscode/settings.json) — mirror the above for the VS Code Lua extension (`Lua.*` keys).
