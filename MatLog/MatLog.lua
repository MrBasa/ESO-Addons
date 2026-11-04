-- MatLog entry: SavedVars, init, public API glue.
local C = MatLog.C
local S = MatLog._

function MatLog.Initialize(savedVars)
    S.saved = savedVars
    if S.saved then
        if type(S.saved.matlogDayKey) == "string" and S.saved.matlogDayKey ~= "" then
            S.selectedDayKey = S.saved.matlogDayKey
        end
        if type(S.saved.matlogChar) == "string" and S.saved.matlogChar ~= "" then
            S.selectedChar = S.saved.matlogChar
        end
        if S.saved.matlogCategory == C.SOURCE_WRIT
            or S.saved.matlogCategory == C.SOURCE_HIRELING
            or S.saved.matlogCategory == C.SOURCE_WORLD
        then
            S.selectedCategory = S.saved.matlogCategory
        else
            S.selectedCategory = "all"
        end
        if type(S.saved.matlogSortKey) == "string" and C.SORT_KEYS[S.saved.matlogSortKey] then
            S.sortKey = S.saved.matlogSortKey
        end
        if S.saved.matlogSortAsc ~= nil then
            S.sortAsc = S.saved.matlogSortAsc and true or false
        end
    end
    MatLog.LoadLogFromSaved()
    MatLog.PruneOldDays()
    MatLog.SetEnabled(S.saved and S.saved.matlogEnabled ~= false)
end

EVENT_MANAGER:RegisterForEvent(C.ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= C.ADDON_NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(C.ADDON_NAME, EVENT_ADD_ON_LOADED)

    local defaults = {
        matlogEnabled = true,
        matlogView = "full",
        matlogPriceSource = "npc",
        matlogDayKey = nil,
        matlogChar = "all",
        matlogCategory = "all",
        matlogSortKey = "item",
        matlogSortAsc = true,
        matlogEncoded = {},
        matlog = nil,
    }
    local profile = nil
    if type(GetWorldName) == "function" then
        local world = GetWorldName()
        if type(world) == "string" and world ~= "" then
            profile = world
        end
    end
    local displayName = nil
    if type(GetDisplayName) == "function" then
        local name = GetDisplayName()
        if type(name) == "string" and name ~= "" then
            displayName = name
        end
    end
    S.saved = ZO_SavedVars:NewAccountWide("MatLogSaved", C.SV_VERSION, nil, defaults, profile, displayName)
    MatLog.Initialize(S.saved)

    EVENT_MANAGER:RegisterForEvent(C.ADDON_NAME .. "Deactivated", EVENT_PLAYER_DEACTIVATED, function()
        MatLog.PersistLog()
    end)

    local logger = BasaTools.GetLogger(C.ADDON_NAME)
    logger:Info("loaded")
end)
