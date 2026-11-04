# Maintainer notes

Technical notes for people who develop or package this suite. Player-facing docs live in the [README](../README.md).

## Repository layout

| Path | Role |
|------|------|
| `BasaTools/`, `WritMatch/`, `LibScanner/`, `MatLog/` | Installable ESO add-ons (one folder each) |
| [`.shared/`](../.shared/) | LuaLS / FlatBadger eso-api stubs (not an add-on) |
| [`scripts/`](../scripts/) | Suite packaging, deploy helpers, catalog / health audit, eso-api refresh |
| [`data/`](../data/) | Generated audit outputs |
| [`.vscode/`](../.vscode/) | Editor tasks |
| [`.cursor/rules/`](../.cursor/rules/) | Cursor rules for add-on behaviour |

## Versions & GitHub release

There is no central version file. Each add-on has its own `## Version` and integer `## AddOnVersion` in `<Addon>/<Addon>.txt`.

1. Bump **only** add-ons that changed. Keep `## AddOnVersion` monotonic (ESO uses it for update detection).
2. Suite zip name comes from the CLI arg, `v*` git tag, or fallback `BasaTools` `## Version` — see [`scripts/package_basatools_suite.sh`](../scripts/package_basatools_suite.sh).
3. Local dry-run: `scripts/package_basatools_suite.sh X.Y.Z` → `dist/BasaToolsSuite-vX.Y.Z.zip`.
4. Tag and push `vX.Y.Z` to run [`.github/workflows/release.yml`](../.github/workflows/release.yml) and attach the zip to the GitHub Release.

> VS Code / Cursor task: **Package: BasaTools suite**.

## Local deploy (optional)

[`scripts/deploy_steam_eso_addons.sh`](../scripts/deploy_steam_eso_addons.sh) copies repo add-on folders into a local `AddOns` tree (`cp -a`; does **not** delete stale files by default). Override the destination with `ESO_ADDONS_DIR`. To remove orphans under those deployed folders after copy: `--prune` or `DEPLOY_PRUNE=1`.

> VS Code / Cursor task: **Deploy: Steam ESO addons**.

## Add-on catalog / health

```bash
python3 scripts/catalog_addons.py
python3 scripts/scan_addon_code.py
python3 scripts/eso_addon_health.py -o data/addon_health_report.md
```

See [`data/addon_catalog.csv`](../data/addon_catalog.csv) and related files under [`data/`](../data/).

## Lua language server

LuaLS uses [`.luarc.json`](../.luarc.json): hand prefix [`.shared/eso-api-stubs/eso_api_prefix.lua`](../.shared/eso-api-stubs/eso_api_prefix.lua) then FlatBadger [`.shared/eso-api/library`](../.shared/eso-api/library). Refresh after major patches:

```bash
scripts/update_eso_api.sh --check
scripts/update_eso_api.sh
```

Details: [`.cursor/rules/ESO-LuaAPI-RULE.md`](../.cursor/rules/ESO-LuaAPI-RULE.md).
