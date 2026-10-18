# ESO add-on health audit

_Generated: 2026-10-18 19:14 UTC_

## Scan paths

- **AddOns:** `/home/mrbasa/Games/ESO/live/AddOns`
- **SavedVariables:** `/home/mrbasa/Games/ESO/live/SavedVariables`

- **Add-on roots discovered:** 145
- **Add-ons scanned (after disable filter):** 145
- **Names disabled in #Default (if settings file used):** 0

## 1. Missing required dependencies

Required = merged `## DependsOn` + `## PCDependsOn` tokens; each must match an existing add-on root folder name under AddOns.

- _(none)_

## 2. Missing optional `Lib*` dependencies

Only tokens from `## OptionalDependsOn` whose names start with **`Lib`** (expected add-on folder names). Other optional tokens (UI skins, data modules, non-library add-ons) are omitted here by design.

_Informational only — missing optional libraries are normal if you do not use that integration._

- **`LibCustomTitles`** not installed — optional for **`pChat`** (manifest `pChat/pChat.txt`)
- **`LibFeedback`** not installed — optional for **`DolgubonsLazyWritCreator`** (manifest `DolgubonsLazyWritCreator/DolgubonsLazyWritCreator.addon`)
- **`LibGroupSocket`** not installed — optional for **`RaidNotifier`** (manifest `RaidNotifier/RaidNotifier.txt`)
- **`LibStub`** not installed — optional for **`DolgubonsLazyWritCreator`** (manifest `DolgubonsLazyWritCreator/DolgubonsLazyWritCreator.addon`)
- **`LibStub`** not installed — optional for **`LibAddonMenu-2.0`** (manifest `LibAddonMenu-2.0/LibAddonMenu-2.0.addon`)
- **`LibStub`** not installed — optional for **`LibLazyCrafting`** (manifest `LibLazyCrafting/LibLazyCrafting.addon`)
- **`LibStub`** not installed — optional for **`LibMainMenu-2.0`** (manifest `LibMainMenu-2.0/LibMainMenu-2.0.addon`)
- **`LibStub`** not installed — optional for **`LibMsgWin-1.0`** (manifest `LibMsgWin-1.0/LibMsgWin-1.0.txt`)
- **`LibStub`** not installed — optional for **`RaidNotifier`** (manifest `RaidNotifier/RaidNotifier.txt`)

## 3. Orphaned / unused `Lib*` roots

_Lib folder names starting with `Lib` that never appear in any installed manifest `DependsOn`, `OptionalDependsOn`, or `PCDependsOn` line (all add-ons on disk; not filtered by AddOnSettings)._ Not proof-safe to delete.

- `LibScanner/`
- `LibVotansAddonList/`

## 4. Orphaned SavedVariables (heuristic)

`.lua` files in SavedVariables whose basename is not an add-on root folder name on disk. Files whose basename matches a `## SavedVariables:` table token from any manifest are skipped (reduces some false positives). **False positives** are still possible (renamed add-ons, nonstandard file names). Cross-check manifests before deleting.

- `/home/mrbasa/Games/ESO/live/SavedVariables/ZO_Ingame.lua`
- `/home/mrbasa/Games/ESO/live/SavedVariables/ZO_InternalIngame.lua`
- `/home/mrbasa/Games/ESO/live/SavedVariables/ZO_Pregame.lua`

## 5. Other artifacts (AddOns tree)

Top-level zip files and directories without a valid add-on manifest; plus `.DS_Store`, `Thumbs.db`, and `__MACOSX` under the tree.

- Directory without add-on manifest: `HarvestMapData/`
- Directory without add-on manifest: `LibCustomTitles/`
- Zip at top level: `LootLog_ILikeMoneyEdition_v02.zip`

## 6. Embedded nested `Lib*` (under top-level non-Lib add-ons)

Immediate subfolders named `Lib*` under a top-level add-on whose name does **not** start with `Lib`. `nested_addon_root` means a manifest exists at `LibX/LibX.txt` (or `.addon`). `standalone_duplicate` means an add-on root with the same folder name exists at top level (or elsewhere) under AddOns.

- `CharacterKnowledge/LibCharacterKnowledge` — nested add-on root, **standalone `Lib*` with same name exists**
- `CharacterKnowledge/LibExtendedJournal` — nested add-on root, **standalone `Lib*` with same name exists**
- `CombatAlerts/LibCombatAlerts` — nested add-on root, **standalone `Lib*` with same name exists**
- `DolgubonsLazyWritCreator/Libs` — files-only embed
- `HarvestMap/Libs` — files-only embed
- `ItemBrowser/LibExtendedJournal` — nested add-on root, **standalone `Lib*` with same name exists**
- `ItemBrowser/LibItemSets` — nested add-on root, **standalone `Lib*` with same name exists**
- `LootLog/LibExtendedJournal` — nested add-on root, **standalone `Lib*` with same name exists**
- `MasterMerchant/Libs` — files-only embed
- `SnapShot/LibOT` — nested add-on root, **standalone `Lib*` with same name exists**

## Additional findings

### Sample of `## SavedVariables:` table names (first 30)
- `ACACUC_CharacterKnowledge`
- `ACACUC_CombatAlerts`
- `ACACUC_CrutchAlerts`
- `ACACUC_ItemBrowser`
- `ACACUC_LootLog`
- `ADRSV`
- `AddonSelectorSavedVars`
- `AdvancedFilters_Settings`
- `ArmoryStyleManagerData`
- `AsyncSavedVars`
- `AwesomeGuildStore_Data`
- `BUI_REPORTS`
- `BUI_VARS`
- `BanditsCompanions_SavedVars`
- `BeamMeUp_SV`
- `CharacterKnowledgeSavedVariables`
- `CharacterMarkdownSettings`
- `CombatAlertsModules`
- `CombatAlertsSavedVariables`
- `CombatAlertsSettings`
- `CombatMetricsFightDataSV`
- `CombatMetrics_Save`
- `CraftStore_Account`
- `CraftStore_Character`
- `CrutchAlertsInstallationWide`
- `CrutchAlertsSavedVariables`
- `DolgubonsWritCrafterSavedVars`
- `Dustman_GlobalSavedVariables`
- `Dustman_Junk_GlobalSavedVariables`
- `Dustman_Junk_SavedVariables`

