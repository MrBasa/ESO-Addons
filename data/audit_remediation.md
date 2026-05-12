# Audit remediation (watchlist)

Fill `enablement_steps` in `addon_catalog.csv` or expand sections below as you verify in-game.

## 1. Achievement and motif progression in chat

**Goal:** Chat-box (or chat-linked) notifications when achievement or motif knowledge advances.

**Candidate add-ons to verify:** `PithkaAchievementTracker`, `CharacterKnowledge`, related libs (`LibCharacterKnowledge`, `LibMotif`). Check LAM panels and code signals for `CHAT_ROUTER`, achievement/motif events, and toggles that disable chat spam.

**Enablement (template):**

1. Supporting add-on(s): _TBD after in-game test_
2. Settings path: _ESC → Settings → Add-Ons → …_
3. Toggles: _enable chat / progress notifications; disable duplicate notifier if two add-ons conflict_
4. Slash commands: see `data/addon_summaries/<Addon>.txt` and `addon_code_signals.csv`
5. `/reloadui` after changing settings

---

## 2. In-bank collected totals and trader value (TTC / MM)

**Goal:** Collected-style totals including **bank**, with pricing from **Tamriel Trade Centre** and/or **Master Merchant**.

**Candidate add-ons:** `IIfA`, `TamrielTradeCentre`, `MasterMerchant`, `LibPrice`. Confirm bank scan and price source in settings; resolve conflicts if two add-ons own the same tooltip column.

**Enablement (template):**

1. Ensure TTC client / price data and MM sales data are current
2. In IIfA (and related): enable bank inclusion and preferred price source
3. See `addon_code_signals.csv` for slash commands (rescan / refresh if any)

---

## 3. LibScanner runtime merge

After `/libscan` or `/libscanexport` in-game, copy `LibScannerSavedVars.lastExport` from `live/SavedVariables/LibScanner.lua` into `data/libscan_export.tsv` (or run `scripts/merge_libscan_tsv.py --savedvars <path>`). Then run `merge_libscan_tsv.py` to fill `out_of_date` and `missing_deps` on the catalog.

---

## 4. LootLogCustom deploy

Repo folder: `LootLogCustom/`. **`scripts/deploy_steam_eso_addons.sh` currently skips this folder** (see `SKIP_NAMES` in that script). When you want it live: remove `LootLogCustom` from `SKIP_NAMES`, run the deploy script, **disable** stock `LootLog` if present, verify **Loot Log (Custom)** in the add-on list, then remove or archive `LootLog_ILikeMoneyEdition_v02.zip` from `live/AddOns`. Alternatively copy `LootLogCustom/` into `live/AddOns` manually once.
