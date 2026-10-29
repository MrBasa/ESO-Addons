local ADDON_NAME = "BasaTools"
local RETENTION_DAYS = 3
local DAY_LENGTH = 86400
local EVENT_PREFIX = ADDON_NAME .. "MatLog"

BasaTools = BasaTools or {}
BasaTools.MatLog = BasaTools.MatLog or {}

local MatLog = BasaTools.MatLog
local saved = nil
local listenersOn = false
local listTypesReady = false
local panelBound = false
local showingHelp = false
local selectedDayKey = nil
local selectedChar = "all"
local selectedCategory = "all"
local sortKey = "item"
local sortAsc = true
local SORT_KEYS = {
    item = true,
    qty = true,
    category = true,
    character = true,
    value = true,
}
local RefreshFilterCombos
local RefreshHeaders
local sortHeaderGroup = nil
local mailSnapshots = {}
local backpackMailCounts = {}
local mailBagBaselineReady = false
local mailDiffToken = 0
local mailDiffAfterClose = false
local mailApiHooked = false
local inboxHasHireling = false
local sawHirelingThisMailbox = false
local mailCreditPending = false
local takeAllInProgress = false
local mailDiffRetries = 0
local lastMailHireling = false
local MAIL_DIFF_MAX_RETRIES = 6
local backpackWritCounts = {}
local writBagBaselineReady = false
local NoteWritBagGain
local boundPanel = nil
local mailboxOpen = false
local lastInvAddMs = 0
local boundChecks = {}
local pendingWrit = nil
local trackedWritNames = {}
local writBoxFlavor = nil
local writBoxNames = nil
local recentWritCredit = {}
local lastBoxScanMs = 0
local lastBoxScanHit = false
local lootingWritBox = false
local worldLootUntilMs = 0
local WORLD_LOOT_GRACE_MS = 2500
-- LWC waits until the NPC interact camera ends, then delays UseItem
-- (containerDelay + 1s + latency). Ten seconds is not enough.
local WRIT_LOOT_WINDOW_S = 90
local WRIT_BOX_DRAIN_S = 5
local WRIT_CREDIT_DEDUPE_MS = 3000
local BOX_SCAN_CACHE_MS = 500

-- Flavor-text samples from Lazy Writ Crafter (same flavour on all ranks / locales).
local WRIT_BOX_FLAVOR_LINKS = {
    "|H1:item:121302:175:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h",
    "|H1:item:138816:3:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h",
    "|H1:item:147603:3:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h",
    "|H1:item:142175:3:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h",
    "|H1:item:58519:175:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h",
    "|H1:item:59714:175:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h",
    "|H1:item:58528:175:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h",
    "|H1:item:57851:175:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h",
    "|H1:item:58510:175:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h",
}

local SUPPRESS_INTERACTION = {}
do
    local keys = {
        INTERACTION_STORE,
        INTERACTION_VENDOR,
        INTERACTION_BANK,
        INTERACTION_GUILDBANK,
        INTERACTION_TRADINGHOUSE,
        INTERACTION_CRAFT,
        INTERACTION_STABLE,
        INTERACTION_ARMORY,
        INTERACTION_RETRAIT,
    }
    for i = 1, #keys do
        if type(keys[i]) == "number" then
            SUPPRESS_INTERACTION[keys[i]] = true
        end
    end
end

local MATERIAL_TYPES = {
    [ITEMTYPE_BLACKSMITHING_RAW_MATERIAL] = true,
    [ITEMTYPE_BLACKSMITHING_MATERIAL] = true,
    [ITEMTYPE_BLACKSMITHING_BOOSTER] = true,
    [ITEMTYPE_CLOTHIER_RAW_MATERIAL] = true,
    [ITEMTYPE_CLOTHIER_MATERIAL] = true,
    [ITEMTYPE_CLOTHIER_BOOSTER] = true,
    [ITEMTYPE_WOODWORKING_RAW_MATERIAL] = true,
    [ITEMTYPE_WOODWORKING_MATERIAL] = true,
    [ITEMTYPE_WOODWORKING_BOOSTER] = true,
    [ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL] = true,
    [ITEMTYPE_JEWELRYCRAFTING_MATERIAL] = true,
    [ITEMTYPE_JEWELRYCRAFTING_BOOSTER] = true,
    [ITEMTYPE_JEWELRY_RAW_TRAIT] = true,
    [ITEMTYPE_JEWELRY_TRAIT] = true,
    [ITEMTYPE_ARMOR_TRAIT] = true,
    [ITEMTYPE_WEAPON_TRAIT] = true,
    [ITEMTYPE_STYLE_MATERIAL] = true,
    [ITEMTYPE_RAW_MATERIAL] = true,
    [ITEMTYPE_ENCHANTING_RUNE_ASPECT] = true,
    [ITEMTYPE_ENCHANTING_RUNE_ESSENCE] = true,
    [ITEMTYPE_ENCHANTING_RUNE_POTENCY] = true,
    [ITEMTYPE_ENCHANTMENT_BOOSTER] = true,
    [ITEMTYPE_INGREDIENT] = true,
    [ITEMTYPE_FLAVORING] = true,
    [ITEMTYPE_SPICE] = true,
    [ITEMTYPE_REAGENT] = true,
    [ITEMTYPE_POTION_BASE] = true,
    [ITEMTYPE_POISON_BASE] = true,
    [ITEMTYPE_FURNISHING_MATERIAL] = true,
}

local HIRELING_SUBJECTS = {
    ["Raw Enchanter Materials"] = true,
    ["Raw Clothier Materials"] = true,
    ["Raw Blacksmith Materials"] = true,
    ["Raw Woodworker Materials"] = true,
    ["Raw Provisioner Materials"] = true,
    ["Raw Jewelry Crafter Materials"] = true,
    ["Raw Jewelry Materials"] = true,
    ["Schreinermaterial"] = true,
    ["Versorgerzutaten"] = true,
    ["Schneidermaterial"] = true,
    ["Verzauberermaterial"] = true,
    ["Schmiedematerial"] = true,
    ["Schmuckhandwerkmaterial"] = true,
    ["Schmuckmaterial"] = true,
    ["Matériaux bruts d'enchantement"] = true,
    ["Matériaux bruts de forge"] = true,
    ["Matériaux bruts de travail du bois"] = true,
    ["Matériaux bruts de couture"] = true,
    ["Matériaux bruts de cuisine"] = true,
    ["Matériaux bruts de joaillerie"] = true,
    ["Matériaux bruts de bijoutier"] = true,
    ["Materiales de encantamiento no refinados"] = true,
    ["Materiales de sastrería no refinados"] = true,
    ["Materiales de herrería no refinados"] = true,
    ["Materiales de carpintería no refinados"] = true,
    ["Materiales de cocina crudos"] = true,
    ["Materiales de joyería no refinados"] = true,
}

local COL_HEADER = { 0.93, 0.86, 0.55 }
local COL_MUTED = { 0.7, 0.7, 0.65 }
local COL_MAT = { 0.55, 0.82, 0.98 }
local COL_SURVEY = { 0.35, 0.85, 0.35 }
local COL_WRIT = { 0.93, 0.86, 0.55 }
-- Inventory VALUE column: stack total (gold) and unit (blue).
local COL_GOLD_TOTAL = { 0.91, 0.80, 0.22 }
local COL_GOLD_UNIT = { 0.29, 0.61, 1.0 }

local KIND_LABEL = {
    material = "Material",
    survey = "Survey",
    writ = "Writ",
}

local SOURCE_HIRELING = "hireling"
local SOURCE_WRIT = "writ"
local SOURCE_WORLD = "world"

local SOURCE_LABEL = {
    hireling = "Hireling",
    writ = "Writ",
    world = "World",
}

local function Child(parent, name)
    if BasaTools.Child then
        return BasaTools.Child(parent, name)
    end
    if parent and parent.GetNamedChild then
        return parent:GetNamedChild(name)
    end
    return nil
end

local function GetPanel()
    if boundPanel then
        return boundPanel
    end
    local win = BasaTools.GetWindow and BasaTools.GetWindow()
    return Child(win, "PanelMatLog")
end

local function LogTable()
    if not saved then
        return nil
    end
    if type(saved.matlog) ~= "table" then
        saved.matlog = {}
    end
    return saved.matlog
end

local function GetAnchorTime()
    local offset = 0
    if TIMED_ACTIVITIES_MANAGER and TIMED_ACTIVITIES_MANAGER.GetTimedActivityTypeTimeRemainingSeconds then
        offset = TIMED_ACTIVITIES_MANAGER:GetTimedActivityTypeTimeRemainingSeconds(TIMED_ACTIVITY_TYPE_WEEKLY) or 0
    end
    if offset == 0 and type(GetTimeUntilNextDailyLoginRewardClaimS) == "function" then
        offset = GetTimeUntilNextDailyLoginRewardClaimS() or 0
    end
    return zo_round((GetTimeStamp() + offset) / 120) * 120
end

local function PreviousResetTime()
    local intervals = zo_floor((GetTimeStamp() - GetAnchorTime()) / DAY_LENGTH)
    return GetAnchorTime() + intervals * DAY_LENGTH
end

local function CurrentDayKey()
    return tostring(PreviousResetTime())
end

local function FormatDayKey(dayKey)
    local ts = tonumber(dayKey)
    if not ts then
        return tostring(dayKey or "")
    end
    if dayKey == CurrentDayKey() then
        if type(GetDateStringFromTimestamp) == "function" then
            return "Today (" .. GetDateStringFromTimestamp(ts) .. ")"
        end
        return "Today"
    end
    if type(GetDateStringFromTimestamp) == "function" then
        return GetDateStringFromTimestamp(ts)
    end
    return tostring(dayKey)
end

local function CharName()
    if type(GetUnitName) == "function" then
        local name = GetUnitName("player")
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    return "Unknown"
end

local function MailKey(mailId)
    if type(Id64ToString) == "function" then
        return Id64ToString(mailId)
    end
    return tostring(mailId)
end

local function ItemBaseKey(link, name)
    if type(link) == "string" and link ~= "" and type(GetItemLinkItemId) == "function" then
        local itemId = GetItemLinkItemId(link)
        if itemId and itemId ~= 0 then
            return "id:" .. tostring(itemId)
        end
        return link
    end
    return "name:" .. tostring(name or "?")
end

local function NormalizeSource(source)
    if source == SOURCE_WRIT or source == SOURCE_HIRELING or source == SOURCE_WORLD then
        return source
    end
    return SOURCE_HIRELING
end

local function ItemKey(link, name, source)
    return NormalizeSource(source) .. ":" .. ItemBaseKey(link, name)
end

local function SanitizeItemName(name)
    if type(name) ~= "string" or name == "" then
        return name
    end
    local formatted
    if SI_TOOLTIP_ITEM_NAME then
        if type(ZO_CachedStrFormat) == "function" then
            formatted = ZO_CachedStrFormat(SI_TOOLTIP_ITEM_NAME, name)
        elseif type(zo_strformat) == "function" then
            formatted = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
        end
    elseif type(zo_strformat) == "function" then
        formatted = zo_strformat("<<C:1>>", name)
    end
    if type(formatted) == "string" and formatted ~= "" then
        return formatted
    end
    return string.gsub(name, "%^[A-Za-z]+", "")
end

local function ItemName(link, fallback)
    local name
    if type(link) == "string" and link ~= "" and type(GetItemLinkName) == "function" then
        name = GetItemLinkName(link)
    end
    if type(name) ~= "string" or name == "" then
        name = fallback
    end
    name = SanitizeItemName(name)
    if type(name) == "string" and name ~= "" then
        return name
    end
    return "Item"
end

local function PriceGold(link)
    if type(link) ~= "string" or link == "" then
        return nil
    end
    local lib = rawget(_G, "LibPrice")
    if type(lib) ~= "table" or type(lib.ItemLinkToPriceGold) ~= "function" then
        return nil
    end
    local source = (saved and saved.matlogPriceSource) or "npc"
    local gold = lib.ItemLinkToPriceGold(link, source)
    if type(gold) ~= "number" then
        gold = lib.ItemLinkToPriceGold(link)
    end
    if type(gold) == "number" then
        return gold
    end
    return nil
end

local function FormatGold(amount)
    if type(amount) ~= "number" then
        return ""
    end
    local n = zo_round(amount)
    local num = tostring(n)
    if type(ZO_CommaDelimitNumber) == "function" then
        num = ZO_CommaDelimitNumber(n)
    end
    return num .. " |t16:16:EsoUI/Art/currency/currency_gold.dds|t"
end

local function HexRGB(rgb)
    local function byte(v)
        local n = zo_round((v or 0) * 255)
        if n < 0 then
            n = 0
        elseif n > 255 then
            n = 255
        end
        return n
    end
    return string.format("%02X%02X%02X", byte(rgb[1]), byte(rgb[2]), byte(rgb[3]))
end

local function ColorGoldText(text, rgb)
    if type(text) ~= "string" or text == "" then
        return ""
    end
    local num, icon = string.match(text, "^([^|]+)(|t.*)$")
    local hex = HexRGB(rgb)
    if num and icon then
        return "|c" .. hex .. num .. "|r" .. icon
    end
    return "|c" .. hex .. text .. "|r"
end

local function LooksLikeSurveyName(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    return string.find(string.lower(name), "survey", 1, true) ~= nil
end

local function LooksLikeMasterWritName(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    local lower = string.lower(name)
    if string.find(lower, "master writ", 1, true) then
        return true
    end
    return string.find(lower, "sealed", 1, true) ~= nil and string.find(lower, "writ", 1, true) ~= nil
end

local function ClassifyFromTypes(itemType, specializedType, name)
    if itemType == ITEMTYPE_MASTER_WRIT or specializedType == SPECIALIZED_ITEMTYPE_MASTER_WRIT then
        return "writ"
    end
    if specializedType == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT then
        return "survey"
    end
    if LooksLikeSurveyName(name) then
        return "survey"
    end
    if LooksLikeMasterWritName(name) then
        return "writ"
    end
    if MATERIAL_TYPES[itemType] then
        return "material"
    end
    return nil
end

local function ClassifyLink(link, name)
    if (not name or name == "") and type(link) == "string" and link ~= "" and type(GetItemLinkName) == "function" then
        name = GetItemLinkName(link)
    end
    if type(link) ~= "string" or link == "" then
        if LooksLikeSurveyName(name) then
            return "survey"
        end
        if LooksLikeMasterWritName(name) then
            return "writ"
        end
        return nil
    end
    local itemType, specializedType = GetItemLinkItemType(link)
    if type(GetItemLinkSpecializedItemType) == "function" then
        local extra = GetItemLinkSpecializedItemType(link)
        if type(extra) == "number" and extra ~= 0 then
            specializedType = extra
        end
    end
    return ClassifyFromTypes(itemType, specializedType, name)
end

local function ClassifySlot(bagId, slotIndex)
    local itemType, specializedType
    if type(GetItemType) == "function" then
        itemType, specializedType = GetItemType(bagId, slotIndex)
    end
    local link = nil
    if type(GetItemLink) == "function" then
        link = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
    end
    local name = ItemName(link)
    local kind = ClassifyFromTypes(itemType, specializedType, name)
    if kind then
        return kind, link
    end
    return ClassifyLink(link, name), link
end

local function EnsureWritBoxLookups()
    if writBoxFlavor then
        return
    end
    local flavors = {}
    local names = {}
    if type(GetItemLinkFlavorText) == "function" then
        for i = 1, #WRIT_BOX_FLAVOR_LINKS do
            local link = WRIT_BOX_FLAVOR_LINKS[i]
            local flavor = GetItemLinkFlavorText(link)
            if type(flavor) == "string" and flavor ~= "" then
                flavors[flavor] = true
            end
            if type(GetItemLinkName) == "function" then
                local boxName = GetItemLinkName(link)
                if type(boxName) == "string" and boxName ~= "" then
                    names[boxName] = true
                end
            end
        end
    end
    if next(flavors) then
        writBoxFlavor = flavors
        writBoxNames = names
    end
end

local function LwcBoxCraftType(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    local wc = _G["WritCreater"]
    if type(wc) ~= "table" or type(wc.boxNames) ~= "table" then
        return nil
    end
    local info = wc.boxNames[name]
    if type(info) == "table" then
        return info[2]
    end
    return nil
end

local function IsWritRewardBoxName(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    local craft = LwcBoxCraftType(name)
    if type(craft) == "number" then
        return craft > 0
    end
    EnsureWritBoxLookups()
    return writBoxNames and writBoxNames[name] == true
end

local function IsWritRewardContainerLink(link)
    if type(link) ~= "string" or link == "" then
        return false
    end
    local itemType = GetItemLinkItemType(link)
    if itemType ~= ITEMTYPE_CONTAINER and itemType ~= ITEMTYPE_CONTAINER_STACKABLE then
        return false
    end
    if type(GetItemLinkSpecializedItemType) == "function"
        and GetItemLinkSpecializedItemType(link) == SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE
    then
        return false
    end
    EnsureWritBoxLookups()
    if type(GetItemLinkFlavorText) == "function" and writBoxFlavor then
        local flavor = GetItemLinkFlavorText(link)
        if type(flavor) == "string" and writBoxFlavor[flavor] then
            return true
        end
    end
    return IsWritRewardBoxName(GetItemLinkName(link))
end

local function SlotIsWritRewardBox(bagId, slotIndex)
    if type(GetItemType) ~= "function" then
        return false
    end
    local itemType = GetItemType(bagId, slotIndex)
    if itemType ~= ITEMTYPE_CONTAINER and itemType ~= ITEMTYPE_CONTAINER_STACKABLE then
        return false
    end
    if type(GetItemLink) ~= "function" then
        return false
    end
    return IsWritRewardContainerLink(GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT))
end

local function KindColor(kind)
    if kind == "survey" then
        return COL_SURVEY
    end
    if kind == "writ" then
        return COL_WRIT
    end
    return COL_MAT
end

local function SourceColor(source)
    if source == SOURCE_WRIT then
        return COL_WRIT
    end
    if source == SOURCE_WORLD then
        return COL_SURVEY
    end
    return COL_MAT
end

local function StoredBaseKey(key)
    if type(key) ~= "string" then
        return tostring(key or "")
    end
    local prefix, rest = string.match(key, "^([^:]+):(.*)$")
    if rest and (prefix == SOURCE_WRIT or prefix == SOURCE_HIRELING or prefix == SOURCE_WORLD) then
        return rest
    end
    return key
end

local function MigrateLogSources()
    local log = LogTable()
    if not log then
        return
    end
    for _, day in pairs(log) do
        if type(day) == "table" then
            for charName, bucket in pairs(day) do
                if type(bucket) == "table" then
                    local moved = {}
                    for key, row in pairs(bucket) do
                        if type(row) == "table" then
                            local source = NormalizeSource(row.source)
                            row.source = source
                            local newKey = source .. ":" .. StoredBaseKey(key)
                            moved[newKey] = row
                        end
                    end
                    day[charName] = moved
                end
            end
        end
    end
end

local function EnsureCharBucket(dayKey, charName)
    local log = LogTable()
    if not log then
        return nil
    end
    if type(log[dayKey]) ~= "table" then
        log[dayKey] = {}
    end
    local day = log[dayKey]
    if type(day[charName]) ~= "table" then
        day[charName] = {}
    end
    return day[charName]
end

local function NowMs()
    if type(GetFrameTimeMilliseconds) == "function" then
        return GetFrameTimeMilliseconds()
    end
    return 0
end

local function AddItem(link, count, name, source, kind)
    if type(count) ~= "number" or count == 0 then
        return false
    end
    kind = kind or ClassifyLink(link, name)
    if not kind then
        return false
    end
    source = NormalizeSource(source)
    local bucket = EnsureCharBucket(CurrentDayKey(), CharName())
    if not bucket then
        return false
    end
    local displayName = ItemName(link, name)
    local key = ItemKey(link, displayName, source)
    local row = bucket[key]
    if type(row) ~= "table" then
        row = { link = link, name = displayName, count = 0, category = kind, source = source }
        bucket[key] = row
    end
    row.count = (row.count or 0) + count
    row.category = kind
    row.source = source
    if type(link) == "string" and link ~= "" then
        row.link = link
    end
    if displayName and displayName ~= "" then
        row.name = displayName
    end
    return true
end

local function BackpackHasWritBox()
    local now = NowMs()
    if now > 0 and (now - lastBoxScanMs) < BOX_SCAN_CACHE_MS then
        return lastBoxScanHit
    end
    lastBoxScanMs = now
    lastBoxScanHit = false
    if type(GetBagSize) ~= "function" then
        return false
    end
    local size = GetBagSize(BAG_BACKPACK) or 0
    for slot = 0, size - 1 do
        if SlotIsWritRewardBox(BAG_BACKPACK, slot) then
            lastBoxScanHit = true
            return true
        end
    end
    return false
end

local function IsLootingNow()
    if type(IsLooting) == "function" and IsLooting() then
        return true
    end
    return type(GetInteractionType) == "function" and GetInteractionType() == INTERACTION_LOOT
end

local function ItemCreditId(link, name)
    if type(GetItemLinkItemId) == "function" and type(link) == "string" then
        local id = GetItemLinkItemId(link)
        if type(id) == "number" and id > 0 then
            return tostring(id)
        end
    end
    return ItemName(link, name)
end

local function PruneRecentWritCredit()
    local now = NowMs()
    local i = 1
    while i <= #recentWritCredit do
        if now - recentWritCredit[i].ms > WRIT_CREDIT_DEDUPE_MS then
            table.remove(recentWritCredit, i)
        else
            i = i + 1
        end
    end
end

local function AlreadyCreditedWrit(link, count, name)
    PruneRecentWritCredit()
    local id = ItemCreditId(link, name)
    for i = 1, #recentWritCredit do
        local row = recentWritCredit[i]
        if row.id == id and row.count == count then
            table.remove(recentWritCredit, i)
            return true
        end
    end
    return false
end

local function NoteWritCredit(link, count, name)
    recentWritCredit[#recentWritCredit + 1] = {
        id = ItemCreditId(link, name),
        count = count,
        ms = NowMs(),
    }
end

local function AddWritItem(link, count, name)
    if AlreadyCreditedWrit(link, count, name) then
        return false
    end
    if AddItem(link, count, name, SOURCE_WRIT) then
        NoteWritCredit(link, count, name)
        NoteWritBagGain(link, count)
        return true
    end
    return false
end

local function RefreshIfShown()
    if BasaTools.IsShown and BasaTools.IsShown() then
        MatLog.RefreshReport()
    end
end

local function PruneOldDays()
    local log = LogTable()
    if not log then
        return
    end
    local cutoff = GetTimeStamp() - (RETENTION_DAYS * DAY_LENGTH)
    for key in pairs(log) do
        local ts = tonumber(key)
        if ts and ts < cutoff then
            log[key] = nil
        end
    end
end

local function NormalizeMailText(text)
    if type(text) ~= "string" or text == "" then
        return ""
    end
    if type(zo_strformat) == "function" then
        local formatted = zo_strformat("<<1>>", text)
        if type(formatted) == "string" and formatted ~= "" then
            text = formatted
        end
    end
    return string.lower(text)
end

local function SubjectLooksLikeHireling(subject)
    if type(subject) ~= "string" or subject == "" then
        return false
    end
    if HIRELING_SUBJECTS[subject] then
        return true
    end
    local want = NormalizeMailText(subject)
    for key, on in pairs(HIRELING_SUBJECTS) do
        if on and NormalizeMailText(key) == want then
            return true
        end
    end
    local wc = rawget(_G, "WritCreater")
    if type(wc) == "table" and type(wc.hirelingMailSubjects) == "table" then
        if wc.hirelingMailSubjects[subject] then
            return true
        end
        for key, on in pairs(wc.hirelingMailSubjects) do
            if on and NormalizeMailText(key) == want then
                return true
            end
        end
    end
    local lower = NormalizeMailText(subject)
    if string.find(lower, "hireling", 1, true) then
        return true
    end
    return false
end

local function SenderLooksLikeHireling(sender)
    local lower = NormalizeMailText(sender)
    if lower == "" then
        return false
    end
    if string.find(lower, "hireling", 1, true) then
        return true
    end
    if type(GetString) == "function" and type(HIRELING_TYPE_ITERATION_BEGIN) == "number" then
        local last = HIRELING_TYPE_ITERATION_END or HIRELING_TYPE_MAX_VALUE or 5
        for i = HIRELING_TYPE_ITERATION_BEGIN, last do
            local label = GetString("SI_HIRELINGTYPE", i)
            if type(label) == "string" and label ~= "" and string.find(lower, NormalizeMailText(label), 1, true) then
                return true
            end
        end
    end
    return false
end

local function SenderIsGuild(sender)
    if type(sender) ~= "string" or sender == "" then
        return false
    end
    local lower = NormalizeMailText(sender)
    if string.find(lower, "guild store", 1, true) or string.find(lower, "trading house", 1, true) then
        return true
    end
    if type(GetNumGuilds) == "function" and type(GetGuildName) == "function" then
        local n = GetNumGuilds() or 0
        for i = 1, n do
            local name = GetGuildName(i)
            if name == sender or NormalizeMailText(name) == lower then
                return true
            end
        end
    end
    return false
end

local function MailMeta(mailId)
    if type(GetMailItemInfo) ~= "function" then
        return nil
    end
    local sender, _, subject, _, _, fromSystem, fromCustomer, returned, numAtt, _money, codAmount = GetMailItemInfo(mailId)
    return {
        sender = sender,
        subject = subject,
        fromSystem = fromSystem and true or false,
        fromCustomer = fromCustomer and true or false,
        returned = returned and true or false,
        numAtt = numAtt or 0,
        codAmount = (type(codAmount) == "number" and codAmount) or 0,
    }
end

local function LooksLikeHirelingMeta(meta)
    if type(meta) ~= "table" then
        return false
    end
    if meta.fromCustomer or meta.returned or (meta.codAmount or 0) > 0 then
        return false
    end
    if SubjectLooksLikeHireling(meta.subject) or SenderLooksLikeHireling(meta.sender) then
        return true
    end
    -- System NPC mail that is not a guild-store shipment. Hireling subjects vary by
    -- language; guild-store mail uses the guild name as sender.
    if meta.fromSystem and not SenderIsGuild(meta.sender) then
        return true
    end
    return false
end

local function IsHirelingMail(mailId)
    return LooksLikeHirelingMeta(MailMeta(mailId))
end

local function ShouldSnapshotMail(mailId)
    local meta = MailMeta(mailId)
    if not meta or meta.numAtt <= 0 then
        return false
    end
    return LooksLikeHirelingMeta(meta)
end

local function ForEachInboxMail(fn)
    if type(GetNextMailId) ~= "function" then
        return
    end
    local id = GetNextMailId(nil)
    while id do
        fn(id)
        id = GetNextMailId(id)
    end
end

local function ScanHirelingInbox()
    local hasHireling = false
    local hasOtherAtt = false
    ForEachInboxMail(function(mailId)
        local meta = MailMeta(mailId)
        if not meta or meta.numAtt <= 0 then
            return
        end
        if LooksLikeHirelingMeta(meta) then
            hasHireling = true
        elseif meta.fromSystem then
            hasOtherAtt = true
        end
    end)
    inboxHasHireling = hasHireling
    if hasHireling then
        sawHirelingThisMailbox = true
    end
    return hasHireling, hasOtherAtt
end

local function ReadAttachments(mailId)
    local meta = MailMeta(mailId)
    local n = meta and meta.numAtt or 0
    if n <= 0 then
        return nil
    end
    local items = {}
    for i = 1, n do
        local link = nil
        if type(GetAttachedItemLink) == "function" then
            link = GetAttachedItemLink(mailId, i, LINK_STYLE_DEFAULT)
        end
        local count = 1
        local iconName = nil
        if type(GetAttachedItemInfo) == "function" then
            local _tex, stack, _creator, _sell, _meets, _eq, _quality, _style, name = GetAttachedItemInfo(mailId, i)
            if type(stack) == "number" and stack > 0 then
                count = stack
            end
            if type(name) == "string" and name ~= "" then
                iconName = name
            end
        end
        if type(link) == "string" and link ~= "" then
            items[#items + 1] = { link = link, count = count, name = ItemName(link, iconName) }
        end
    end
    if #items == 0 then
        return nil
    end
    return items
end

local function SnapshotMail(mailId)
    if not ShouldSnapshotMail(mailId) then
        return
    end
    local items = ReadAttachments(mailId)
    if items then
        mailSnapshots[MailKey(mailId)] = items
    end
end

local function SnapshotOpenInbox()
    ScanHirelingInbox()
    ForEachInboxMail(SnapshotMail)
end

local function SlotStackCount(bagId, slot)
    if type(GetSlotStackSize) == "function" then
        local n = GetSlotStackSize(bagId, slot)
        if type(n) == "number" and n > 0 then
            return n
        end
    end
    return 0
end

local function AddClassifiedSlot(bagId, slot, counts, links, kinds)
    local kind, link = ClassifySlot(bagId, slot)
    if not kind then
        return
    end
    local itemId = nil
    if type(GetItemLinkItemId) == "function" and type(link) == "string" then
        itemId = GetItemLinkItemId(link)
    end
    if type(itemId) ~= "number" or itemId <= 0 then
        return
    end
    local n = SlotStackCount(bagId, slot)
    counts[itemId] = (counts[itemId] or 0) + n
    links[itemId] = link
    kinds[itemId] = kind
end

local function ClassifiedBackpackCounts()
    -- Hireling / node mats with ESO Plus land in the craft bag (BAG_VIRTUAL),
    -- not the backpack. Take-all never opens messages, so this scan is the
    -- source of truth for both bags.
    local counts = {}
    local links = {}
    local kinds = {}
    if type(GetBagSize) == "function" then
        local size = GetBagSize(BAG_BACKPACK) or 0
        for slot = 0, size - 1 do
            AddClassifiedSlot(BAG_BACKPACK, slot, counts, links, kinds)
        end
    end
    if BAG_VIRTUAL and type(GetNextVirtualBagSlotId) == "function" then
        local slot = GetNextVirtualBagSlotId(nil)
        while slot do
            AddClassifiedSlot(BAG_VIRTUAL, slot, counts, links, kinds)
            slot = GetNextVirtualBagSlotId(slot)
        end
    end
    return counts, links, kinds
end

local function CaptureMailBagBaseline()
    local counts = ClassifiedBackpackCounts()
    backpackMailCounts = counts
    mailBagBaselineReady = true
end

local function CaptureWritBagBaseline()
    local counts = ClassifiedBackpackCounts()
    backpackWritCounts = counts
    writBagBaselineReady = true
end

local function EnsureWritBagBaseline()
    if not writBagBaselineReady then
        CaptureWritBagBaseline()
    end
end

NoteWritBagGain = function(link, count)
    if type(count) ~= "number" or count == 0 then
        return
    end
    if type(GetItemLinkItemId) ~= "function" or type(link) ~= "string" then
        return
    end
    local itemId = GetItemLinkItemId(link)
    if type(itemId) == "number" and itemId > 0 then
        backpackWritCounts[itemId] = (backpackWritCounts[itemId] or 0) + count
    end
end

local function CreditWritBagDiff()
    if not writBagBaselineReady then
        return
    end
    local now, links, kinds = ClassifiedBackpackCounts()
    local added = false
    for itemId, count in pairs(now) do
        local delta = count - (backpackWritCounts[itemId] or 0)
        if delta > 0 then
            local link = links[itemId]
            if AddItem(link, delta, ItemName(link), SOURCE_WRIT, kinds[itemId]) then
                added = true
            end
        end
    end
    backpackWritCounts = now
    if added then
        RefreshIfShown()
    end
end

local function NoteMailBagGain(link, count)
    if type(count) ~= "number" or count == 0 then
        return
    end
    if type(GetItemLinkItemId) ~= "function" or type(link) ~= "string" then
        return
    end
    local itemId = GetItemLinkItemId(link)
    if type(itemId) == "number" and itemId > 0 then
        backpackMailCounts[itemId] = (backpackMailCounts[itemId] or 0) + count
    end
end

local function CreditMailBagDiff()
    if not mailBagBaselineReady then
        return false
    end
    local now, links, kinds = ClassifiedBackpackCounts()
    local added = false
    for itemId, count in pairs(now) do
        local delta = count - (backpackMailCounts[itemId] or 0)
        if delta > 0 then
            local link = links[itemId]
            if AddItem(link, delta, ItemName(link), SOURCE_HIRELING, kinds[itemId]) then
                added = true
            end
        end
    end
    backpackMailCounts = now
    if added then
        mailDiffRetries = 0
        RefreshIfShown()
    end
    return added
end

local function ScheduleMailBagDiff(delayMs)
    if not mailBagBaselineReady then
        CaptureMailBagBaseline()
    end
    mailDiffToken = mailDiffToken + 1
    local token = mailDiffToken
    local function apply()
        if token ~= mailDiffToken then
            return
        end
        local added = CreditMailBagDiff()
        if mailCreditPending and not added and mailDiffRetries < MAIL_DIFF_MAX_RETRIES then
            mailDiffRetries = mailDiffRetries + 1
            ScheduleMailBagDiff(500)
            return
        end
        if mailDiffAfterClose then
            mailDiffAfterClose = false
            mailCreditPending = false
            mailBagBaselineReady = false
            backpackMailCounts = {}
        elseif added and not mailboxOpen then
            mailCreditPending = false
        end
    end
    if type(zo_callLater) == "function" then
        zo_callLater(apply, delayMs or 400)
    else
        apply()
    end
end

local function BeginMailCredit()
    mailCreditPending = true
    mailDiffRetries = 0
    if not mailBagBaselineReady then
        CaptureMailBagBaseline()
    end
end

local function AbsorbMailBagIntoBaseline(delayMs)
    mailCreditPending = false
    local function apply()
        CaptureMailBagBaseline()
    end
    if type(zo_callLater) == "function" then
        zo_callLater(apply, delayMs or 400)
    else
        apply()
    end
end

local function CreditHirelingItems(items)
    if type(items) ~= "table" then
        return false
    end
    local added = false
    for i = 1, #items do
        local item = items[i]
        if AddItem(item.link, item.count, item.name, SOURCE_HIRELING) then
            NoteMailBagGain(item.link, item.count)
            added = true
        end
    end
    return added
end

local function CreditMail(mailId)
    local key = MailKey(mailId)
    local items = mailSnapshots[key]
    if type(items) ~= "table" and IsHirelingMail(mailId) then
        items = ReadAttachments(mailId)
    end
    mailSnapshots[key] = nil
    if CreditHirelingItems(items) then
        RefreshIfShown()
    end
end

local function OnMailOpen()
    mailboxOpen = true
    mailDiffAfterClose = false
    mailCreditPending = false
    takeAllInProgress = false
    sawHirelingThisMailbox = false
    inboxHasHireling = false
    lastMailHireling = false
    mailDiffRetries = 0
    SnapshotOpenInbox()
    CaptureMailBagBaseline()
end

local function OnMailClose()
    mailboxOpen = false
    lastMailHireling = false
    takeAllInProgress = false
    if mailCreditPending then
        mailDiffAfterClose = true
        ScheduleMailBagDiff(600)
    else
        mailDiffAfterClose = false
        mailBagBaselineReady = false
        backpackMailCounts = {}
        sawHirelingThisMailbox = false
    end
end

local function OnMailReadable(_, mailId)
    lastMailHireling = IsHirelingMail(mailId)
    SnapshotMail(mailId)
end

local function CraftingBusy()
    if type(GetCraftingInteractionType) ~= "function" then
        return false
    end
    local craft = GetCraftingInteractionType()
    return type(craft) == "number" and craft > 0
end

local function ExtendWritCapture(seconds, name)
    local untilT = GetTimeStamp() + (seconds or WRIT_LOOT_WINDOW_S)
    if pendingWrit then
        if untilT > (pendingWrit.untilTime or 0) then
            pendingWrit.untilTime = untilT
        end
        if type(name) == "string" and name ~= "" then
            pendingWrit.boxName = name
        end
        return
    end
    pendingWrit = {
        name = name or "box",
        items = {},
        untilTime = untilT,
        fromBox = true,
    }
end

local function WritCaptureActive()
    if not pendingWrit then
        return false
    end
    if type(GetTimeStamp) == "function" and pendingWrit.untilTime and GetTimeStamp() > pendingWrit.untilTime then
        if BackpackHasWritBox() then
            pendingWrit.untilTime = GetTimeStamp() + WRIT_LOOT_WINDOW_S
            return true
        end
        CreditWritBagDiff()
        pendingWrit = nil
        return false
    end
    return true
end

local function ShouldIgnoreInventoryGain()
    -- Mailbox inventory is credited from snapshots / bag-diff, not slot updates
    -- (craft-bag stacks often have stackCountChange 0). Do not log it as World.
    if mailboxOpen then
        return true
    end
    if WritCaptureActive() or IsLootingNow() then
        return false
    end
    if CraftingBusy() then
        return true
    end
    if type(GetInteractionType) == "function" then
        local interaction = GetInteractionType()
        if SUPPRESS_INTERACTION[interaction] then
            return true
        end
    end
    return false
end

local function MarkWorldLoot()
    local now = NowMs()
    if now > 0 then
        worldLootUntilMs = now + WORLD_LOOT_GRACE_MS
    end
end

local function WorldLootActive()
    local now = NowMs()
    if now > 0 and now < worldLootUntilMs then
        return true
    end
    if type(GetInteractionType) == "function" then
        local interaction = GetInteractionType()
        if interaction == INTERACTION_HARVEST
            or interaction == INTERACTION_FISH
            or interaction == INTERACTION_PICKPOCKET
            or interaction == INTERACTION_HIDEYHOLE
            or interaction == INTERACTION_ANTIQUITY_DIG_SPOT then
            return true
        end
    end
    if type(GetLootTargetInfo) == "function" then
        local name, targetType = GetLootTargetInfo()
        if IsWritRewardBoxName(name) then
            return false
        end
        if targetType == INTERACT_TARGET_TYPE_OBJECT
            or targetType == INTERACT_TARGET_TYPE_FIXTURE
            or targetType == INTERACT_TARGET_TYPE_AOE_LOOT then
            return true
        end
    end
    return false
end

local function CurrentSource()
    -- Harvest / node loot while LWC still has a writ coffer open.
    if WorldLootActive() then
        return SOURCE_WORLD
    end
    if WritCaptureActive() then
        return SOURCE_WRIT
    end
    if mailboxOpen then
        return SOURCE_HIRELING
    end
    return SOURCE_WORLD
end

local function IsDailyWritQuest(journalIndex)
    if type(journalIndex) ~= "number" then
        return false
    end
    if type(GetJournalQuestRepeatType) ~= "function" or type(GetJournalQuestType) ~= "function" then
        return false
    end
    if GetJournalQuestRepeatType(journalIndex) ~= QUEST_REPEAT_DAILY then
        return false
    end
    local qType = GetJournalQuestType(journalIndex)
    if qType ~= QUEST_TYPE_CRAFTING and qType ~= QUEST_TYPE_HOLIDAY_EVENT then
        return false
    end
    if type(GetQuestConditionMasterWritInfo) == "function" then
        local master = GetQuestConditionMasterWritInfo(journalIndex, 1, 1)
        if master ~= nil then
            return false
        end
    end
    return true
end

local function ScanTrackedWrits()
    trackedWritNames = {}
    local n = 25
    if type(GetNumJournalQuests) == "function" then
        n = GetNumJournalQuests() or 25
    end
    for i = 1, n do
        if IsDailyWritQuest(i) then
            local name = GetJournalQuestName(i)
            if type(name) == "string" and name ~= "" then
                trackedWritNames[name] = true
            end
        end
    end
end

local function SnapshotWritRewards(journalIndex)
    local items = {}
    if type(GetJournalQuestNumRewards) ~= "function" or type(GetJournalQuestRewardInfo) ~= "function" then
        return items
    end
    local num = GetJournalQuestNumRewards(journalIndex) or 0
    for i = 1, num do
        local rewardType, name, amount = GetJournalQuestRewardInfo(journalIndex, i)
        if rewardType == REWARD_TYPE_AUTO_ITEM or rewardType == REWARD_TYPE_STYLE_STONES then
            local link = nil
            if type(GetQuestRewardItemLink) == "function" then
                link = GetQuestRewardItemLink(i, LINK_STYLE_DEFAULT)
            end
            items[#items + 1] = {
                link = link,
                name = name,
                count = (type(amount) == "number" and amount > 0) and amount or 1,
            }
        end
    end
    return items
end

local function BeginWritCapture(journalIndex, questName)
    CaptureWritBagBaseline()
    local items = SnapshotWritRewards(journalIndex)
    ExtendWritCapture(WRIT_LOOT_WINDOW_S, questName)
    pendingWrit.items = items
end

local function CreditWritSnapshot()
    if not pendingWrit then
        return
    end
    local items = pendingWrit.items or {}
    pendingWrit.items = {}
    local added = false
    for i = 1, #items do
        local item = items[i]
        if not IsWritRewardContainerLink(item.link) then
            if AddWritItem(item.link, item.count, item.name) then
                added = true
            end
        end
    end
    if added then
        RefreshIfShown()
    end
end

local function StartCaptureIfWritBoxes()
    EnsureWritBoxLookups()
    lastBoxScanMs = 0
    if BackpackHasWritBox() then
        EnsureWritBagBaseline()
        ExtendWritCapture(WRIT_LOOT_WINDOW_S, "bag")
    end
end

local function OnQuestCompleteDialog(_, journalIndex)
    local name = GetJournalQuestName(journalIndex)
    if IsDailyWritQuest(journalIndex) or (type(name) == "string" and trackedWritNames[name]) then
        BeginWritCapture(journalIndex, name)
    end
end

local function OnQuestComplete(_, questName)
    if type(questName) == "string" and trackedWritNames[questName] then
        if not pendingWrit then
            pendingWrit = { name = questName, items = {}, untilTime = GetTimeStamp() + WRIT_LOOT_WINDOW_S }
        else
            pendingWrit.untilTime = GetTimeStamp() + WRIT_LOOT_WINDOW_S
        end
    end
end

local function OnQuestRemoved(_, isCompleted, _journalIndex, questName)
    if not isCompleted then
        if type(questName) == "string" then
            trackedWritNames[questName] = nil
        end
        return
    end
    if pendingWrit then
        CreditWritSnapshot()
        pendingWrit.untilTime = GetTimeStamp() + WRIT_LOOT_WINDOW_S
    elseif type(questName) == "string" and trackedWritNames[questName] then
        pendingWrit = { name = questName, items = {}, untilTime = GetTimeStamp() + WRIT_LOOT_WINDOW_S }
    end
    if type(questName) == "string" then
        trackedWritNames[questName] = nil
    end
    ScanTrackedWrits()
end

local function OnQuestAdded()
    ScanTrackedWrits()
end

local function OnMailTake(_, mailId)
    -- Category Take all is credited from bag-diff so per-mail events do not
    -- double-count. Single-mail Take all uses TakeMailAttachments (not the
    -- older TakeMailAttachedItems) and is snapshotted in that PreHook.
    if takeAllInProgress then
        return
    end
    local hireling = IsHirelingMail(mailId) or mailSnapshots[MailKey(mailId)] ~= nil
    lastMailHireling = hireling
    if hireling then
        BeginMailCredit()
        CreditMail(mailId)
        ScheduleMailBagDiff(400)
    else
        AbsorbMailBagIntoBaseline(400)
    end
end

local function OnMailTakeAll(_, result, category)
    -- Inbox category "Take all" does not open each message. MAIL_CATEGORY_PLAYER_MAIL
    -- is 0 (falsy), so compare with == only. Hireling mail is SYSTEM; guild-store
    -- mail is too. Bag-diff whenever this mailbox had hireling mail — mixed inboxes
    -- may include other system attachments.
    takeAllInProgress = false
    if type(result) == "number" and result ~= MAIL_TAKE_ATTACHMENT_RESULT_SUCCESS then
        return
    end
    if category == MAIL_CATEGORY_PLAYER_MAIL then
        AbsorbMailBagIntoBaseline(200)
        return
    end
    if mailCreditPending or sawHirelingThisMailbox then
        BeginMailCredit()
        ScheduleMailBagDiff(800)
    end
end

local function OnMailInboxUpdate()
    if mailboxOpen and not mailCreditPending and not takeAllInProgress then
        ScanHirelingInbox()
        ForEachInboxMail(SnapshotMail)
    end
end

local function PrepareSingleMailTake(mailId)
    lastMailHireling = IsHirelingMail(mailId)
    SnapshotMail(mailId)
    if lastMailHireling then
        BeginMailCredit()
    end
end

local function HookMailTakeApis()
    if mailApiHooked or type(ZO_PreHook) ~= "function" then
        return
    end
    mailApiHooked = true
    ZO_PreHook("TakeAllMailAttachmentsInCategory", function(category)
        if not listenersOn then
            return
        end
        takeAllInProgress = true
        ScanHirelingInbox()
        CaptureMailBagBaseline()
        if category == MAIL_CATEGORY_PLAYER_MAIL then
            mailCreditPending = false
            return
        end
        if sawHirelingThisMailbox or inboxHasHireling then
            BeginMailCredit()
            ScheduleMailBagDiff(1200)
        end
    end)
    -- Keyboard/gamepad "Take All" on one mail, and LWC, call TakeMailAttachments.
    ZO_PreHook("TakeMailAttachments", function(mailId)
        if not listenersOn then
            return
        end
        PrepareSingleMailTake(mailId)
    end)
    ZO_PreHook("TakeMailAttachedItems", function(mailId)
        if not listenersOn then
            return
        end
        PrepareSingleMailTake(mailId)
    end)
    if type(ZO_MailInboxShared_TakeAll) == "function" then
        ZO_PreHook("ZO_MailInboxShared_TakeAll", function(mailId)
            if not listenersOn then
                return
            end
            PrepareSingleMailTake(mailId)
        end)
    end
end

local function SlotGainCount(bagId, slotIndex, isNewItem, stackCountChange)
    if type(stackCountChange) == "number" and stackCountChange > 0 then
        return stackCountChange
    end
    -- Craft-bag slots hold the whole stack of an item. That total is not a gain.
    if bagId == BAG_VIRTUAL then
        return nil
    end
    if isNewItem or WritCaptureActive() or IsLootingNow() then
        if type(GetSlotStackSize) == "function" then
            local n = GetSlotStackSize(bagId, slotIndex)
            if type(n) == "number" and n > 0 then
                return n
            end
        end
        return 1
    end
    return nil
end

local function RecordGain(link, count, name, source)
    if source == SOURCE_WRIT then
        return AddWritItem(link, count, name)
    end
    return AddItem(link, count, name, source)
end

local function CreditLootWindow()
    if type(GetNumLootItems) ~= "function" or type(GetLootItemInfo) ~= "function" then
        return false
    end
    local n = GetNumLootItems() or 0
    local added = false
    for i = 1, n do
        local lootId, lootName, _, quantity = GetLootItemInfo(i)
        local link = nil
        if type(GetLootItemLink) == "function" and lootId then
            link = GetLootItemLink(lootId, LINK_STYLE_DEFAULT)
        end
        if RecordGain(link, quantity or 1, lootName, SOURCE_WRIT) then
            added = true
        end
    end
    return added
end

local function OnInventorySlot(_, bagId, slotIndex, isNewItem, _sound, _reason, stackCountChange)
    if bagId ~= BAG_BACKPACK and bagId ~= BAG_VIRTUAL then
        return
    end
    lastBoxScanMs = 0
    if type(GetItemLink) ~= "function" then
        return
    end
    local link = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
    if IsWritRewardContainerLink(link) then
        EnsureWritBagBaseline()
        ExtendWritCapture(WRIT_LOOT_WINDOW_S, ItemName(link))
        return
    end
    if mailboxOpen and mailCreditPending then
        ScheduleMailBagDiff(300)
    end
    local count = SlotGainCount(bagId, slotIndex, isNewItem, stackCountChange)
    if not count then
        return
    end
    if ShouldIgnoreInventoryGain() then
        return
    end
    local source = CurrentSource()
    if RecordGain(link, count, nil, source) then
        lastInvAddMs = NowMs()
        if source == SOURCE_HIRELING then
            NoteMailBagGain(link, count)
        elseif source == SOURCE_WORLD and WritCaptureActive() then
            NoteWritBagGain(link, count)
        end
        RefreshIfShown()
    end
end

local function OnLootReceived(_, _receivedBy, itemName, quantity, _sound, _lootType, isSelf)
    if not isSelf then
        return
    end
    if mailboxOpen and not WritCaptureActive() then
        return
    end
    if ShouldIgnoreInventoryGain() then
        return
    end
    if not WritCaptureActive() and (NowMs() - lastInvAddMs) < 600 then
        return
    end
    local source = CurrentSource()
    if RecordGain(itemName, quantity or 1, ItemName(itemName), source) then
        lastInvAddMs = NowMs()
        if source == SOURCE_WORLD and WritCaptureActive() then
            NoteWritBagGain(itemName, quantity or 1)
        end
        RefreshIfShown()
    end
end

local function OnLootUpdated()
    local name, targetType
    if type(GetLootTargetInfo) == "function" then
        name, targetType = GetLootTargetInfo()
    end
    local isWritBox = IsWritRewardBoxName(name)
    -- Used coffers are ITEM. Harvest nodes are OBJECT / FIXTURE — do not treat
    -- every loot window during writ capture as a box.
    if not isWritBox and WritCaptureActive() and targetType == INTERACT_TARGET_TYPE_ITEM then
        isWritBox = true
    end
    lootingWritBox = isWritBox
    if not isWritBox then
        if WritCaptureActive() then
            MarkWorldLoot()
        end
        return
    end
    ExtendWritCapture(WRIT_LOOT_WINDOW_S, name)
    if CreditLootWindow() then
        lastInvAddMs = NowMs()
        RefreshIfShown()
    end
end

local function OnLootClosed()
    local wasWritBox = lootingWritBox
    lootingWritBox = false
    if not wasWritBox then
        return
    end
    if pendingWrit then
        pendingWrit.untilTime = GetTimeStamp() + WRIT_BOX_DRAIN_S
        if BackpackHasWritBox() then
            pendingWrit.untilTime = GetTimeStamp() + WRIT_LOOT_WINDOW_S
        end
    end
    local function apply()
        CreditWritBagDiff()
    end
    if type(zo_callLater) == "function" then
        zo_callLater(apply, 200)
    else
        apply()
    end
end

local function UnregisterListeners()
    EVENT_MANAGER:UnregisterForEvent(EVENT_PREFIX .. "MailReadable", EVENT_MAIL_READABLE)
    EVENT_MANAGER:UnregisterForEvent(EVENT_PREFIX .. "MailTake", EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS)
    EVENT_MANAGER:UnregisterForEvent(EVENT_PREFIX .. "MailTakeAll", EVENT_MAIL_TAKE_ALL_ATTACHMENTS_IN_CATEGORY_RESPONSE)
    EVENT_MANAGER:UnregisterForEvent(EVENT_PREFIX .. "MailOpen", EVENT_MAIL_OPEN_MAILBOX)
    EVENT_MANAGER:UnregisterForEvent(EVENT_PREFIX .. "MailClose", EVENT_MAIL_CLOSE_MAILBOX)
    EVENT_MANAGER:UnregisterForEvent(EVENT_PREFIX .. "MailInbox", EVENT_MAIL_INBOX_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(EVENT_PREFIX .. "Inv", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(EVENT_PREFIX .. "InvVirtual", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(EVENT_PREFIX .. "Loot", EVENT_LOOT_RECEIVED)
    EVENT_MANAGER:UnregisterForEvent(EVENT_PREFIX .. "LootUpdated", EVENT_LOOT_UPDATED)
    EVENT_MANAGER:UnregisterForEvent(EVENT_PREFIX .. "LootClosed", EVENT_LOOT_CLOSED)
    EVENT_MANAGER:UnregisterForEvent(EVENT_PREFIX .. "QuestDialog", EVENT_QUEST_COMPLETE_DIALOG)
    EVENT_MANAGER:UnregisterForEvent(EVENT_PREFIX .. "QuestComplete", EVENT_QUEST_COMPLETE)
    EVENT_MANAGER:UnregisterForEvent(EVENT_PREFIX .. "QuestRemoved", EVENT_QUEST_REMOVED)
    EVENT_MANAGER:UnregisterForEvent(EVENT_PREFIX .. "QuestAdded", EVENT_QUEST_ADDED)
    EVENT_MANAGER:UnregisterForEvent(EVENT_PREFIX .. "Activated", EVENT_PLAYER_ACTIVATED)
    listenersOn = false
end

local function RegisterListeners()
    if listenersOn then
        return
    end
    EVENT_MANAGER:RegisterForEvent(EVENT_PREFIX .. "MailReadable", EVENT_MAIL_READABLE, OnMailReadable)
    EVENT_MANAGER:RegisterForEvent(EVENT_PREFIX .. "MailTake", EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, OnMailTake)
    EVENT_MANAGER:RegisterForEvent(EVENT_PREFIX .. "MailTakeAll", EVENT_MAIL_TAKE_ALL_ATTACHMENTS_IN_CATEGORY_RESPONSE, OnMailTakeAll)
    EVENT_MANAGER:RegisterForEvent(EVENT_PREFIX .. "MailOpen", EVENT_MAIL_OPEN_MAILBOX, OnMailOpen)
    EVENT_MANAGER:RegisterForEvent(EVENT_PREFIX .. "MailClose", EVENT_MAIL_CLOSE_MAILBOX, OnMailClose)
    EVENT_MANAGER:RegisterForEvent(EVENT_PREFIX .. "MailInbox", EVENT_MAIL_INBOX_UPDATE, OnMailInboxUpdate)
    EVENT_MANAGER:RegisterForEvent(EVENT_PREFIX .. "Inv", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySlot)
    if type(EVENT_MANAGER.AddFilterForEvent) == "function" and REGISTER_FILTER_BAG_ID and BAG_BACKPACK then
        EVENT_MANAGER:AddFilterForEvent(EVENT_PREFIX .. "Inv", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    end
    if BAG_VIRTUAL then
        EVENT_MANAGER:RegisterForEvent(EVENT_PREFIX .. "InvVirtual", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySlot)
        if type(EVENT_MANAGER.AddFilterForEvent) == "function" and REGISTER_FILTER_BAG_ID then
            EVENT_MANAGER:AddFilterForEvent(EVENT_PREFIX .. "InvVirtual", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_VIRTUAL)
        end
    end
    HookMailTakeApis()
    EVENT_MANAGER:RegisterForEvent(EVENT_PREFIX .. "Loot", EVENT_LOOT_RECEIVED, OnLootReceived)
    EVENT_MANAGER:RegisterForEvent(EVENT_PREFIX .. "LootUpdated", EVENT_LOOT_UPDATED, OnLootUpdated)
    EVENT_MANAGER:RegisterForEvent(EVENT_PREFIX .. "LootClosed", EVENT_LOOT_CLOSED, OnLootClosed)
    EVENT_MANAGER:RegisterForEvent(EVENT_PREFIX .. "QuestDialog", EVENT_QUEST_COMPLETE_DIALOG, OnQuestCompleteDialog)
    EVENT_MANAGER:RegisterForEvent(EVENT_PREFIX .. "QuestComplete", EVENT_QUEST_COMPLETE, OnQuestComplete)
    EVENT_MANAGER:RegisterForEvent(EVENT_PREFIX .. "QuestRemoved", EVENT_QUEST_REMOVED, OnQuestRemoved)
    EVENT_MANAGER:RegisterForEvent(EVENT_PREFIX .. "QuestAdded", EVENT_QUEST_ADDED, OnQuestAdded)
    EVENT_MANAGER:RegisterForEvent(EVENT_PREFIX .. "Activated", EVENT_PLAYER_ACTIVATED, function()
        EnsureWritBoxLookups()
        ScanTrackedWrits()
        StartCaptureIfWritBoxes()
        PruneOldDays()
    end)
    listenersOn = true
end

function MatLog.SetEnabled(enabled)
    if enabled then
        RegisterListeners()
        ScanTrackedWrits()
        StartCaptureIfWritBoxes()
        PruneOldDays()
    else
        UnregisterListeners()
    end
end

local function GetList()
    local panel = GetPanel()
    local backdrop = Child(panel, "ListBackdrop")
    return Child(backdrop, "List"), Child(panel, "Totals")
end

local function GetHeaders()
    local panel = GetPanel()
    local backdrop = Child(panel, "ListBackdrop")
    return Child(backdrop, "Headers")
end

local HEADER_SPECS = {
    { child = "Item", key = "item", label = "Item", align = TEXT_ALIGN_LEFT, dir = ZO_SORT_ORDER_UP },
    { child = "Qty", key = "qty", label = "Qty", align = TEXT_ALIGN_RIGHT, dir = ZO_SORT_ORDER_UP },
    { child = "Category", key = "category", label = "Category", align = TEXT_ALIGN_LEFT, dir = ZO_SORT_ORDER_UP },
    { child = "Character", key = "character", label = "Character", align = TEXT_ALIGN_LEFT, dir = ZO_SORT_ORDER_UP },
    { child = "Value", key = "value", label = "Gold", align = TEXT_ALIGN_RIGHT, dir = ZO_SORT_ORDER_DOWN },
}

local function SortOrderFromAsc(asc)
    if asc then
        return ZO_SORT_ORDER_UP
    end
    return ZO_SORT_ORDER_DOWN
end

local function OnSortHeaderClicked(key, order)
    if type(key) ~= "string" or not SORT_KEYS[key] then
        return
    end
    if showingHelp then
        return
    end
    sortKey = key
    sortAsc = (order == ZO_SORT_ORDER_UP)
    if saved then
        saved.matlogSortKey = sortKey
        saved.matlogSortAsc = sortAsc
    end
    MatLog.RefreshReport()
end

local function BindSortHeaders()
    if sortHeaderGroup then
        return
    end
    local headers = GetHeaders()
    if not headers or type(ZO_SortHeader_Initialize) ~= "function" or type(ZO_SortHeaderGroup) ~= "table" then
        return
    end
    for i = 1, #HEADER_SPECS do
        local spec = HEADER_SPECS[i]
        local control = Child(headers, spec.child)
        if control then
            ZO_SortHeader_Initialize(control, spec.label, spec.key, spec.dir, spec.align, "ZoFontGameBold")
        end
    end
    sortHeaderGroup = ZO_SortHeaderGroup:New(headers, true)
    local clicked = ZO_SortHeaderGroup.HEADER_CLICKED or "HeaderClicked"
    sortHeaderGroup:RegisterCallback(clicked, OnSortHeaderClicked)
    if sortHeaderGroup.AddHeadersFromContainer then
        sortHeaderGroup:AddHeadersFromContainer()
    else
        for i = 1, #HEADER_SPECS do
            local control = Child(headers, HEADER_SPECS[i].child)
            if control then
                sortHeaderGroup:AddHeader(control)
            end
        end
    end
    local suppress = ZO_SortHeaderGroup.SUPPRESS_CALLBACKS
    if sortHeaderGroup.SelectHeaderByKey then
        sortHeaderGroup:SelectHeaderByKey(sortKey, suppress, true, SortOrderFromAsc(sortAsc))
    end
end

RefreshHeaders = function()
    BindSortHeaders()
    if not sortHeaderGroup then
        return
    end
    local summary = saved and saved.matlogView == "summary"
    if sortHeaderGroup.SetHeaderHiddenForKey then
        sortHeaderGroup:SetHeaderHiddenForKey("character", summary and true or false)
    else
        local charHdr = Child(GetHeaders(), "Character")
        if charHdr and charHdr.SetHidden then
            charHdr:SetHidden(summary and true or false)
        end
    end
end

local function SetHeadersVisible(visible)
    local panel = GetPanel()
    local backdrop = Child(panel, "ListBackdrop")
    local headers = Child(backdrop, "Headers")
    local list = Child(backdrop, "List")
    if headers then
        headers:SetHidden(not visible)
    end
    if list and list.ClearAnchors then
        list:ClearAnchors()
        local top = visible and 34 or 4
        list:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 4, top)
        list:SetAnchor(BOTTOMRIGHT, backdrop, BOTTOMRIGHT, -4, -4)
    end
    if visible then
        RefreshHeaders()
    end
end

local function HideTooltip()
    if ItemTooltip then
        ClearTooltip(ItemTooltip)
    end
end

local function ShowItemTooltip(control, link)
    if not control or type(link) ~= "string" or link == "" or not ItemTooltip then
        return
    end
    InitializeTooltip(ItemTooltip, control, LEFT, 0, 0, RIGHT)
    if ItemTooltip.SetLink then
        ItemTooltip:SetLink(link)
    end
end

local function SetupMatLogRow(control, data)
    local icon = Child(control, "Icon")
    local item = Child(control, "Item")
    local qty = Child(control, "Qty")
    local category = Child(control, "Category")
    local character = Child(control, "Character")
    local value = Child(control, "Value")
    local valueTotal = value and Child(value, "Total")
    local valueUnit = value and Child(value, "Unit")
    local divider = Child(control, "RowDivider")
    if divider then
        if divider.SetColor then
            divider:SetColor(1, 1, 1, 0.18)
        end
        if divider.SetAlpha then
            divider:SetAlpha(0.18)
        end
        divider:SetHidden(false)
    end
    local r, g, b = data.r or 0.9, data.g or 0.9, data.b or 0.85
    if icon then
        if type(data.icon) == "string" and data.icon ~= "" then
            icon:SetTexture(data.icon)
            icon:SetHidden(false)
        else
            icon:SetHidden(true)
        end
    end
    if item then
        item:SetText(data.item or "")
        item:SetColor(r, g, b, 1)
    end
    if qty then
        qty:SetText(data.qty or "")
        qty:SetColor(r, g, b, 1)
    end
    if category then
        category:SetText(data.category or "")
        category:SetColor(r, g, b, 1)
        category:SetHidden(data.hideCategory and true or false)
    end
    if character then
        character:SetText(data.character or "")
        character:SetColor(r, g, b, 1)
        character:SetHidden(data.hideCharacter and true or false)
    end
    local hideValue = data.hideValue and true or false
    if value then
        value:SetHidden(hideValue)
    end
    if valueTotal then
        local totalText = ColorGoldText(data.valueTotal, COL_GOLD_TOTAL)
        valueTotal:SetText(totalText)
        valueTotal:SetColor(COL_GOLD_TOTAL[1], COL_GOLD_TOTAL[2], COL_GOLD_TOTAL[3], 1)
        valueTotal:SetHidden(hideValue or totalText == "")
    end
    if valueUnit then
        local unitText = ColorGoldText(data.valueUnit, COL_GOLD_UNIT)
        valueUnit:SetText(unitText)
        valueUnit:SetColor(COL_GOLD_UNIT[1], COL_GOLD_UNIT[2], COL_GOLD_UNIT[3], 1)
        valueUnit:SetHidden(hideValue or unitText == "")
    end
    if control.SetHandler then
        control:SetHandler("OnMouseEnter", function(self)
            ShowItemTooltip(self, data.link)
        end)
        control:SetHandler("OnMouseExit", function()
            HideTooltip()
        end)
    end
end

local function SetupLineRow(control, data)
    local label = Child(control, "Line")
    if not label then
        return
    end
    label:SetText(data.text or "")
    label:SetColor(data.r or 0.9, data.g or 0.9, data.b or 0.85, 1)
end

local function EnsureListTypes()
    if listTypesReady then
        return
    end
    local list = GetList()
    if not list or type(ZO_ScrollList_AddDataType) ~= "function" then
        return
    end
    ZO_ScrollList_AddDataType(list, 1, "BasaToolsMatLogRow", 42, SetupMatLogRow)
    ZO_ScrollList_AddDataType(list, 2, "BasaToolsOutputLineRow", 22, SetupLineRow)
    listTypesReady = true
end

local function SortedDayKeys()
    local log = LogTable() or {}
    local keys = {}
    local current = CurrentDayKey()
    local seen = false
    for key in pairs(log) do
        keys[#keys + 1] = key
        if key == current then
            seen = true
        end
    end
    if not seen then
        keys[#keys + 1] = current
    end
    table.sort(keys, function(a, b)
        return (tonumber(a) or 0) > (tonumber(b) or 0)
    end)
    local kept = {}
    for i = 1, math.min(#keys, RETENTION_DAYS) do
        kept[#kept + 1] = keys[i]
    end
    return kept
end

local function DayChars(dayKey)
    local log = LogTable()
    local day = log and log[dayKey]
    local names = {}
    if type(day) == "table" then
        for name in pairs(day) do
            names[#names + 1] = name
        end
        table.sort(names)
    end
    return names, day
end

local function ItemIcon(link)
    if type(link) == "string" and link ~= "" and type(GetItemLinkIcon) == "function" then
        local tex = GetItemLinkIcon(link)
        if type(tex) == "string" and tex ~= "" then
            return tex
        end
    end
    return "EsoUI/Art/Icons/icon_missing.dds"
end

local function CollectRows()
    local dayKey = selectedDayKey or CurrentDayKey()
    local names, day = DayChars(dayKey)
    local summary = saved and saved.matlogView == "summary"
    local rows = {}
    local stacked = {}
    local stackOrder = {}
    local totalValue = 0
    local priced = false

    local function wantChar(name)
        return selectedChar == "all" or selectedChar == name
    end

    local function wantCategory(source)
        return selectedCategory == "all" or selectedCategory == source
    end

    local function consider(charName, entry)
        if type(entry) ~= "table" then
            return
        end
        local source = NormalizeSource(entry.source)
        if not wantCategory(source) then
            return
        end
        local color = summary and KindColor(entry.category) or SourceColor(source)
        local unit = PriceGold(entry.link)
        local count = entry.count or 0
        local lineValue = nil
        if unit then
            lineValue = unit * count
            totalValue = totalValue + lineValue
            priced = true
        end
        local displayName = SanitizeItemName(entry.name) or entry.name or "Item"
        if summary then
            local key = ItemBaseKey(entry.link, displayName)
            local slot = stacked[key]
            if not slot then
                slot = {
                    link = entry.link,
                    name = displayName,
                    count = 0,
                    category = entry.category,
                    icon = ItemIcon(entry.link),
                    r = color[1],
                    g = color[2],
                    b = color[3],
                }
                stacked[key] = slot
                stackOrder[#stackOrder + 1] = key
            end
            slot.count = slot.count + count
            if type(entry.link) == "string" and entry.link ~= "" then
                slot.link = entry.link
            end
        else
            rows[#rows + 1] = {
                kind = "item",
                qty = tostring(count),
                qtyNum = count,
                item = displayName,
                category = SOURCE_LABEL[source] or "Hireling",
                character = charName,
                valueTotal = unit and FormatGold(lineValue) or "",
                valueUnit = unit and FormatGold(unit) or "",
                valueNum = lineValue or 0,
                icon = ItemIcon(entry.link),
                link = entry.link,
                r = color[1],
                g = color[2],
                b = color[3],
            }
        end
    end

    if type(day) == "table" then
        for i = 1, #names do
            local charName = names[i]
            if wantChar(charName) then
                local bucket = day[charName]
                if type(bucket) == "table" then
                    local keys = {}
                    for key in pairs(bucket) do
                        keys[#keys + 1] = key
                    end
                    table.sort(keys, function(a, b)
                        local na = bucket[a] and bucket[a].name or a
                        local nb = bucket[b] and bucket[b].name or b
                        return na < nb
                    end)
                    for k = 1, #keys do
                        consider(charName, bucket[keys[k]])
                    end
                end
            end
        end
    end

    if summary then
        totalValue = 0
        priced = false
        for i = 1, #stackOrder do
            local entry = stacked[stackOrder[i]]
            local unit = PriceGold(entry.link)
            local count = entry.count or 0
            local lineValue = nil
            if unit then
                lineValue = unit * count
                totalValue = totalValue + lineValue
                priced = true
            end
            local displayName = SanitizeItemName(entry.name) or entry.name or "Item"
            rows[#rows + 1] = {
                kind = "item",
                qty = tostring(count),
                qtyNum = count,
                item = displayName,
                category = KIND_LABEL[entry.category] or "",
                character = "",
                valueTotal = unit and FormatGold(lineValue) or "",
                valueUnit = unit and FormatGold(unit) or "",
                valueNum = lineValue or 0,
                icon = entry.icon,
                link = entry.link,
                hideCharacter = true,
                r = entry.r,
                g = entry.g,
                b = entry.b,
            }
        end
    end

    table.sort(rows, function(a, b)
        local ka, kb
        if sortKey == "qty" then
            ka, kb = a.qtyNum or 0, b.qtyNum or 0
        elseif sortKey == "value" then
            ka, kb = a.valueNum or 0, b.valueNum or 0
        elseif sortKey == "category" then
            ka, kb = string.lower(a.category or ""), string.lower(b.category or "")
        elseif sortKey == "character" then
            ka, kb = string.lower(a.character or ""), string.lower(b.character or "")
        else
            ka, kb = string.lower(a.item or ""), string.lower(b.item or "")
        end
        if ka == kb then
            local ia, ib = string.lower(a.item or ""), string.lower(b.item or "")
            if ia ~= ib then
                return ia < ib
            end
            local ca, cb = string.lower(a.category or ""), string.lower(b.category or "")
            if ca ~= cb then
                return ca < cb
            end
            return (a.character or "") < (b.character or "")
        end
        if sortAsc then
            return ka < kb
        end
        return ka > kb
    end)

    return rows, { count = #rows, totalValue = totalValue, priced = priced, summary = summary }
end

local function FillList(entries, lineMode, showHeaders)
    EnsureListTypes()
    SetHeadersVisible(showHeaders and true or false)
    local list, totalsLabel = GetList()
    if not list or not ZO_ScrollList_Clear then
        return
    end
    ZO_ScrollList_Clear(list)
    local scrollData = ZO_ScrollList_GetDataList(list)
    for i = 1, #entries do
        local e = entries[i]
        local rowType = lineMode and 2 or 1
        table.insert(scrollData, ZO_ScrollList_CreateDataEntry(rowType, e))
    end
    ZO_ScrollList_Commit(list)
    if type(ZO_ScrollList_ResetToTop) == "function" then
        ZO_ScrollList_ResetToTop(list)
    end
    return totalsLabel
end

local function TotalsText(info)
    info = info or {}
    local parts = {}
    if info.summary then
        parts[#parts + 1] = string.format("%d stacked item(s)", info.count or 0)
        if info.priced then
            parts[#parts + 1] = "Total " .. FormatGold(info.totalValue)
        else
            local lib = rawget(_G, "LibPrice")
            if type(lib) ~= "table" then
                parts[#parts + 1] = "(LibPrice not loaded — values blank)"
            end
        end
    else
        parts[#parts + 1] = string.format("%d row(s)", info.count or 0)
        if info.priced then
            parts[#parts + 1] = "Total " .. FormatGold(info.totalValue)
        else
            local lib = rawget(_G, "LibPrice")
            if type(lib) ~= "table" then
                parts[#parts + 1] = "(LibPrice not loaded — values blank)"
            end
        end
    end
    return table.concat(parts, "   ·   ")
end

function MatLog.ShowHelp()
    showingHelp = true
    local lines = {
        { text = "MatLog — materials, surveys, and master writs you gather.", r = COL_HEADER[1], g = COL_HEADER[2], b = COL_HEADER[3] },
        { text = "Enable — record world loot, daily-writ coffer contents (including auto-loot by Lazy Writ Crafter), and hireling mail (including Take all into the craft bag). Player mail is not logged. Guild-store mail taken by itself is skipped; a mixed System-mail Take all may include those attachments as Hireling. Off keeps existing rows until they age out." },
        { text = "Kept for three daily-reset days. Use the day dropdown to switch." },
        { text = "Full — one row per item per character. Category is Writ (quest), Hireling (mail), or World (loot). The Category dropdown filters that column; the footer totals follow the filter." },
        { text = "Summary — stack by item across characters. Gold is inventory-style: stack total on top, unit price below." },
        { text = "Click a column header to sort. Click again to reverse. Gold sorts by stack total." },
        { text = "Does not track gold, vendor purchases, or guild-store buys." },
    }
    local totalsLabel = FillList(lines, true, false)
    if totalsLabel then
        totalsLabel:SetText("Help")
    end
end

local function ComboCallback(setter)
    return function(_combo, _text, choice)
        setter(choice and choice.value)
        showingHelp = false
        zo_callLater(function()
            RefreshFilterCombos()
            MatLog.RefreshReport()
        end, 1)
    end
end

local function RebuildCombo(combo, items, selectedValue, selectedText)
    if not combo then
        return
    end
    combo:ClearItems()
    for i = 1, #items do
        local item = items[i]
        local entry = combo:CreateItemEntry(item.text, ComboCallback(item.setter or function() end))
        entry.value = item.value
        combo:AddItem(entry)
        if item.value == selectedValue then
            combo:SetSelectedItem(item.text)
        end
    end
    if selectedText and combo.SetSelectedItem then
        combo:SetSelectedItem(selectedText)
    end
end

RefreshFilterCombos = function()
    local panel = GetPanel()
    if not panel then
        return
    end
    local dayCombo = ZO_ComboBox_ObjectFromContainer(Child(panel, "DayDrop"))
    local charCombo = ZO_ComboBox_ObjectFromContainer(Child(panel, "CharDrop"))
    local categoryCombo = ZO_ComboBox_ObjectFromContainer(Child(panel, "CategoryDrop"))
    local dayKeys = SortedDayKeys()
    if not selectedDayKey then
        selectedDayKey = CurrentDayKey()
    end
    local dayItems = {}
    for i = 1, #dayKeys do
        local key = dayKeys[i]
        dayItems[#dayItems + 1] = {
            text = FormatDayKey(key),
            value = key,
            setter = function(value)
                selectedDayKey = value
                selectedChar = "all"
                if saved then
                    saved.matlogDayKey = value
                    saved.matlogChar = "all"
                end
            end,
        }
    end
    if dayCombo then
        dayCombo:SetSortsItems(false)
        RebuildCombo(dayCombo, dayItems, selectedDayKey)
        dayCombo:SetSelectedItem(FormatDayKey(selectedDayKey))
    end

    local names = DayChars(selectedDayKey or CurrentDayKey())
    local charItems = {
        {
            text = "All characters",
            value = "all",
            setter = function(value)
                selectedChar = value
                if saved then
                    saved.matlogChar = value
                end
            end,
        },
    }
    for i = 1, #names do
        charItems[#charItems + 1] = {
            text = names[i],
            value = names[i],
            setter = function(value)
                selectedChar = value
                if saved then
                    saved.matlogChar = value
                end
            end,
        }
    end
    if charCombo then
        charCombo:SetSortsItems(false)
        RebuildCombo(charCombo, charItems, selectedChar)
        if selectedChar == "all" then
            charCombo:SetSelectedItem("All characters")
        else
            charCombo:SetSelectedItem(selectedChar)
        end
    end

    local categoryItems = {
        {
            text = "All categories",
            value = "all",
            setter = function(value)
                selectedCategory = value
                if saved then
                    saved.matlogCategory = value
                end
            end,
        },
    }
    local categoryOrder = { SOURCE_WRIT, SOURCE_HIRELING, SOURCE_WORLD }
    for i = 1, #categoryOrder do
        local value = categoryOrder[i]
        categoryItems[#categoryItems + 1] = {
            text = SOURCE_LABEL[value],
            value = value,
            setter = function(choice)
                selectedCategory = choice
                if saved then
                    saved.matlogCategory = choice
                end
            end,
        }
    end
    if categoryCombo then
        categoryCombo:SetSortsItems(false)
        RebuildCombo(categoryCombo, categoryItems, selectedCategory)
        if selectedCategory == "all" then
            categoryCombo:SetSelectedItem("All categories")
        else
            categoryCombo:SetSelectedItem(SOURCE_LABEL[selectedCategory] or "All categories")
        end
    end
end

local function BindPriceSourceCombo(panel)
    local combo = ZO_ComboBox_ObjectFromContainer(Child(panel, "PriceSourceDrop"))
    if not combo then
        return
    end
    local current = (saved and saved.matlogPriceSource) or "npc"
    local choices = {
        { text = "NPC vendor", value = "npc" },
        { text = "Tamriel Trade Centre", value = "ttc" },
        { text = "Master Merchant", value = "mm" },
    }
    combo:SetSortsItems(false)
    combo:ClearItems()
    for i = 1, #choices do
        local choice = choices[i]
        local entry = combo:CreateItemEntry(choice.text, function()
            if saved then
                saved.matlogPriceSource = choice.value
            end
            showingHelp = false
            MatLog.RefreshReport()
        end)
        entry.value = choice.value
        combo:AddItem(entry)
        if choice.value == current then
            combo:SetSelectedItem(choice.text)
        end
    end
end

local function BindCheck(control, label, tooltip, getFn, setFn)
    if not control then
        return
    end
    if not boundChecks[control] then
        ZO_CheckButton_SetLabelText(control, label)
        ZO_CheckButton_SetToggleFunction(control, function(button, checked)
            local on = checked
            if on == nil then
                on = ZO_CheckButton_IsChecked(control)
            end
            setFn(on and true or false)
        end)
        if tooltip then
            local tipLabel = control.label or Child(control, "Label")
            if tipLabel and tipLabel.SetHandler then
                tipLabel:SetHandler("OnMouseEnter", function()
                    ZO_Tooltips_ShowTextTooltip(tipLabel, TOP, tooltip)
                end)
                tipLabel:SetHandler("OnMouseExit", function()
                    ZO_Tooltips_HideTextTooltip()
                end)
            end
        end
        boundChecks[control] = true
    end
    if getFn() then
        ZO_CheckButton_SetChecked(control)
    else
        ZO_CheckButton_SetUnchecked(control)
    end
end

function MatLog.BindPanel(panel)
    if panel then
        boundPanel = panel
    end
    panel = GetPanel()
    if not panel then
        return
    end
    BindPriceSourceCombo(panel)
    panelBound = true
    BindCheck(
        Child(panel, "CheckEnable"),
        "Enable",
        "Record gathered materials, surveys, and master writs. Existing rows stay until they age out of the 3-day window.",
        function()
            return saved and saved.matlogEnabled ~= false
        end,
        function(checked)
            if saved then
                saved.matlogEnabled = checked and true or false
            end
            MatLog.SetEnabled(checked)
            showingHelp = false
            MatLog.RefreshReport()
        end
    )
    BindCheck(
        Child(panel, "CheckSummary"),
        "Summary",
        "Stack by item across characters. Gold shows stack total on top and unit price below. Unchecked is the full per-character list.",
        function()
            return saved and saved.matlogView == "summary"
        end,
        function(checked)
            if saved then
                saved.matlogView = checked and "summary" or "full"
            end
            showingHelp = false
            MatLog.RefreshReport()
        end
    )
    RefreshFilterCombos()
    RefreshHeaders()
end

function MatLog.SortBy(key)
    if type(key) ~= "string" or not SORT_KEYS[key] then
        return
    end
    if showingHelp then
        return
    end
    if sortHeaderGroup and sortHeaderGroup.HeaderForKey and sortHeaderGroup.OnHeaderClicked then
        local header = sortHeaderGroup:HeaderForKey(key)
        if header then
            sortHeaderGroup:OnHeaderClicked(header)
            return
        end
    end
    if sortKey == key then
        sortAsc = not sortAsc
    else
        sortKey = key
        sortAsc = (key ~= "value")
    end
    if saved then
        saved.matlogSortKey = sortKey
        saved.matlogSortAsc = sortAsc
    end
    MatLog.RefreshReport()
end

function BasaTools_MatLogSort(key)
    MatLog.SortBy(key)
end

function MatLog.OnPanelShown(panel)
    showingHelp = false
    MatLog.BindPanel(panel)
    MatLog.RefreshReport()
end

function MatLog.RefreshReport()
    if not panelBound then
        MatLog.BindPanel()
    end
    if showingHelp then
        return
    end
    local rows, info = CollectRows()
    if #rows == 0 then
        local totalsLabel = FillList({
            {
                text = "Nothing recorded for this day yet. Gather materials, surveys, or master writs with MatLog enabled.",
                r = COL_MUTED[1],
                g = COL_MUTED[2],
                b = COL_MUTED[3],
            },
        }, true, true)
        if totalsLabel then
            totalsLabel:SetText(TotalsText(info or {}))
        end
        return
    end
    local totalsLabel = FillList(rows, false, true)
    if totalsLabel then
        totalsLabel:SetText(TotalsText(info))
    end
end

function MatLog.Initialize(savedVars)
    saved = savedVars
    if saved then
        if type(saved.matlogDayKey) == "string" and saved.matlogDayKey ~= "" then
            selectedDayKey = saved.matlogDayKey
        end
        if type(saved.matlogChar) == "string" and saved.matlogChar ~= "" then
            selectedChar = saved.matlogChar
        end
        if saved.matlogCategory == SOURCE_WRIT or saved.matlogCategory == SOURCE_HIRELING or saved.matlogCategory == SOURCE_WORLD then
            selectedCategory = saved.matlogCategory
        else
            selectedCategory = "all"
        end
        if type(saved.matlogSortKey) == "string" and SORT_KEYS[saved.matlogSortKey] then
            sortKey = saved.matlogSortKey
        end
        if saved.matlogSortAsc ~= nil then
            sortAsc = saved.matlogSortAsc and true or false
        end
    end
    MigrateLogSources()
    PruneOldDays()
    MatLog.SetEnabled(saved and saved.matlogEnabled ~= false)
end

BasaTools.RegisterTab({
    id = "MatLog",
    title = "MatLog",
    tooltip = "Track gathered materials, surveys, and master writs.",
    texture = "EsoUI/Art/Inventory/inventory_tabIcon_crafting_up.dds",
    panelTemplate = "BasaToolsMatLogPanel",
    usesOutput = false,
    fillPanel = true,
    available = function()
        return true
    end,
    buildPanel = function(panel)
        MatLog.BindPanel(panel)
    end,
    onShown = function(panel)
        MatLog.OnPanelShown(panel)
    end,
    onInit = function(savedVars)
        MatLog.Initialize(savedVars)
    end,
    onHelp = function()
        MatLog.ShowHelp()
    end,
})
