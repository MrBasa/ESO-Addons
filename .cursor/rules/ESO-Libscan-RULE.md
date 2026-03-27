## Purpose

`LibScanner` is an **Elder Scrolls Online (ESO)** add-on (folder [`LibScanner/`](../../LibScanner/)). It helps you identify:

- which installed add-on **libraries** are missing dependencies
- which libraries look **unused** (candidates for removal)

**ESO** means *Elder Scrolls Online*.

Target runtime: **Elder Scrolls Online Update 49.0**, per [`LibScanner/manifest.txt`](../../LibScanner/manifest.txt) (`## APIVersion: 101049`).

Global repo layout, Lua stubs, and UESP vs manifest API versions are described in [`ESO-Global-RULE.md`](ESO-Global-RULE.md) and [`ESO-LuaAPI-RULE.md`](ESO-LuaAPI-RULE.md).

## Key APIs used in `LibScanner/LibScanner.lua`

- `AddOnManager:*`
  - `GetNumAddOns()`
  - `GetAddOnInfo(i)`
  - `GetAddOnVersion(i)`
  - `GetAddOnNumDependencies(i)`
  - `GetAddOnDependencyInfo(i, j)`
- `EVENT_MANAGER:*`
  - `RegisterForEvent(addonName, EVENT_ADD_ON_LOADED, callback)`
  - `UnregisterForEvent(addonName, EVENT_ADD_ON_LOADED)`
- Slash commands:
  - `SLASH_COMMANDS["/libscan"]`
- Scroll list helpers:
  - `ZO_ScrollList_GetDataList`
  - `ZO_ScrollList_Clear`
  - `ZO_ScrollList_CreateDataEntry`
  - `ZO_ScrollList_Commit`
  - `ZO_ScrollList_AddDataType`

## Notes for code changes

- Follow the repo-wide **linting requirement** in [`ESO-Global-RULE.md`](ESO-Global-RULE.md) for every task (check diagnostics on changed Lua/XML-related work).
- Keep dependency logic aligned with ESO’s add-on/library model (only treat a dependency as a *library* when it exists as an installed library when possible).
- UI strings may contain ESO color codes (`|c...` / `|r`); strip them when you need plain text.
