local ADDON_NAME = "WritMatch"

WritMatch = WritMatch or {}

local LLC_WW = "WritWorthy"
local LLC_LWC_MASTER = "DolgubonsLazyWritCreatorMaster"

--- Optional line sink (BasaTools). Chat always still goes to CHAT_ROUTER.
local outputSink = nil

local ownLLC = nil
local writStationByName = nil
local saved = nil
local MarkComplete
local KickImprove

local function StationLabel(station)
    local name = GetString("SI_TRADESKILLTYPE", station)
    if name and name ~= "" then
        return name
    end
    return tostring(station)
end

-- LLC queues are keyed by CRAFTING_TYPE_*. Walk those globals, not 1..7.
local function ForEachCraftingStation(fn)
    fn(CRAFTING_TYPE_BLACKSMITHING)
    fn(CRAFTING_TYPE_CLOTHIER)
    fn(CRAFTING_TYPE_ENCHANTING)
    fn(CRAFTING_TYPE_ALCHEMY)
    fn(CRAFTING_TYPE_PROVISIONING)
    fn(CRAFTING_TYPE_WOODWORKING)
    fn(CRAFTING_TYPE_JEWELRYCRAFTING)
end

function WritMatch.SetOutputSink(fn)
    if fn == nil or type(fn) == "function" then
        outputSink = fn
    end
end

local function Chat(msg)
    CHAT_ROUTER:AddSystemMessage(msg)
    if type(outputSink) == "function" then
        outputSink(msg)
    end
end

local function QualityName(quality)
    local name = GetString("SI_ITEMQUALITY", quality)
    if name and name ~= "" then
        return name
    end
    return tostring(quality)
end

local function TraitName(traitType)
    local name = GetString("SI_ITEMTRAITTYPE", traitType)
    if name and name ~= "" then
        return name
    end
    return tostring(traitType)
end

local function UniqueId(bagId, slotIndex)
    return Id64ToString(GetItemUniqueId(bagId, slotIndex))
end

local function BuildWritStationMap()
    if writStationByName then
        return writStationByName
    end
    writStationByName = {
        [GetItemLinkName("|H1:item:121532:6:1:0:0:0:26:194:5:178:15:34:0:0:0:0:0:0:0:0:883200|h|h")] = CRAFTING_TYPE_CLOTHIER,
        [GetItemLinkName("|H1:item:119680:6:1:0:0:0:47:188:4:240:12:29:0:0:0:0:0:0:0:0:56375|h|h")] = CRAFTING_TYPE_BLACKSMITHING,
        [GetItemLinkName("|H1:item:119682:6:1:0:0:0:65:192:4:95:14:47:0:0:0:0:0:0:0:0:63250|h|h")] = CRAFTING_TYPE_WOODWORKING,
        [GetItemLinkName("|H1:item:119564:5:1:0:0:0:26581:207:4:0:0:0:0:0:0:0:0:0:0:20000|h|h")] = CRAFTING_TYPE_ENCHANTING,
        [GetItemLinkName("|H1:item:119693:5:1:0:0:0:68276:0:0:0:0:0:0:0:0:0:0:0:0:0:20000|h|h")] = CRAFTING_TYPE_PROVISIONING,
        [GetItemLinkName("|H1:item:119705:5:1:0:0:0:199:19:3:15:0:0:0:0:0:0:0:0:0:0:50000|h|h")] = CRAFTING_TYPE_ALCHEMY,
        [GetItemLinkName("|H1:item:153737:5:1:0:0:0:18:255:4:439:33:0:0:0:0:0:0:0:0:0:346500|h|h")] = CRAFTING_TYPE_JEWELRYCRAFTING,
    }
    return writStationByName
end

local function IsSmithingStation(station)
    return station == CRAFTING_TYPE_BLACKSMITHING
        or station == CRAFTING_TYPE_CLOTHIER
        or station == CRAFTING_TYPE_WOODWORKING
        or station == CRAFTING_TYPE_JEWELRYCRAFTING
end

local function GetLLC(name)
    if not LibLazyCrafting or type(LibLazyCrafting.GetRequestingAddon) ~= "function" then
        return nil
    end
    return LibLazyCrafting:GetRequestingAddon(name)
end

local function EnsureOwnLLC()
    if ownLLC then
        return ownLLC
    end
    if not LibLazyCrafting or type(LibLazyCrafting.AddRequestingAddon) ~= "function" then
        return nil
    end
    ownLLC = LibLazyCrafting:AddRequestingAddon(ADDON_NAME, true, function(event, _station, result)
        if event == LLC_CRAFT_SUCCESS and result and result.reference then
            MarkComplete(tostring(result.reference))
        end
        if event == LLC_CRAFT_SUCCESS
            or event == LLC_CRAFT_PARTIAL_IMPROVEMENT
            or event == LLC_NO_FURTHER_CRAFT_POSSIBLE
        then
            KickImprove()
        end
    end)
    return ownLLC
end

local function KnownLLCTables()
    local tables = {}
    local ww = GetLLC(LLC_WW)
    local lwc = GetLLC(LLC_LWC_MASTER)
    if ww then
        tables[#tables + 1] = ww
    end
    if lwc then
        tables[#tables + 1] = lwc
    end
    return tables
end

local function AllLLCTables()
    local tables = KnownLLCTables()
    if ownLLC then
        tables[#tables + 1] = ownLLC
    end
    return tables
end

local function CancelAllByReference(uniqueId)
    local tables = AllLLCTables()
    for i = 1, #tables do
        tables[i]:cancelItemByReference(uniqueId)
    end
end

local function DequeueWritWorthy(uniqueId)
    if WritWorthyInventoryList and WritWorthyInventoryList.SaveChariableState then
        WritWorthyInventoryList.SaveChariableState(uniqueId, nil)
    end
end

local function EachLLCQueue(fn)
    local root = LibLazyCrafting and LibLazyCrafting.craftingQueue
    if not root then
        return
    end
    for addonName, stations in pairs(root) do
        if type(stations) == "table" then
            ForEachCraftingStation(function(station)
                local queue = stations[station]
                if type(queue) == "table" then
                    fn(addonName, station, queue)
                end
            end)
        end
    end
end

local function RequestHint(req)
    if not req then
        return "?"
    end
    local bits = { req.type or "?" }
    if req.ItemLink and req.ItemLink ~= "" then
        bits[#bits + 1] = req.ItemLink
    elseif req.link and req.link ~= "" then
        bits[#bits + 1] = req.link
    else
        if req.setIndex ~= nil then
            bits[#bits + 1] = "set=" .. tostring(req.setIndex)
        end
        if req.pattern ~= nil then
            bits[#bits + 1] = "pat=" .. tostring(req.pattern)
        end
        if req.quality ~= nil then
            bits[#bits + 1] = "q=" .. tostring(req.quality)
        end
        if req.style ~= nil then
            bits[#bits + 1] = "style=" .. tostring(req.style)
        end
    end
    if req.reference ~= nil and req.reference ~= "" then
        bits[#bits + 1] = "ref=" .. tostring(req.reference)
    end
    return table.concat(bits, " ")
end

local KICK_NAME = ADDON_NAME .. "Kick"
local kickPending = false
local kickTries = 0

local function CountOwnImproves()
    local queues = LibLazyCrafting and LibLazyCrafting.craftingQueue and LibLazyCrafting.craftingQueue[ADDON_NAME]
    if not queues then
        return 0
    end
    local n = 0
    ForEachCraftingStation(function(station)
        local queue = queues[station]
        if queue then
            for i = 1, #queue do
                if queue[i] and queue[i].type == "improvement" then
                    n = n + 1
                end
            end
        end
    end)
    return n
end

local function FindSlotByUniqueIdString(idStr)
    if not idStr or idStr == "" then
        return nil, nil
    end
    local bagId = BAG_BACKPACK
    for slotIndex = 0, GetBagSize(bagId) do
        local uid = GetItemUniqueId(bagId, slotIndex)
        if uid and Id64ToString(uid) == idStr then
            return bagId, slotIndex
        end
    end
    return nil, nil
end

local function RefreshImproveSlots()
    local queues = LibLazyCrafting and LibLazyCrafting.craftingQueue and LibLazyCrafting.craftingQueue[ADDON_NAME]
    if not queues then
        return
    end
    ForEachCraftingStation(function(station)
        local queue = queues[station]
        if queue then
            for i = 1, #queue do
                local req = queue[i]
                if req and req.type == "improvement" then
                    local idStr = req.itemStringUniqueId
                    if (not idStr or idStr == "") and req.itemUniqueId then
                        idStr = Id64ToString(req.itemUniqueId)
                    end
                    local bagId, slotIndex = FindSlotByUniqueIdString(idStr)
                    if bagId then
                        req.ItemBagID = bagId
                        req.ItemSlotID = slotIndex
                    end
                end
            end
        end
    end)
end

local function TryKick()
    kickTries = kickTries + 1
    if GetCraftingInteractionType() == CRAFTING_TYPE_INVALID or CountOwnImproves() == 0 then
        kickPending = false
        EVENT_MANAGER:UnregisterForUpdate(KICK_NAME)
        return
    end
    local busy = ZO_CraftingUtils_IsPerformingCraftProcess()
        or (LibLazyCrafting.isCurrentlyCrafting and LibLazyCrafting.isCurrentlyCrafting[1])
    if busy then
        if kickTries >= 12 then
            kickPending = false
            EVENT_MANAGER:UnregisterForUpdate(KICK_NAME)
        end
        return
    end
    RefreshImproveSlots()
    kickPending = false
    EVENT_MANAGER:UnregisterForUpdate(KICK_NAME)
    LibLazyCrafting.craftInteract(nil, GetCraftingInteractionType())
end

KickImprove = function()
    if kickPending or CountOwnImproves() == 0 then
        return
    end
    kickPending = true
    kickTries = 0
    EVENT_MANAGER:UnregisterForUpdate(KICK_NAME)
    EVENT_MANAGER:RegisterForUpdate(KICK_NAME, 300, TryKick)
end

local function LwcSettings()
    if WritCreater and type(WritCreater.GetSettings) == "function" then
        return WritCreater:GetSettings()
    end
    return nil
end

local function LwcAutoCraftOn()
    local settings = LwcSettings()
    return settings and settings.autoCraft == true
end

local EXPERTISE_TEXTURE = {
    [CRAFTING_TYPE_BLACKSMITHING] = "/esoui/art/icons/ability_smith_004.dds",
    [CRAFTING_TYPE_CLOTHIER] = "/esoui/art/icons/ability_tradecraft_004.dds",
    [CRAFTING_TYPE_WOODWORKING] = "/esoui/art/icons/ability_tradecraft_001.dds",
    [CRAFTING_TYPE_JEWELRYCRAFTING] = "/esoui/art/icons/passive_platingexpertise.dds",
}

local EXPERTISE_NAME = {
    [CRAFTING_TYPE_BLACKSMITHING] = "Temper Expertise",
    [CRAFTING_TYPE_CLOTHIER] = "Tannin Expertise",
    [CRAFTING_TYPE_WOODWORKING] = "Rosin Expertise",
    [CRAFTING_TYPE_JEWELRYCRAFTING] = "Plating Expertise",
}

local function GetExpertiseRank(station)
    local manager = SKILLS_DATA_MANAGER
    local skillLine = manager and manager.GetCraftingSkillLineData and manager:GetCraftingSkillLineData(station)
    if not skillLine then
        return 0, 1
    end
    local skillType, skillIndex = skillLine:GetIndices()
    local want = EXPERTISE_TEXTURE[station]
    if not want then
        return 0, 1
    end
    for i = 1, GetNumSkillAbilities(skillType, skillIndex) do
        local _, texture = GetSkillAbilityInfo(skillType, skillIndex, i)
        if texture == want then
            local current, maxRank = GetSkillAbilityUpgradeInfo(skillType, skillIndex, i)
            return current or 0, maxRank or 1
        end
    end
    return 0, 1
end

local function WarnExpertise(station)
    if not station or not EXPERTISE_NAME[station] then
        return
    end
    local current, maxRank = GetExpertiseRank(station)
    if current ~= maxRank then
        Chat(string.format(
            "WritMatch: %s is %d/%d. LLC will improve once (to green) then stop to save mats. Max that passive and use the table again.",
            EXPERTISE_NAME[station],
            current,
            maxRank
        ))
    end
end

-- Craft-new requests are type "smithing". Leave improvement / deconstruct / glyphs.
local function CancelAllCraftNew()
    local n = 0
    EachLLCQueue(function(_, _, queue)
        local i = 1
        while i <= #queue do
            local req = queue[i]
            if req and req.type == "smithing" then
                table.remove(queue, i)
                n = n + 1
            else
                i = i + 1
            end
        end
    end)
    return n
end

local function ClearWritWorthyQueuedFlags()
    local n = 0
    if not (WritWorthy and WritWorthy.savedChariables and WritWorthy.savedChariables.writ_unique_id) then
        return 0
    end
    for uniqueId, row in pairs(WritWorthy.savedChariables.writ_unique_id) do
        if row and row.state == "queued" then
            WritWorthyInventoryList.SaveChariableState(uniqueId, nil)
            n = n + 1
        end
    end
    return n
end

local function IsAlreadyComplete(uniqueId)
    if WritCreater and WritCreater.savedVarsAccountWide and WritCreater.savedVarsAccountWide.craftedMasterWrits
        and WritCreater.savedVarsAccountWide.craftedMasterWrits[uniqueId]
    then
        return true
    end
    if WritWorthy and WritWorthy.savedChariables and WritWorthy.savedChariables.writ_unique_id then
        local row = WritWorthy.savedChariables.writ_unique_id[uniqueId]
        if row and row.state == "completed" then
            return true
        end
    end
    return false
end

MarkComplete = function(uniqueId)
    if WritCreater and WritCreater.savedVarsAccountWide then
        WritCreater.savedVarsAccountWide.craftedMasterWrits = WritCreater.savedVarsAccountWide.craftedMasterWrits or {}
        WritCreater.savedVarsAccountWide.craftedMasterWrits[uniqueId] = true
    end
    if WritWorthyInventoryList and WritWorthyInventoryList.SaveChariableState then
        WritWorthyInventoryList.SaveChariableState(uniqueId, "completed")
        local list = WritWorthyInventoryList.singleton
        if list then
            local data = list.UniqueIDToInventoryData and list:UniqueIDToInventoryData(uniqueId)
            if data then
                data.ui_is_completed = true
                if list.UpdateUISoon then
                    list:UpdateUISoon(data)
                end
            elseif list.Refresh then
                list:Refresh()
            end
        end
    end
    CancelAllByReference(uniqueId)
end

local function RefreshBackpackIcons()
    if PLAYER_INVENTORY and PLAYER_INVENTORY.UpdateList then
        PLAYER_INVENTORY:UpdateList(INVENTORY_BACKPACK)
    end
end

local function ParseSmithingWrit(link)
    local x = { ZO_LinkHandler_ParseLink(link) }
    return {
        templateId = tonumber(x[10]),
        quality = tonumber(x[12]),
        setIndex = tonumber(x[13]),
        traitType = tonumber(x[14]),
        styleId = tonumber(x[15]),
    }
end

local function ExpectedItemLink(parsed, station)
    if not parsed.templateId or not parsed.setIndex or not parsed.traitType or not station then
        return nil
    end
    local pattern = LibLazyCrafting.GetItemTemplateIdPatternIndex(parsed.templateId)
    if not pattern then
        return nil
    end
    local getter = LibLazyCrafting.getItemLinkFromParticulars
    if type(getter) ~= "function" then
        return nil
    end
    return getter(pattern, true, 150, parsed.styleId, parsed.traitType + 1, station, parsed.setIndex, 1)
end

local function WantString(parsed, expectedLink)
    local itemName = expectedLink and GetItemLinkName(expectedLink) or ("template " .. tostring(parsed.templateId))
    local hasSet, setName = false, nil
    if expectedLink then
        hasSet, setName = GetItemLinkSetInfo(expectedLink, false)
    end
    local style = ""
    if parsed.styleId and parsed.styleId > 0 then
        style = GetItemStyleName(parsed.styleId) or ""
    end
    local parts = {}
    if hasSet and setName and setName ~= "" then
        parts[#parts + 1] = setName
    end
    parts[#parts + 1] = itemName
    parts[#parts + 1] = TraitName(parsed.traitType)
    if style ~= "" then
        parts[#parts + 1] = style
    end
    parts[#parts + 1] = QualityName(parsed.quality)
    return table.concat(parts, ", ")
end

local function ItemMatchesWrit(itemLink, expectedLink, parsed)
    if not expectedLink or expectedLink == "" then
        return false
    end
    if GetItemLinkItemId(itemLink) ~= GetItemLinkItemId(expectedLink) then
        return false
    end
    local traitType = GetItemLinkTraitInfo(itemLink)
    if traitType ~= parsed.traitType then
        return false
    end
    if parsed.styleId and parsed.styleId > 0 then
        if GetItemLinkItemStyle(itemLink) ~= parsed.styleId then
            return false
        end
    end
    return true
end

local function IsPlayerCrafted(bagId, slotIndex, itemLink)
    if not IsItemLinkCrafted(itemLink) then
        return false
    end
    local creator = GetItemCreatorName(bagId, slotIndex)
    return creator == GetUnitName("player")
end

local function ScanBackpackWritIds()
    local ids = {}
    local bagId = BAG_BACKPACK
    for slotIndex = 0, GetBagSize(bagId) do
        if GetItemType(bagId, slotIndex) == ITEMTYPE_MASTER_WRIT then
            ids[UniqueId(bagId, slotIndex)] = true
        end
    end
    return ids
end

local function CollectOrphans()
    local haveWrit = ScanBackpackWritIds()
    local orphans = {}
    local names = { LLC_WW, LLC_LWC_MASTER, ADDON_NAME }
    for n = 1, #names do
        local llc = GetLLC(names[n])
        if llc and llc.personalQueue then
            ForEachCraftingStation(function(station)
                local queue = llc.personalQueue[station]
                if queue then
                    for i = 1, #queue do
                        local req = queue[i]
                        local ref = req and req.reference
                        if type(ref) == "string" and ref ~= "" and not haveWrit[ref] then
                            orphans[#orphans + 1] = {
                                addon = names[n],
                                reference = ref,
                                request = req,
                            }
                        end
                    end
                end
            end)
        end
    end
    return orphans
end

local function OrphanHint(req)
    if not req then
        return ""
    end
    if req.ItemLink and req.ItemLink ~= "" then
        return req.ItemLink
    end
    if req.link and req.link ~= "" then
        return req.link
    end
    if req.setIndex then
        return "set " .. tostring(req.setIndex)
    end
    return ""
end

local function QueueImprove(uniqueId, bagId, slotIndex, quality)
    DequeueWritWorthy(uniqueId)
    CancelAllByReference(uniqueId)
    local target = EnsureOwnLLC()
    if not target or type(target.ImproveSmithingItem) ~= "function" then
        return false
    end
    target:ImproveSmithingItem(bagId, slotIndex, quality, true, uniqueId)
    return true
end

local function CollectWritsAndGear()
    local stations = BuildWritStationMap()
    local writs = {}
    local unsupported = {}
    local gear = {}
    local bagId = BAG_BACKPACK
    for slotIndex = 0, GetBagSize(bagId) do
        local itemType = GetItemType(bagId, slotIndex)
        if itemType == ITEMTYPE_MASTER_WRIT then
            local link = GetItemLink(bagId, slotIndex)
            local uniqueId = UniqueId(bagId, slotIndex)
            local station = stations[GetItemLinkName(link)]
            if IsSmithingStation(station) then
                writs[#writs + 1] = {
                    bagId = bagId,
                    slotIndex = slotIndex,
                    link = link,
                    uniqueId = uniqueId,
                    station = station,
                    parsed = ParseSmithingWrit(link),
                    already = IsAlreadyComplete(uniqueId),
                }
            elseif station then
                unsupported[#unsupported + 1] = link
            end
        elseif itemType ~= ITEMTYPE_NONE then
            local link = GetItemLink(bagId, slotIndex)
            if link and link ~= "" and IsPlayerCrafted(bagId, slotIndex, link) then
                gear[#gear + 1] = {
                    bagId = bagId,
                    slotIndex = slotIndex,
                    link = link,
                    used = false,
                    quality = GetItemLinkFunctionalQuality(link),
                }
            end
        end
    end
    return writs, gear, unsupported
end

local function FindGear(writ, gear)
    local expected = ExpectedItemLink(writ.parsed, writ.station)
    writ.expectedLink = expected
    local best, bestKind = nil, nil
    for i = 1, #gear do
        local item = gear[i]
        if not item.used and ItemMatchesWrit(item.link, expected, writ.parsed) then
            if item.quality >= writ.parsed.quality then
                return item, "complete", expected
            end
            if not best or item.quality > best.quality then
                best = item
                bestKind = "improve"
            end
        end
    end
    return best, bestKind, expected
end

local function PrintGroup(title, lines)
    if #lines == 0 then
        return
    end
    Chat(title)
    for i = 1, #lines do
        Chat("  " .. lines[i])
    end
end

local function Reconcile()
    if not LibLazyCrafting then
        Chat("WritMatch: LibLazyCrafting is not loaded.")
        return
    end

    local writs, gear, unsupported = CollectWritsAndGear()
    local completeLines = {}
    local improveLines = {}
    local unmatchedLines = {}
    local alreadyN = 0

    for i = 1, #writs do
        local writ = writs[i]
        if writ.already then
            alreadyN = alreadyN + 1
            -- LWC may have marked complete while WritWorthy still says queued.
            MarkComplete(writ.uniqueId)
        else
            local item, kind = FindGear(writ, gear)
            if kind == "complete" then
                item.used = true
                MarkComplete(writ.uniqueId)
                completeLines[#completeLines + 1] = writ.link .. " → " .. item.link
            elseif kind == "improve" then
                item.used = true
                local queued = QueueImprove(writ.uniqueId, item.bagId, item.slotIndex, writ.parsed.quality)
                local extra = queued and "queued" or "could not queue"
                improveLines[#improveLines + 1] = string.format(
                    "%s → %s  %s → %s (%s)",
                    writ.link,
                    item.link,
                    QualityName(item.quality),
                    QualityName(writ.parsed.quality),
                    extra
                )
            else
                DequeueWritWorthy(writ.uniqueId)
                CancelAllByReference(writ.uniqueId)
                unmatchedLines[#unmatchedLines + 1] = writ.link .. "  " .. WantString(writ.parsed, writ.expectedLink)
            end
        end
    end

    local orphans = CollectOrphans()
    local orphanLines = {}
    for i = 1, #orphans do
        local hint = OrphanHint(orphans[i].request)
        if hint ~= "" then
            orphanLines[#orphanLines + 1] = orphans[i].addon .. "  " .. hint
        else
            orphanLines[#orphanLines + 1] = orphans[i].addon
        end
    end

    RefreshBackpackIcons()

    local changed = #completeLines + #improveLines + #unmatchedLines + #orphanLines
    if changed == 0 then
        Chat(string.format("WritMatch: nothing to do (%d already complete).", alreadyN))
        if #unsupported > 3 then
            Chat(string.format("  %d non-smithing sealed writs ignored.", #unsupported))
        elseif #unsupported > 0 then
            Chat("  Ignored: " .. table.concat(unsupported, " "))
        end
        return
    end

    Chat("WritMatch")
    PrintGroup("Complete", completeLines)
    PrintGroup("Improve (queued)", improveLines)
    PrintGroup("Unmatched", unmatchedLines)
    PrintGroup("Orphans (still queued, writ not in bag)", orphanLines)

    local tally = string.format(
        "%d complete, %d improve queued, %d unmatched, %d orphan.",
        #completeLines,
        #improveLines,
        #unmatchedLines,
        #orphanLines
    )
    if alreadyN > 0 then
        tally = tally .. string.format(" %d already complete.", alreadyN)
    end
    if #orphanLines > 0 then
        tally = tally .. " /writmatch orphans to drop orphans."
    end
    if #unsupported > 3 then
        tally = tally .. string.format(" %d non-smithing ignored.", #unsupported)
    elseif #unsupported > 0 then
        Chat("Ignored: " .. table.concat(unsupported, " "))
    end
    Chat(tally)
    if LwcAutoCraftOn() then
        Chat("WritMatch: Lazy Writ auto-craft is ON. A wood table will craft daily generic bows/staves. /writmatch hold first.")
    end
    if #improveLines > 0 then
        WarnExpertise(CRAFTING_TYPE_WOODWORKING)
        WarnExpertise(CRAFTING_TYPE_BLACKSMITHING)
        WarnExpertise(CRAFTING_TYPE_CLOTHIER)
        WarnExpertise(CRAFTING_TYPE_JEWELRYCRAFTING)
    end
end

local function DumpQueues()
    if not LibLazyCrafting then
        Chat("WritMatch: LibLazyCrafting is not loaded.")
        return
    end
    Chat("WritMatch queues")
    Chat(string.format("  LWC auto-craft: %s", LwcAutoCraftOn() and "ON" or "off"))
    if saved and saved.heldAutoCraft then
        Chat("  hold: active (resume will turn auto-craft back on)")
    end
    local total, smithingN, improveN = 0, 0, 0
    EachLLCQueue(function(addonName, station, queue)
        for i = 1, #queue do
            local req = queue[i]
            if req then
                total = total + 1
                if req.type == "smithing" then
                    smithingN = smithingN + 1
                elseif req.type == "improvement" then
                    improveN = improveN + 1
                end
                local tag = (req.type == "improvement") and "improve" or "NEW"
                Chat(string.format(
                    "  [%s] %s  %s  %s",
                    tag,
                    addonName,
                    StationLabel(station),
                    RequestHint(req)
                ))
            end
        end
    end)
    if total == 0 then
        Chat("  (empty)")
    else
        Chat(string.format("%d LLC job(s): %d craft-new, %d improve.", total, smithingN, improveN))
    end
    if improveN > 0 then
        WarnExpertise(CRAFTING_TYPE_WOODWORKING)
        WarnExpertise(CRAFTING_TYPE_BLACKSMITHING)
        WarnExpertise(CRAFTING_TYPE_CLOTHIER)
        WarnExpertise(CRAFTING_TYPE_JEWELRYCRAFTING)
    end
end

local function CancelCraftNews()
    local wwFlags = 0
    if WritWorthyInventoryList and WritWorthyInventoryList.SaveChariableState then
        wwFlags = ClearWritWorthyQueuedFlags()
        local list = WritWorthyInventoryList.singleton
        if list and list.Refresh then
            list:Refresh()
        end
    end
    local dropped = CancelAllCraftNew()
    Chat(string.format(
        "WritMatch: cleared %d WritWorthy queued flag(s), dropped %d craft-new LLC job(s). Improvement jobs kept.",
        wwFlags,
        dropped
    ))
    if LwcAutoCraftOn() then
        Chat("WritMatch: Lazy Writ auto-craft is still ON — daily writs will re-queue at the station. /writmatch hold")
    end
end

local function HoldDaily()
    local settings = LwcSettings()
    if settings then
        if settings.autoCraft then
            settings.autoCraft = false
            if saved then
                saved.heldAutoCraft = true
            end
            Chat("WritMatch: Lazy Writ auto-craft turned OFF so daily generic items will not craft.")
        elseif saved and saved.heldAutoCraft then
            Chat("WritMatch: Lazy Writ auto-craft already held off.")
        else
            Chat("WritMatch: Lazy Writ auto-craft was already off.")
        end
    else
        Chat("WritMatch: Lazy Writ not loaded; skipped daily hold.")
    end
    if WritCreater then
        if WritCreater.LLCInteraction then
            WritCreater.LLCInteraction:cancelItem()
        end
        if WritCreater.LLCInteractionMultiplicator then
            WritCreater.LLCInteractionMultiplicator:cancelItem()
        end
        if WritCreater.pomotionalLLC then
            WritCreater.pomotionalLLC:cancelItem()
        end
    end
    CancelCraftNews()
    Chat("WritMatch: /writmatch next, then station. /writmatch resume when the improve pass is done.")
end

local function ResumeDaily()
    local settings = LwcSettings()
    if saved and saved.heldAutoCraft and settings then
        settings.autoCraft = true
        saved.heldAutoCraft = false
        Chat("WritMatch: Lazy Writ auto-craft turned back ON.")
    else
        Chat("WritMatch: not holding Lazy Writ auto-craft (leave LWC settings as they are).")
    end
end

local function CancelOrphans()
    local orphans = CollectOrphans()
    if #orphans == 0 then
        Chat("WritMatch: no orphaned LLC jobs.")
        return
    end
    Chat("WritMatch")
    local cancelled = 0
    for i = 1, #orphans do
        local llc = GetLLC(orphans[i].addon)
        if llc then
            llc:cancelItemByReference(orphans[i].reference)
            cancelled = cancelled + 1
            local hint = OrphanHint(orphans[i].request)
            if hint ~= "" then
                Chat("  dropped " .. orphans[i].addon .. "  " .. hint)
            else
                Chat("  dropped " .. orphans[i].addon)
            end
        end
    end
    Chat(string.format("%d orphaned LLC job(s) cancelled.", cancelled))
end

function WritMatch.GetHelpText()
    return table.concat({
        "WritMatch — reconcile sealed master writs with backpack gear.",
        "",
        "Requires LibLazyCrafting. Optional: WritWorthy, Dolgubon's Lazy Writ Crafter.",
        "Smithing only (blacksmith, clothier, woodworking, jewelry). Backpack only.",
        "",
        "Buttons / slash (/writmatch …):",
        "  Reconcile  — /writmatch           mark complete, queue improve, list unmatched/orphans",
        "  Hold       — /writmatch hold      turn off Lazy Writ autoCraft; drop craft-new jobs",
        "  Resume     — /writmatch resume    restore autoCraft if we turned it off",
        "  Crafts     — /writmatch crafts    clear WritWorthy queued + craft-new only",
        "  Queues     — /writmatch queues    dump every LLC job",
        "  Kick       — /writmatch kick      restart improve after LLC stalls (at a station)",
        "  Orphans    — /writmatch orphans   cancel LLC jobs whose sealed writ is gone",
        "",
        "Chat keeps item links. This pane uses plain names so you can select and copy.",
        "If LLC improves once then stops: max the station expertise passive, then Kick at the table.",
    }, "\n")
end

function WritMatch.Run(op)
    op = zo_strtrim(tostring(op or ""))
    if op == "orphans" then
        CancelOrphans()
    elseif op == "crafts" then
        CancelCraftNews()
    elseif op == "hold" then
        HoldDaily()
    elseif op == "resume" then
        ResumeDaily()
    elseif op == "queues" then
        DumpQueues()
    elseif op == "kick" then
        if GetCraftingInteractionType() == CRAFTING_TYPE_INVALID then
            Chat("WritMatch: interact with a station first.")
        else
            KickImprove()
            Chat("WritMatch: kicking improve queue.")
        end
    elseif op == "" or op == "reconcile" then
        Reconcile()
    else
        Chat("WritMatch: /writmatch  |  hold  |  crafts  |  queues  |  kick  |  orphans  |  resume")
    end
end

local function OnSlash(args)
    args = zo_strtrim(args or "")
    if args == "" then
        WritMatch.Run("reconcile")
    else
        WritMatch.Run(args)
    end
end

local function OnAddOnLoaded(_, name)
    if name ~= ADDON_NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    saved = ZO_SavedVars:NewAccountWide("WritMatchSaved", 1, nil, { heldAutoCraft = false })
    SLASH_COMMANDS["/writmatch"] = OnSlash
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CRAFT_COMPLETED, function()
        KickImprove()
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
