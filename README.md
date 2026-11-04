# 🛠️ BasaTools

A small suite of helpers for [The Elder Scrolls Online](https://www.elderscrollsonline.com/) — aimed at crafters who juggle **master writs**, **materials**, and a busy **AddOns** folder.

Everything opens from one window. Type `/basatools` in chat (or tap the optional HUD icon) and pick a tab.

---

## 📦 What's included

| Add-on | What it does |
|--------|----------------|
| **BasaTools** | The shared window, Help buttons, and a **Tweaks** tab for inventory / HUD options |
| **WritMatch** | Matches sealed master writs to gear already in your backpack |
| **LibScanner** | Checks whether your enabled add-ons are missing libraries or look out of date |
| **MatLog** | Logs materials, survey loot, and master writs you gather |

Install all four together from the suite zip. Each folder is its own add-on — enable or disable them individually in **Settings → Add-Ons**.

---

## 🚀 Getting started

1. Download the latest **`BasaToolsSuite-v*.zip`** from [GitHub Releases](https://github.com/MrBasa/ESO-Addons/releases).
2. Use your addon manager, such as **Minion** or **ESO Addon Manager**, to install it into your `AddOns` folder (or extract the zip there yourself). You should end up with four folders: `BasaTools`, `WritMatch`, `LibScanner`, and `MatLog`.
3. In **Settings → Add-Ons**, enable those four plus the libraries below, then reload UI if asked.
4. Type **`/basatools`** in chat. (Optional: enable the HUD icon on the **Tweaks** tab.)

**Where is `AddOns`?**

| Platform | Typical location |
|----------|------------------|
| Windows | `Documents\Elder Scrolls Online\live\AddOns` |
| macOS | `~/Documents/Elder Scrolls Online/live/AddOns` |
| Linux (Steam) | `~/.steam/steam/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/AddOns` |

---

## 📚 Libraries you'll need

Use your addon manager, such as **Minion** or **ESO Addon Manager**, to install these from [ESOUI](https://www.esoui.com/) if you don't already have them:

| Library | Needed for | Required? |
|---------|------------|-----------|
| **LibLazyCrafting** | WritMatch | ✅ Yes |
| **LibDataEncode** | MatLog | ✅ Yes |
| **LibPrice** | Gold values in MatLog | Optional |
| **WritWorthy** | Gold-per-voucher overlay & Granny's Eel Pie tweak | Optional |
| **Dolgubon's Lazy Writ Crafter** | Better MatLog writ-coffer detection | Optional |
| **LibDebugLogger** | Structured debug logs | Optional |

BasaTools may note missing optionals in chat on first load. Official **Loot Log** remains the general loot journal; MatLog focuses on mats, surveys, and master writs.

---

## 🪟 BasaTools (the window)

BasaTools is the home for the other tools. Tabs appear only when that add-on is enabled; **Tweaks** is always there.

**Basics**

- Open / close with `/basatools` or the HUD icon.
- Drag the window; resize from the bottom-right corner.
- Settings (last tab, window size, HUD position, Tweaks options) are saved **for your account**, not per character.

### Tweaks tab

Three optional checkboxes:

| Option | What it does |
|--------|----------------|
| **Show gold per voucher…** | On sealed master writs in inventory, shows crafting-mat cost as gold per writ voucher (needs **WritWorthy**). Does not replace the sell-price column. |
| **Enable Granny's Eel Pie…** | Teaches **WritWorthy** about Granny's Eel Pie master writs so mat cost / g/v / auto-craft work correctly. |
| **Show a movable HUD icon…** | Places a small hammer icon on screen. Click to open BasaTools; drag to move it. |

---

## ⚒️ WritMatch

**For:** crafters with sealed master writs and finished (or nearly finished) gear already in the backpack.

WritMatch looks at sealed **smithing** master writs (blacksmith, clothier, woodworking, jewelry) in your **backpack** and pairs them with matching crafted gear. When something already meets the writ, it marks the writ complete in the usual crafting helpers and cleans up leftover craft jobs. When gear still needs improvement, it queues that improvement instead of crafting a duplicate.

Open the **WritMatch** tab (or use the slash commands below). Results show in the output pane and in chat.

| Button / command | What it does |
|------------------|--------------|
| **Match writs** · `/writmatch` | Pair writs with backpack gear: mark complete, queue leftover improves, list unmatched items. Does **not** cancel craft jobs for writs that still have no matching gear. |
| **Show LLC queue** · `/writmatch queues` | List every LibLazyCrafting job currently queued. |
| **Clear LLC queue** · `/writmatch crafts` | Clear “craft a new item” jobs and related WritWorthy queued flags. Keeps improvement jobs. |
| **Kick improve** · `/writmatch kick` | Restart improvement if the craft queue stalled — stand at a crafting station first. |
| **Drop orphan jobs** · `/writmatch orphans` | Cancel craft jobs whose sealed writ is no longer in your backpack. |

**Helpful tips**

- Only backpack gear counts (not bank / craft bag).
- If improvement runs once then stops, max the station’s expertise passive, then use **Kick improve** at the table.
- Press **Help** on the tab for the same guidance in-game.

---

## 🔍 LibScanner

**For:** anyone whose AddOns list has grown and who wonders “what’s broken or unused?”

LibScanner scans **enabled** add-ons and reports dependency / version status inside BasaTools.

1. Open the **LibScanner** tab (or type `/libscan` — `/scan` also works).
2. Click **Scan add-ons**.
3. Use the **Versions** and **Libraries** sub-views:

| View | What you'll see |
|------|-----------------|
| **Versions** | Enabled add-ons with whether they look up to date, plus author version info |
| **Libraries** | Missing / disabled dependencies, and a best-effort list of `Lib*` folders that may be unused |

| Button / command | What it does |
|------------------|--------------|
| **Scan add-ons** · `/libscan` | Run the scan and show results |
| **Export TSV** · `/libscanexport` | Same scan, also save a TSV snapshot in SavedVariables |
| `/libscandebug` | Toggle extra debug chat (off by default) |

**Helpful tips**

- Select text in the Libraries report to copy it — don't paste a huge report into chat (the client truncates).
- “Unused library” is a hint, not a guarantee it's safe to delete. When in doubt, leave it installed.
- Press **Help** on the tab for in-game guidance.

---

## 📋 MatLog

**For:** tracking what you gather — crafting mats, survey loot, and master writs — without treating it as a full loot journal.

MatLog records quietly in the background while **Enable** is checked. Open the **MatLog** tab in BasaTools to browse the log.

**What it tracks**

- World loot (materials / surveys / master writs as classified by the add-on)
- Daily-writ coffer contents (including auto-loot by Lazy Writ Crafter, when that add-on is present)
- Hireling mail (including “Take all” into the craft bag)

**What it does not track**

- Gold
- Vendor purchases
- Guild-store buys
- Ordinary player-to-player mail

**How to use the tab**

| Control | What it does |
|---------|----------------|
| **Enable** | Turn recording on or off. Existing rows stay until they age out. |
| **Summary** | Stack the same item across characters. Off = **Full** view (one row per item per character). |
| Day dropdown | Switch between the last few daily-reset days (kept for **three** days). |
| Character / Category | Filter the list; footer totals follow the filters. |
| Column headers | Click to sort; click again to reverse. |

Gold columns need **LibPrice**; without it, values stay blank. Category labels are **Writ** (quest), **Hireling** (mail), or **World** (loot).

Press **Help** on the tab for the full in-game explanation.

---

## 💬 Quick reference

| Open… | Type… |
|-------|--------|
| Main window | `/basatools` |
| WritMatch match | `/writmatch` |
| LibScanner | `/libscan` (or `/scan`) |
| MatLog | Use the MatLog tab in BasaTools |

---

## 🧑‍💻 Developing / packaging

Maintainer notes (version bumps, suite zip, GitHub Releases, local scripts, LuaLS) live in [docs/maintainer.md](docs/maintainer.md).

---

## License

MIT — see [LICENSE](LICENSE).
