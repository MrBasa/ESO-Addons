# Audit remediation (watchlist)

Last refreshed: 2026-10-18 (offline code + catalog refresh).

## 1. Achievement and motif progression in chat

**Goal:** Chat-box (or chat-linked) notifications when achievement or motif knowledge advances.

### What the installed candidates actually do

| Add-on | Role vs goal |
|--------|----------------|
| **LootDrop** (Reborn) | **Best match on disk.** Overlay + optional **chat log** for achievement completed/progress; loot filters include **Style Loot**. Not a tracker UI. |
| **PithkaAchievementTracker** | Trial/dungeon **tracker UI** + `/tp` helpers. No chat progress notifier in `Options.lua` / `main.lua`. |
| **CharacterKnowledge** + **LibCharacterKnowledge** | Motif/recipe/research **browser + tooltips** (`/ck`, `/characterknowledge`, `/lckstyles`). Chat only for learn batch (`/cklearn` → “Items learned: N”) and welcome — **not** automatic motif-progress spam. |
| **LibMotif** | **Removed from disk** (still disabled in old `AddOnSettings` lines). Replaced on disk by ancient **LibMotifCategories** (API ~100027) — library only, no chat. |
| **CraftStoreFixedAndImproved** | Updates style knowledge on `EVENT_STYLE_LEARNED`; no chat progress line for motifs. |

### Enablement — LootDrop (recommended for chat)

1. Character AddOns menu: enable **LootDrop**, **LibAnimation-1.0**, **LibAddonMenu-2.0**, **LibMediaProvider** (manifest asks for `LibMediaProvider-1.0`; nested under `LibMediaProvider/PC/` — if LootDrop shows missing deps in-game, reinstall LootDrop / LibMediaProvider from Minion into the live AddOns path).
2. ESC → Settings → Add-Ons → **LootDrop**:
   - **Achievements** → enable **Achievements**, **Show Completed**, **Show Progress** (overlay).
   - **Chat Log Options** → enable **Log Completed Achievements** and **Log Achievement Progress**; set **Output Tab** (or General → chat tab + Set Tab). Ensure **Hide LootDrop Chat** is off.
   - **Style Loot** (loot section) → enable if you want style-page loot callouts (not the same as “motif chapter learned”, but closest installed loot/style signal).
3. Slash / keybinds: see `data/addon_summaries/LootDrop.txt` (`LOOTDROP_TOGGLE_ACHIEVEMENTS`, `LOOTDROP_TOGGLE_STYLE`, hide-chat toggle).
4. `/reloadui` after changes. Per-character `AddOnSettings`: LootDrop is **partial** (on for some toons, off for others) — enable on the characters that need chat.

### Enablement — CharacterKnowledge (tooltips / browser, not chat spam)

1. Enable **CharacterKnowledge** + standalone **LibCharacterKnowledge** (nested copies also ship inside the CK folder).
2. ESC → Settings → Add-Ons → **LibCharacterKnowledge** (`LCKSettings`) for character priority/tracking; CK panel for tooltip sections (motif chapters, characters).
3. `/ck` or `/characterknowledge` for browser; `/cklearn` / `/ckl` to learn learnable items (chat confirms count only).
4. For **automatic motif chat**, CK is insufficient — use LootDrop style/achievement chat or search ESOUI for a dedicated motif notifier.

### Pithka

Use for trifecta/score tracking only. Do not expect chat achievement lines from this add-on.

### ESOUI alternatives if still missing

Search ESOUI for achievement chat / “achievement progress” notifiers, and motif/style learn announcers. Confirm they use `EVENT_ACHIEVEMENT_*` / `EVENT_STYLE_LEARNED` + `CHAT_ROUTER` before installing.

---

## 2. In-bank collected totals and trader value (TTC / MM)

**Goal:** Collected-style totals including **bank**, with pricing from **Tamriel Trade Centre** and/or **Master Merchant**.

### What the installed candidates actually do

| Add-on | Role vs goal |
|--------|----------------|
| **IIfA** | Cross-bag inventory UI; tracks bank when you visit; location filter **All Storage** / **Everything** includes bank. **No built-in TTC/MM price column** in menu strings — ownership/counts/tooltips, not guild-trader valuation. Currency tooltip includes banked gold. |
| **TamrielTradeCentre** | Guild trader prices/tooltips; **requires desktop Client.exe** under `AddOns/TamrielTradeCentre/Client`. Price-to-chat / tooltip toggles in LAM. |
| **MasterMerchant** | Sales history + tooltip prices; deal calc can use TTC suggested/avg/sales. `/mm`, `/lgs`. |
| **LibPrice** | Library only (`mm` / `ttc` / `att` sources). Used by WritWorthy etc.; no UI. |

### Enablement — bank-inclusive inventory (IIfA)

1. Enable **IIfA** (+ **LibCustomMenu**, **LibAsync**, **LibAddonMenu-2.0**, **LibMediaProvider**).
2. Open bank once per character so IIfA indexes `BAG_BANK` / subscriber bank.
3. ESC → Settings → Add-Ons → **Inventory Insight**:
   - **Guild Bank Options** → **Guild Bank Data Collection** on if you want guild banks; open each guild bank once.
   - Scene toggles: **Bank scene** on so the IIfA frame appears while banking.
   - In the IIfA window filter dropdown: **All Storage** or **Everything** (strings: bank + characters + craft bag + chests; Everything adds houses).
4. Slash: `/ii`. `/reloadui` after setting changes.

### Enablement — trader value (TTC + MM)

1. **TTC desktop client (required):** run `…/live/AddOns/TamrielTradeCentre/Client/Client.exe` (Wine/Proton or native helper you already use) **before** launching ESO so price/lookup tables refresh. Docs: http://tamrieltradecentre.com/help/AddonAndClient  
   On this machine the live tree is `~/Games/ESO/live/AddOns/TamrielTradeCentre/Client/`.
2. ESC → Settings → Add-Ons → **Tamriel Trade Centre**: enable price tooltips; optional **Price to Chat** / history online buttons. Slash: `/ttc`.
3. ESC → Settings → Add-Ons → **Master Merchant**: enable tooltip/sales alerts as desired; pick **one** primary deal/tooltip price mode (MM avg vs TTC suggested/avg/sales) to reduce overlap. Slash: `/mm`.
4. Consumers of **LibPrice** (e.g. WritWorthy) pick up `mm`/`ttc` automatically when those add-ons are loaded — no LibPrice panel.
5. For **IIfA list valued in gold via TTC/MM**: not provided by stock IIfA settings found in code. Use TTC/MM tooltips on items, MM/TTC UIs, or an ESOUI add-on that adds price columns on top of LibPrice.

---

## 3. LibScanner runtime merge

**LibScanner** was deployed to live AddOns on 2026-10-18 via `scripts/deploy_steam_eso_addons.sh`.

After `/libscan` or `/libscanexport` in-game, copy `LibScannerSavedVars.lastExport` from `live/SavedVariables/LibScanner.lua` into `data/libscan_export.tsv` (or run `scripts/merge_libscan_tsv.py --savedvars <path>`). Then run `merge_libscan_tsv.py` to fill `out_of_date` and `missing_deps` on the catalog.

---

## 4. LootLogCustom deploy

Repo folder: `LootLogCustom/`. **`scripts/deploy_steam_eso_addons.sh` currently skips this folder** (see `SKIP_NAMES` in that script). When you want it live: remove `LootLogCustom` from `SKIP_NAMES`, run the deploy script, **disable** stock `LootLog` if present, verify **Loot Log (Custom)** in the add-on list, then remove or archive `LootLog_ILikeMoneyEdition_v02.zip` from `live/AddOns`. Alternatively copy `LootLogCustom/` into `live/AddOns` manually once.

---

## 5. Minion vs live AddOns (path audit)

See session summary / README. Source of truth: `~/Games/ESO/live/AddOns` (symlink target of Steam Proton `compatdata/306130/.../live`). Minion Flatpak `ESO-1` `addon-path` already points at the Steam path. Main sync issue: **Minion detection looks for `FolderName.txt`**, while **57 add-ons only ship `FolderName.addon`** — Minion still tracks most by UID after install, but re-scan logs “Toc not found” and omits folders it never registered (e.g. AwesomeGuildStore, BeamMeUp, … until reinstalled).

## 6. LibScanner unused libs (2026-10-18 in-game)

Runtime scan: **no broken required deps**, **no missing Lib\* optional-only folders**.

**Unused Lib\*** (not required by any enabled add-on’s `DependsOn`; may still be `OptionalDependsOn`):

| Lib | Manifest refs |
|-----|----------------|
| LibChatMenuButton | optional: BeamMeUp |
| LibCustomIcons | optional: CrutchAlerts, OdySupportIcons |
| LibFilteredChatPanel | optional: CrutchAlerts (also disabled in AddOnSettings #Default) |
| LibGroupBroadcast | optional: CrutchAlerts |
| LibMotifCategories | optional: AdvancedFilters |
| LibMsgWin-1.0 | optional: QuestMap |
| LibMultiAccountCollectibles | optional: LootLog |
| LibMultiAccountSets | optional: ItemBrowser, LootLog |
| LibRadialMenu | optional: DolgubonsLazyWritCreator, LootLog |
| LibRecipe | optional: LibLazyCrafting |
| LibServerResetTime | optional: LootLog |
| LibSlashCommander | optional: BeamMeUp, CharacterMarkdown, LibSets, LibZone, WritWorthy, pChat |
| LibUndauntedPledges | optional: ItemBrowser |
| LibVotansAddonList | **no manifest refs** — safest removal candidate if AddonSelector doesn’t need it |

Do **not** mass-delete optional libs if you use the listed parent features (AF motif filters, pChat slash UX, multi-account collectibles, etc.).

**Export note:** `/libscanexport` failed to persist TSV (`lastExport=nil`, ESO 2000-char SV limit). LibScanner was patched to chunk into `lastExportChunks`; redeployed — re-run `/libscanexport` + `/reloadui`, then `merge_libscan_tsv.py --savedvars …`.

