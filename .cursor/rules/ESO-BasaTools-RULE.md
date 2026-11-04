## Purpose

[`BasaTools/`](../../BasaTools/) is an **Elder Scrolls Online (ESO)** add-on. It is the control panel for **our** custom tools ([`WritMatch`](../../WritMatch/), [`LibScanner`](../../LibScanner/), [`MatLog`](../../MatLog/)) plus native **Tweaks** (inventory overlay, HUD icon).

**ESO** means *Elder Scrolls Online*.

Out of scope: `scripts/`, favorite-wayshrine backlog, community add-on forks.

Target runtime: per [`BasaTools/BasaTools.txt`](../../BasaTools/BasaTools.txt) (`## APIVersion: 101050`). LuaLS: prefix + FlatBadger ([`ESO-LuaAPI-RULE.md`](ESO-LuaAPI-RULE.md)).

## Behaviour

- Slash: `/basatools` toggles one window. Manifest folder name must match (`BasaTools/BasaTools.txt`).
- Tabs register with `BasaTools.RegisterTab({ id, title, texture, tooltip, panelTemplate, usesOutput, fillPanel, available, buildPanel, onInit, onShown, onHelp })`. Shell XML is chrome only; each tab is a Lua module plus a virtual panel template.
- Tool tabs (WritMatch, LibScanner, MatLog): `OptionalDependsOn`; `available()` is false if that add-on is not loaded — the tab is not created.
- Native tab (Tweaks) always registers. Do not invent a fake global with `.Run` for it.
- **Tabs** sit on a **second row** under the title (not beside it). Virtual `BasaToolsTab`: game `Texture` plus `ZoFontHeader3` label, width from `GetStringWidth` of the full title — never measure a clipped label. Selected = `INTERFACE_TEXT_COLOR_SELECTED` and full-bright icon; idle = contrast + dimmed icon. Do **not** use `ZO_LabelButtonBar` / `ZO_MenuBar` here without `normal`/`pressed`/`highlight` DDS — missing textures render as **white squares**. Tweaks/HUD use custom `BasaTools/textures/hud.dds`; MatLog uses `inventory_tabIcon_crafting_up.dds`.
- Header rule is a **`Texture` inheriting `ZO_HorizontalDivider`** under the tab row (full window width). Do **not** use `ZO_WideHorizontalDivider` plus `SetHeight` — that clips the 9-slice. Close is a 32px `ZO_CloseButton` plus a 44px invisible `CloseHit` pad on the title row only.
- Operation buttons use **`ZO_Tooltips_ShowTextTooltip` / `HideTextTooltip`**.
- Do **not** merge WritMatch/LibScanner/MatLog Lua into the shell. WritMatch/LibScanner expose `Run(op)`, `SetOutputSink(fn)`, `GetHelpText()`, `GetHelpEntries()`. MatLog exposes panel helpers (`BindPanel`, `OnPanelShown`, `ShowHelp`). Native Tweaks live in [`BasaToolsTweaks.lua`](../../BasaTools/BasaToolsTweaks.lua).
- Shared tool output is a **read-only multiline EditBox** (`editEnabled="false"`, `mouseEnabled="true"`, `ALLOW_MARKUP_TYPE_COLOR_ONLY`). Strip `|H` item links and leftover pipes, then wrap each line with `|c` via `ZO_ColorDef:Colorize` so the pane is both colored and selectable. Copy may include `|c` codes. Help uses a 3-col `ZO_ScrollList` overlay (Labels + `SetColor`, not markup). Hide output chrome on fill-panel tabs (LibScanner, MatLog, Tweaks).
- While the window is shown, bind **WritMatch**’s sink so `Chat()` / status lines land in the output pane; unbind on hide. Chat still receives the original lines (item links). Do **not** bind LibScanner to that pane — scan results live on the LibScanner tab. The output pane starts empty (no welcome / how-to lines).
- LibScanner Versions / Libraries live **in the BasaTools LibScanner panel** (`LibScanner.SetHost`). Debug is a checkbox. Libraries report is a selectable EditBox.
- Button XML: `OnClicked`, not `OnClick`. Do not call Lua from XML `OnInitialized`.
- Window is **resizable** (`resizeHandleSize` + `DimensionConstraints`, size persisted in `BasaToolsSaved`). Drag the bottom-right edge. All toggles, last tab, HUD position, MatLog filters, and LibScanner inner tab persist **account-wide** via `ZO_SavedVars:NewAccountWide(..., GetWorldName(), GetDisplayName())` — not per character. Re-apply checkbox checked state every time a panel is shown (hidden `SetChecked` at init does not stick).
- **Help** for WritMatch renders `GetHelpEntries()` in the output overlay. LibScanner help fills the hosted Libraries EditBox. MatLog uses `onHelp`. Tweaks has **no Help button and no output pane** — a fill-panel with a single column of descriptive checkboxes.
- **Master-writ g/v overlay:** extra `CT_LABEL` on inventory rows (`WritWorthy.GetMatCost` / `ToVoucherCount`). Do **not** rewrite `SellPrice` / `SellPriceText`. No-op if WritWorthy is not loaded.
- **Granny's Eel Pie writ support:** Tweaks checkbox injects `FOODDRINK_TO_RECIPE_ITEM_ID[225205] = 225208` into WritWorthy when missing, and seeds `FALLBACK_PRICE` / `LINK` for Red Lichen (`225210`). Do not fork WritWorthy or Lazy Writ; Lazy Writ already uses `GetRecipeInfoFromItemId`.
- **HUD icon:** movable `TopLevelControl` + `ZO_SimpleSceneFragment` on `HUD_SCENE` / `HUD_UI_SCENE`; **no backdrop**. Texture is `BasaTools/textures/hud.dds` (custom hammer roundel). Left-click = `BasaTools.Toggle()`. Persist `iconPos` in SavedVars.
- **MatLog:** separate add-on [`MatLog/`](../../MatLog/); account-wide `MatLogSaved` (migrates once from legacy `BasaToolsSaved.matlog*`). Keyed by ESO daily-reset timestamp, per character; prune after **3 days**. Track gathered materials, survey reports, and master writs. Each row stores `source`: **Writ** / **Hireling** / **World**. Hosted in BasaTools via `OptionalDependsOn` + thin bridge. LWC coffer / hireling-mail / craft-bag behaviour unchanged from the former in-shell module.

## Notes

- Follow linting in [`ESO-Global-RULE.md`](ESO-Global-RULE.md).
- Never invent `CRAFTING_TYPE_*` maps; WritMatch already uses game enums / `GetString`.
