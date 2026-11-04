-- MatLog item / writ-box classification.
local C = MatLog.C
local S = MatLog._

function MatLog.LooksLikeSurveyName(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    return string.find(string.lower(name), "survey", 1, true) ~= nil
end

function MatLog.LooksLikeMasterWritName(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    local lower = string.lower(name)
    if string.find(lower, "master writ", 1, true) then
        return true
    end
    return string.find(lower, "sealed", 1, true) ~= nil and string.find(lower, "writ", 1, true) ~= nil
end

function MatLog.ClassifyFromTypes(itemType, specializedType, name)
    if itemType == ITEMTYPE_MASTER_WRIT or specializedType == SPECIALIZED_ITEMTYPE_MASTER_WRIT then
        return "writ"
    end
    if specializedType == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT then
        return "survey"
    end
    if MatLog.LooksLikeSurveyName(name) then
        return "survey"
    end
    if MatLog.LooksLikeMasterWritName(name) then
        return "writ"
    end
    if C.MATERIAL_TYPES[itemType] then
        return "material"
    end
    return nil
end

function MatLog.ClassifyLink(link, name)
    if (not name or name == "") and type(link) == "string" and link ~= "" and type(GetItemLinkName) == "function" then
        name = GetItemLinkName(link)
    end
    if type(link) ~= "string" or link == "" then
        if MatLog.LooksLikeSurveyName(name) then
            return "survey"
        end
        if MatLog.LooksLikeMasterWritName(name) then
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
    return MatLog.ClassifyFromTypes(itemType, specializedType, name)
end

function MatLog.ClassifySlot(bagId, slotIndex)
    local itemType, specializedType
    if type(GetItemType) == "function" then
        itemType, specializedType = GetItemType(bagId, slotIndex)
    end
    local link = nil
    if type(GetItemLink) == "function" then
        link = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
    end
    local name = MatLog.ItemName(link)
    local kind = MatLog.ClassifyFromTypes(itemType, specializedType, name)
    if kind then
        return kind, link
    end
    return MatLog.ClassifyLink(link, name), link
end

function MatLog.EnsureWritBoxLookups()
    if S.writBoxFlavor then
        return
    end
    local flavors = {}
    local names = {}
    if type(GetItemLinkFlavorText) == "function" then
        for i = 1, #C.WRIT_BOX_FLAVOR_LINKS do
            local link = C.WRIT_BOX_FLAVOR_LINKS[i]
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
        S.writBoxFlavor = flavors
        S.writBoxNames = names
    end
end

function MatLog.LwcBoxCraftType(name)
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

function MatLog.IsWritRewardBoxName(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    local craft = MatLog.LwcBoxCraftType(name)
    if type(craft) == "number" then
        return craft > 0
    end
    MatLog.EnsureWritBoxLookups()
    return S.writBoxNames and S.writBoxNames[name] == true
end

function MatLog.IsWritRewardContainerLink(link)
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
    MatLog.EnsureWritBoxLookups()
    if type(GetItemLinkFlavorText) == "function" and S.writBoxFlavor then
        local flavor = GetItemLinkFlavorText(link)
        if type(flavor) == "string" and S.writBoxFlavor[flavor] then
            return true
        end
    end
    return MatLog.IsWritRewardBoxName(GetItemLinkName(link))
end

function MatLog.SlotIsWritRewardBox(bagId, slotIndex)
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
    return MatLog.IsWritRewardContainerLink(GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT))
end

function MatLog.KindColor(kind)
    local name = MatLog.KindName(kind)
    if name == "survey" then
        return C.COL_SURVEY
    end
    if name == "writ" then
        return C.COL_WRIT
    end
    return C.COL_MAT
end

function MatLog.SourceColor(source)
    if source == C.SOURCE_WRIT then
        return C.COL_WRIT
    end
    if source == C.SOURCE_WORLD then
        return C.COL_SURVEY
    end
    return C.COL_MAT
end

function MatLog.BackpackHasWritBox()
    local now = MatLog.NowMs()
    if now > 0 and (now - S.lastBoxScanMs) < C.BOX_SCAN_CACHE_MS then
        return S.lastBoxScanHit
    end
    S.lastBoxScanMs = now
    S.lastBoxScanHit = false
    if type(GetBagSize) ~= "function" then
        return false
    end
    local size = GetBagSize(BAG_BACKPACK) or 0
    for slot = 0, size - 1 do
        if MatLog.SlotIsWritRewardBox(BAG_BACKPACK, slot) then
            S.lastBoxScanHit = true
            return true
        end
    end
    return false
end

function MatLog.IsLootingNow()
    if type(IsLooting) == "function" and IsLooting() then
        return true
    end
    return type(GetInteractionType) == "function" and GetInteractionType() == INTERACTION_LOOT
end
