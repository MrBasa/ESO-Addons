## Purpose

This repository is a collection of **[Elder Scrolls Online](https://www.elderscrollsonline.com/)** (**ESO**) add-ons. **ESO** means *Elder Scrolls Online*.

## Layout

- Each **immediate child directory** of the repo root whose contents constitute one installable add-on (typically includes `manifest.txt` alongside `.lua` / `.xml` assets) is **one individual ESO add-on**.
- Shared editor/LSP assets live under `.shared/` (not an add-on).

## Lua language server

ESO injects a large set of globals at runtime. Local development uses LuaLS/EmmyLua stubs so those names are not flagged as undefined:

- Stub entrypoint: [`.shared/eso-api-stubs/eso_api.lua`](../../.shared/eso-api-stubs/eso_api.lua)  
- Regenerate stubs with: `python3 scripts/generate_eso_api_stubs.py` (see [`.cursor/rules/ESO-LuaAPI-RULE.md`](ESO-LuaAPI-RULE.md)).

Add-on-specific conventions and APIs belong in per-add-on Cursor rules (for example [`ESO-Libscan-RULE.md`](ESO-Libscan-RULE.md)).

## Linting (required for every task)

As part of **every** task—before considering the work finished—**check the code and config you touched for linter / diagnostic errors** and resolve them (or explicitly justify any intentional exception in the task outcome).

- **Lua:** LuaLS / EmmyLua diagnostics on changed `.lua` files (and ensure [`.luarc.json`](../../.luarc.json) still matches how the project is meant to analyze add-on code).
- **Other:** Use the appropriate linter or schema validation for the file types you edited (for example JSON / JSONC under [`.vscode/`](../../.vscode/), Markdown if your toolchain reports issues).

Do not stop at “it looks fine”; run or consult whatever lint/diagnostic pass your environment provides (e.g. IDE **Problems** / `read_lints` on edited paths) and leave the workspace clean of new errors introduced by the task.
