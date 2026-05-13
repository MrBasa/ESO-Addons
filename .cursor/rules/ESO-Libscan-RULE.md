## Purpose

[`LibScanner/`](../../LibScanner/) is an **Elder Scrolls Online (ESO)** add-on. It scans **enabled** add-ons’ declared **`DependsOn`**, **`OptionalDependsOn`**, and (when manifests are readable) **`PCDependsOn`** tokens from each add-on’s manifest (`.txt` / `.addon` / `manifest.txt` under `GetAddOnRootDirectoryPath`), with an **AddOnManager API fallback** when **no** manifest read succeeds. It summarizes:

- **Broken dependencies** — missing on disk, **disabled** in the UI, or **below manifest minimum version** (from `GetAddOnDependencyInfo`; each line includes the reason; **missing** entries that are only **optional** are omitted when **`OptionalDependsOn`** was parsed into the per–add-on optional set).
- **`Lib*` install folders** split into **optional-only (manifest)** vs **unused** — heuristics; see below. When manifests cannot be read, the **Libraries** report shows a **WARNING** and the optional-only list is **not classified**; **Unused** may include libraries that are only declared in **`OptionalDependsOn`** in real manifests.

**ESO** means *Elder Scrolls Online*.

Target runtime: **Elder Scrolls Online Update 49.0**, per [`LibScanner/LibScanner.txt`](../../LibScanner/LibScanner.txt) (`## APIVersion: 101049`; current add-on version in `## Version:` there).

Global repo layout, Lua stubs, and UESP vs manifest API versions: [`ESO-Global-RULE.md`](ESO-Global-RULE.md), [`ESO-LuaAPI-RULE.md`](ESO-LuaAPI-RULE.md).

---

## Lessons learned (LibScanner / ESO UI + add-on manager)

### Manifest and load order

- ESO loads manifests as **`AddOnFolder/AddOnFolder.txt`**. Wrong filename ⇒ add-on **never loads** (no AddOns menu, slash commands missing).
- **`OnInitialized` in XML** runs while **XML is applied**, often **before** the add-on’s **`.lua` file** has executed ⇒ **globals from Lua are still `nil`**. Do not call Lua init functions from XML `OnInitialized` unless you defer (e.g. `EVENT_ADD_ON_LOADED` / `Initialize()` only).

### Add-on manager API (trust live patterns over a wrong stub)

- Use **`local addOnManager = GetAddOnManager()`** and **`:Method(...)`** — this matches widely used add-ons (e.g. LibDebugLogger, WritWorthy).
- **`GetAddOnInfo(i)`** on live clients matches the **six-return** pattern:  
  `name, title, author, description, enabled, state`  
  where **`state`** is **`ADDON_STATE_*`**. Treat **`state == ADDON_STATE_VERSION_MISMATCH`** as out-of-date for UI purposes.
- **Do not** read a fictional **7th** return as `isLibrary` / `isOutOfDate` unless verified; mis-unpacking makes **`state`** look like a boolean and **marks every add-on as a “library”**, breaking “unused” logic completely.
- **`GetAddOnDependencyInfo(i, j)`** on live commonly returns **six** values:  
  `dependencyName, dependencyExists, dependencyActive, dependencyMinVersion, dependencyVersion, isLibrary`  
  The sixth is **`isLibrary`** (per ESOUI `ESOUIDocumentation.txt`), **not** “optional vs required.” **`GetAddOnNumDependencies`** enumerates **required** manifest dependencies only—optional **`OptionalDependsOn`** entries do **not** appear in that list (verified vs pChat / LootLog / ItemBrowser on live). Use **`dependencyActive == false`** to surface **disabled** libs (e.g. LibCSA disabled while RaidNotifier is enabled)—**`exists` alone is not enough**.
- **Manifest reads in add-on Lua:** standard Lua **`io` is `nil`** in the ESO client; LibScanner’s manifest parser therefore sees **zero successful reads** on live. Do not use **`local empty = "", "", false; return empty`** in Lua 5.1—only the first value is bound; always **`return "", "", false`** (or equivalent) so callers receive **three** returns (`readOk` must not be lost).

### What “library” means in LibScanner

- **Installed catalog:** folder **`name`** matching **`^Lib`** (case-insensitive). ESO’s manifest `## IsLibrary` is not exposed reliably via the 6-tuple `GetAddOnInfo` pattern above; do not depend on a misaligned “`isLibrary`” slot.
- **Lib* optional-only (manifest) list:** installed `Lib*` named in **`## OptionalDependsOn`** of at least one **enabled** add-on, and **not** named in **`## DependsOn`** of any enabled add-on (manifest tokens, same parsing as game folder names). When **no** manifest reads succeed, the UI shows **“Not classified.”** instead of implying there are zero optional-only libs.
- **Unused `Lib*` list:** installed `Lib*` not appearing in **`DependsOn`** or **`OptionalDependsOn`** of any **enabled** add-on **when manifests were read**. If **no** manifest could be read, LibScanner merges **`GetAddOnDependencyInfo`** names into the **required** bucket only and prints a **WARNING** at the top of the Libraries report: **optional-only libraries may be misclassified as unused**; do not treat the list as “safe to delete” without checking each consumer’s manifest on disk.

### Libraries panel: variable-length scrollable text (do **not** use `TextBuffer` + chat slider here)

**What went wrong in practice:** `ZO_TextBuffer` is **chat-log semantics** (line stacking, scroll origin, and **`maxHistoryLines` eviction of oldest lines**), not a document view. Pairing it with a hand-rolled **CombatMetrics-style `Slider`** is fragile: easy to show the wrong end of the log, clip headers when the line cap is exceeded, or scramble section order when trying to “fix” stacking by reversing `AddMessage`. A plain **multiline `EditBox`** filling the frame often **does not get a working scrollbar** unless it lives under a **`ZO_ScrollContainer`** template — so long reports look “truncated” with no thumb.

**What works (LibScanner as implemented):** treat the Libraries report like **LeadList** / **Versions tab** data: **`ZO_ScrollList`** on **`LibScannerWindowLibsPanelOutputList`**, one **virtual row** per report line (`LibScannerLibReportRow` with a `Line` **`Label`**), **`ZO_ScrollList_AddDataType`**, **`ZO_ScrollList_CreateDataEntry`**, **`ZO_ScrollList_Commit`**, row **`SetColor(r,g,b,1)`** in the setup callback. After each full rebuild call **`ZO_ScrollList_ResetToTop(list)`** so the **Broken dependencies** block stays at the **top**; re-run reset when the Libraries panel is **`OnEffectivelyShown`** if layout was wrong while hidden.

**Reference add-on on disk:** LeadList — `leadlist.xml` (`inherits="ZO_ScrollList"`) and `leadlist.lua` (`ZO_ScrollList_AddDataType`, row setup). Same pattern as LibScanner’s Versions list.

**When `TextBuffer` is still appropriate:** read-only logs where **chat-style** behavior is intended and scroll math is tested against a known-good reference (e.g. CombatMetrics); keep **`maxHistoryLines`** safely above worst-case line counts if you must use it.

### `EditBox` for plain text (non-scroll-list)

- **`EditBox:SetText`** applies **ZO rich-text rules**: `|c…|r`, **`/c…`**, **`[...]`**-like segments, and **truncation** at surprising lengths. Sanitize or use **`TextBuffer` / `Label`** for untrusted strings.
- Strip **`|c` / `|r`** (or use **`AddMessage` RGB**) when the target control parses pipe markup.

### Copy dependency lists to clipboard (avoid truncation)

- **Primary path:** **`ZO_GetChatSystem():StartTextEntry(body, nil, nil, true)`** when **`IsChatSystemAvailableForCurrentPlatform()`** — users look at the **chat input line** for Ctrl+C.
- **Caveat:** the client may **trim** very long `StartTextEntry` payloads; do **not** paste the whole Libraries prose report into chat. Prefer **one button per category** (broken / optional-only `Lib*` / unused `Lib*`) that copies only a **comma-separated list of folder names** for that bucket (short single line).
- **Stale data:** clear **`latestBrokenDeps` / `latestOptionalLibs` / `latestUnusedLibs`** at the start of each scan so buttons do not show a previous run after a failed scan.

### GuiXml / `Button` controls

- **`Scripts` / `OnClick` wrappers** are often **invalid** on `Button` controls; use **`OnClicked`** (and avoid `OnInitialized` blocks that call non-existent label APIs).

### Debug noise vs shipping UX

- Gate verbose **`LibScanner:`** / API-probe lines behind a **SavedVar** (e.g. `showDebug`) and a slash toggle (**`/libscandebug`**), default **off**. Chat **`d()`** can be gated the same way so normal scans stay quiet.

### Heuristic limits (document for users)

- **Unused `Lib*` list** is reliable only when manifests were read; otherwise treat it as **API-only** (required deps) and see the **WARNING** in the Libraries report. It is never a full “safe to delete” guarantee (implicit Lua loads, character-specific enables, wrong manifests in upstream add-ons).
- **Lib* optional-only (manifest) list:** those entries are still optional integrations; add-ons may use other implicit loads not reflected in the manifest.
- **Broken dependencies** only inspect **enabled** add-ons (checkbox), matching the scan’s scope.

---

## Key APIs used in [`LibScanner/LibScanner.lua`](../../LibScanner/LibScanner.lua)

- `GetAddOnManager()` then **`addOnManager:GetNumAddOns`**, **`GetAddOnInfo`**, **`GetAddOnVersion`**, **`GetAddOnNumDependencies`**, **`GetAddOnDependencyInfo`**, **`GetAddOnRootDirectoryPath`** (manifest paths)
- **`io.open`** (when **`io`** exists) to read **`## DependsOn`** / **`## OptionalDependsOn`** / **`## PCDependsOn`** from `AddOnFolder.txt` / `AddOnFolder.addon` / `manifest.txt` under the root path. On standard **live** clients **`io` is `nil`**, so manifest lines are not read and the UI relies on the AddOnManager fallback plus the **WARNING** block in the Libraries report.
- `EVENT_MANAGER:*` for `EVENT_ADD_ON_LOADED`
- `SLASH_COMMANDS["/libscan"]`, **`/scan`** alias, **`/libscanexport`**, **`/libscandebug`**
- Scroll list: `ZO_ScrollList_*` for the **Versions** tab and the **Libraries** report list (`OutputList`)
- Copy: `ZO_GetChatSystem():StartTextEntry` for **per-category comma lists** (broken / optional / unused globals)

---

## Notes for code changes

- Follow **linting** in [`ESO-Global-RULE.md`](ESO-Global-RULE.md) on touched Lua/XML.
- When changing add-on manager usage, **verify against an installed reference add-on** under the user’s `.../Documents/Elder Scrolls Online/live/AddOns/` tree or ESOUI wiki—**not** a stub line count alone ([`ESO-LuaAPI-RULE.md`](ESO-LuaAPI-RULE.md)).
- Strip **`|c` / `|r`** from strings bound for **`EditBox`**; for **`TextBuffer`** / colored **`Label`** rows, prefer **RGB** (`AddMessage` / `SetColor`) instead of embedding pipe color codes in the string.
