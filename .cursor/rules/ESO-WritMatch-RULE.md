## Purpose

[`WritMatch/`](../../WritMatch/) is an **Elder Scrolls Online (ESO)** add-on. It reconciles **sealed master writs** in the backpack with **player-crafted gear** already there, then updates LibLazyCrafting / WritWorthy / Lazy Writ so green checks and the craft queue match reality.

**ESO** means *Elder Scrolls Online*.

Target runtime: per [`WritMatch/WritMatch.txt`](../../WritMatch/WritMatch.txt) (`## APIVersion: 101050`). LuaLS libraries: prefix + FlatBadger ([`ESO-LuaAPI-RULE.md`](ESO-LuaAPI-RULE.md)).

Global repo layout and Lua stubs: [`ESO-Global-RULE.md`](ESO-Global-RULE.md), [`ESO-LuaAPI-RULE.md`](ESO-LuaAPI-RULE.md).

## Behaviour

- Slash and BasaTools panel: `/writmatch` applies; `/writmatch crafts` clears WritWorthy `queued` and **all craft-new** LLC jobs (smithing plus provisioning/alchemy/enchanting; keep improvement); `/writmatch queues` dumps every LLC job; `/writmatch orphans` cancels LLC jobs whose sealed-writ unique id is no longer in the backpack; `/writmatch kick` restarts improve. There is **no** hold/resume. Panel buttons call `WritMatch.Run("reconcile"|"crafts"|"queues"|"kick"|"orphans")`. `WritMatch.SetOutputSink(fn)` (BasaTools) also copies `Chat()` lines to the panel; chat is unchanged. Help uses `GetHelpEntries()` (intro + Action/Slash/Effect rows).
- Smithing only (blacksmith / clothier / woodworking / jewelry). Backpack only.
- Pairing is greedy 1:1. A match is same item id (via LLC `getItemLinkFromParticulars` at white quality), trait, and style. Quality is compared separately.
- **Complete** (`quality >= required`): write `WritCreater.savedVarsAccountWide.craftedMasterWrits[id] = true` and `WritWorthyInventoryList.SaveChariableState(id, "completed")`, then `cancelItemByReference` on WritWorthy, Lazy Writ Master, and WritMatch LLC.
- **Improve** (`quality < required`): `SaveChariableState(id, nil)` so login restore cannot re-enqueue craft-new, cancel by reference, then `ImproveSmithingItem` on the **WritMatch** LLC client only.
- **Unmatched:** list only. Do **not** dequeue WritWorthy `queued` rows or cancel LLC jobs for unmatched writs. Already-complete: re-mark complete and cancel leftover craft-new.
- `/writmatch crafts` walks **all** of `LibLazyCrafting.craftingQueue`. Craft-new includes `type == "smithing"` **and** jobs with no type (provisioning/alchemy/enchanting). Leave `improvement` / `deconstruct`. Daily Lazy Writ registers as `DolgubonsLazyWritCreator` and crafts `INDEX_NO_SET` / quality Normal (plain bows). Clearing that queue is not enough: `WritCreater.craftCheck` re-queues on `EVENT_CRAFTING_STATION_INTERACT` while `autoCraft` is true.
- Do not queue improve on WritWorthy/LWC LLC. WritWorthy `RestoreFromSavedChariables` re-calls `EnqueueLLC` (`CraftSmithingItemByLevel`) for every still-`queued` unique id.
- Do **not** call `AddRequestingAddon("WritWorthy")` or `AddRequestingAddon("DolgubonsLazyWritCreatorMaster")`. Use `GetRequestingAddon`.
- Unique ids are `Id64ToString(GetItemUniqueId(...))`.
- Station names in `/writmatch queues`: `GetString("SI_TRADESKILLTYPE", station)` (same pattern as CharacterKnowledge). Quality / trait chat uses `GetString("SI_ITEMQUALITY", …)` / `GetString("SI_ITEMTRAITTYPE", …)`. Walk LLC queues with `CRAFTING_TYPE_*` (not `for station = 1, 7`). “Not at a station” is `GetCraftingInteractionType() == CRAFTING_TYPE_INVALID`. Never invent a `1=blacksmith …` table.
- Chat: grouped, item links, want-string only on unmatched. No per-slot debug.

## Lessons

- Sealed writ parse follows Lazy Writ `ZO_LinkHandler_ParseLink`: template `[10]`, quality `[12]`, set index `[13]`, trait `[14]`, style `[15]`. LLC trait index is `traitType + 1`.
- `LibLazyCrafting.GetItemTemplateIdPatternIndex(id)` must be a **dot** call. A colon call passes `self` and looks up the wrong table.
- WritWorthy `RestoreFromSavedChariables` (on addon init) re-enqueues `CraftSmithingItemByLevel` for every `state == "queued"` unique id. Improving an item without clearing that saved state leaves a craft-new job that fires at the next station or login.
- Plain generic station crafts (no set) are almost always LWC **daily** writs (`WritCreater.LLCInteraction`), not leftover master writs. Master leftovers are set pieces.
- LLC will not improve past green (`ITEM_FUNCTIONAL_QUALITY_MAGIC`) unless the station's expertise passive is maxed (Rosin / Temper / Tannin / Plating). `isItemCraftable` still returns true, so that first job blocks the rest of the queue. Symptom: one improve, then stop. Chat: "Improvement skill is not at maximum."
- After `EVENT_CRAFT_COMPLETED`, LLC calls `CraftEarliest` while `ZO_CraftingUtils_IsPerformingCraftProcess()` is often still true. Smithing improve then no-ops (`LLC_NO_FURTHER_CRAFT_POSSIBLE`) and never schedules the next job. WritMatch re-kicks `craftInteract` after the lock clears (`/writmatch kick` at the table).
