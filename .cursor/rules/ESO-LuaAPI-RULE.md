## Purpose

The file [`.shared/eso-api-stubs/eso_api.lua`](../../.shared/eso-api-stubs/eso_api.lua) provides **LuaLS / EmmyLua** metadata for **Elder Scrolls Online (ESO)** add-on Lua. It improves diagnostics and completions in the editor; it is **not** a runtime substitute for the game.

- **ESO** means *Elder Scrolls Online*.
- When you change this tooling or stubs, follow the **linting requirement** in [`ESO-Global-RULE.md`](ESO-Global-RULE.md) on the files you edit (Python generator, JSON, Lua manual prefix, etc.).
- Regenerate the machine-derived portion with:

  ```bash
  python3 scripts/generate_eso_api_stubs.py
  ```

  Use `python3 scripts/generate_eso_api_stubs.py --help` for options (e.g. `--pin-version`).

## Primary human documentation

**[ESOUI wiki](https://wiki.esoui.com/)** is the main **community-maintained** API reference (functions, events, objects, tutorials). It is **not** hosted by Zenimax/Bethesda, but it is what most authors treat as the canonical *readable* documentation.

**Phase A IntelliSense:** the generator emits `---@see https://wiki.esoui.com/wiki/...` only for symbols explicitly listed in [`.shared/eso-api-stubs/wiki_title_map.json`](../../.shared/eso-api-stubs/wiki_title_map.json) (no automatic guessing, to avoid dead wiki links).

## Machine-derived “whole API” coverage

**UESP ESO Data** ([esoapi.uesp.net](https://esoapi.uesp.net/)) publishes globals and function definitions **extracted from ESO’s Lua**. The generator:

1. Resolves the **latest published** API version listed on the UESP index (or uses `--pin-version`).
2. Downloads that version’s `globals.txt` and `globalfuncs.txt`.
3. Writes a **banner comment** in the generated section with the **UESP API version**, **UTC generation time**, and **source URLs**.

**Important:** Your add-on `## APIVersion:` in `manifest.txt` may be **newer** than UESP’s last dump. The banner states the exact UESP version used so you can tell when stubs lag the live client.

## Local configuration

- [`.luarc.json`](../../.luarc.json) — `workspace.library` points at `./.shared/eso-api-stubs/eso_api.lua` (Lua 5.1 runtime). Optional `diagnostics.globals` lists names created only from XML (e.g. top-level controls) that are not practical to model inside the massive generated stub.
- [`.vscode/settings.json`](../../.vscode/settings.json) — mirror the above for the VS Code Lua extension (`Lua.*` keys).

## Further reading

- Phase B (wiki summaries via MediaWiki API): [`docs/eso-api-stubs-wiki-enrichment.md`](../../docs/eso-api-stubs-wiki-enrichment.md).

</think>


<｜tool▁calls▁begin｜><｜tool▁call▁begin｜>
StrReplace