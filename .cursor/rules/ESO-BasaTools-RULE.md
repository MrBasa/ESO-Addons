## Purpose

[`BasaTools/`](../../BasaTools/) is an **Elder Scrolls Online (ESO)** add-on. It is the control panel for **our** custom tools only: [`WritMatch`](../../WritMatch/) and [`LibScanner`](../../LibScanner/).

**ESO** means *Elder Scrolls Online*.

Out of scope: LootLogCustom, `scripts/`, favorite-wayshrine backlog, community add-ons.

Target runtime: per [`BasaTools/BasaTools.txt`](../../BasaTools/BasaTools.txt) (`## APIVersion: 101050`). LuaLS: prefix + FlatBadger ([`ESO-LuaAPI-RULE.md`](ESO-LuaAPI-RULE.md)).

## Behaviour

- Slash: `/basatools` toggles one window. Manifest folder name must match (`BasaTools/BasaTools.txt`).
- One tab per tool. `OptionalDependsOn` WritMatch and LibScanner; a tab is omitted if that add-on is not loaded (`Addon.Run` missing).
- **Tabs are mouse-enabled `Label`s** (`ZoFontHeader3`) with `GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_SELECTED|CONTRAST|HIGHLIGHT)`. Same idea as main-menu subcategory labels. Do **not** use `ZO_LabelButtonBar` / `ZO_MenuBar` here: those are **icon** slots. Missing `normal`/`pressed`/`highlight` DDS textures render as **white squares**.
- Operation buttons use **`ZO_Tooltips_ShowTextTooltip` / `HideTextTooltip`** (`OnMouseEnter` / `OnMouseExit`). Tab labels get the same from Lua `SetHandler`.
- Do **not** merge tool Lua into this shell. Tools expose `Run(op)`, `SetOutputSink(fn)`, `GetHelpText()`.
- Shared output: multiline `EditBox` in `ZO_EditBackdrop` (pChat / LibSets / LoreBooks copy path). Selectable. Sanitize `|c` / `|H` / remaining pipes before `SetText`.
- While the window is shown, bind each tool’s sink so `Chat()` / status lines also land in the pane; unbind on hide. Chat still receives the original lines (item links).
- Huge lists: do not dump LibScanner’s full report into chat. Per-bucket copy via `ZO_GetChatSystem():StartTextEntry` (Broken / Optional / Unused). Pane **Copy → chat** only if the body is short.
- LibScanner Versions / Libraries `ZO_ScrollList` stays in LibScanner’s own window (Scan / Open LibScanner). Do not replace it with `ZO_TextBuffer`.
- Button XML: `OnClicked`, not `OnClick`. Do not call Lua from XML `OnInitialized`.
- Each tab has **Help** that writes that tool’s `GetHelpText()` into the pane.

## Notes

- Follow linting in [`ESO-Global-RULE.md`](ESO-Global-RULE.md).
- Never invent `CRAFTING_TYPE_*` maps; WritMatch already uses game enums / `GetString`.
