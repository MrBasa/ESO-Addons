-- MatLog data layer: compact rows, LibDataEncode persist, day/char keys.
local C = MatLog.C
local S = MatLog._

function MatLog.Child(parent, name)
    if BasaTools and BasaTools.Child then
        return BasaTools.Child(parent, name)
    end
    if parent and parent.GetNamedChild then
        return parent:GetNamedChild(name)
    end
    return nil
end

function MatLog.GetPanel()
    if S.boundPanel then
        return S.boundPanel
    end
    local win = BasaTools and BasaTools.GetWindow and BasaTools.GetWindow()
    return MatLog.Child(win, "PanelMatLog")
end

function MatLog.LogTable()
    if type(S.log) ~= "table" then
        S.log = {}
    end
    return S.log
end

function MatLog.MarkLogDirty()
    S.logDirty = true
    MatLog.ScheduleEncode()
end

function MatLog.ScheduleEncode()
    if not S.saved then
        return
    end
    S.encodeToken = (S.encodeToken or 0) + 1
    local token = S.encodeToken
    local delay = C.ENCODE_DEBOUNCE_MS
    local function apply()
        if token ~= S.encodeToken then
            return
        end
        MatLog.PersistLog()
    end
    if type(zo_callLater) == "function" then
        zo_callLater(apply, delay)
    else
        apply()
    end
end

function MatLog.PersistLog()
    if not S.saved or not S.logDirty then
        return
    end
    local encoded = LibDataEncode.Encode(S.log, true, C.LDE_GLOBAL_DICT)
    S.saved.matlogEncoded = encoded
    S.saved.matlog = nil
    S.logDirty = false
end

function MatLog.LoadLogFromSaved()
    S.log = {}
    if not S.saved then
        return
    end
    -- Only matlogEncoded is supported (plain compact import was one-shot / removed).
    S.saved.matlog = nil
    local encoded = S.saved.matlogEncoded
    if type(encoded) ~= "table" or #encoded == 0 then
        return
    end
    local data = LibDataEncode.Decode(encoded, C.LDE_GLOBAL_DICT)
    if type(data) == "table" then
        S.log = data
    end
end

function MatLog.GetAnchorTime()
    local offset = 0
    if TIMED_ACTIVITIES_MANAGER and TIMED_ACTIVITIES_MANAGER.GetTimedActivityTypeTimeRemainingSeconds then
        offset = TIMED_ACTIVITIES_MANAGER:GetTimedActivityTypeTimeRemainingSeconds(TIMED_ACTIVITY_TYPE_WEEKLY) or 0
    end
    if offset == 0 and type(GetTimeUntilNextDailyLoginRewardClaimS) == "function" then
        offset = GetTimeUntilNextDailyLoginRewardClaimS() or 0
    end
    return zo_round((GetTimeStamp() + offset) / 120) * 120
end

function MatLog.PreviousResetTime()
    local intervals = zo_floor((GetTimeStamp() - MatLog.GetAnchorTime()) / C.DAY_LENGTH)
    return MatLog.GetAnchorTime() + intervals * C.DAY_LENGTH
end

function MatLog.CurrentDayKey()
    return tostring(MatLog.PreviousResetTime())
end

function MatLog.FormatDayKey(dayKey)
    local ts = tonumber(dayKey)
    if not ts then
        return tostring(dayKey or "")
    end
    if dayKey == MatLog.CurrentDayKey() then
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

function MatLog.CharName()
    if type(GetUnitName) == "function" then
        local name = GetUnitName("player")
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    return "Unknown"
end

function MatLog.MailKey(mailId)
    if type(Id64ToString) == "function" then
        return Id64ToString(mailId)
    end
    return tostring(mailId)
end

function MatLog.NormalizeSource(source)
    if source == C.SOURCE_WRIT or source == C.SOURCE_HIRELING or source == C.SOURCE_WORLD then
        return source
    end
    return C.SOURCE_HIRELING
end

function MatLog.SourceCode(source)
    return C.SOURCE_CODE[MatLog.NormalizeSource(source)] or "h"
end

function MatLog.SourceFromKey(key)
    if type(key) ~= "string" then
        return C.SOURCE_HIRELING
    end
    local code = string.match(key, "^([who]):")
    return C.SOURCE_FROM_CODE[code] or C.SOURCE_HIRELING
end

function MatLog.ItemIdFromLink(link)
    if type(link) == "string" and link ~= "" and type(GetItemLinkItemId) == "function" then
        local itemId = GetItemLinkItemId(link)
        if itemId and itemId ~= 0 then
            return itemId
        end
    end
    return nil
end

function MatLog.ItemIdFromKey(key)
    if type(key) ~= "string" then
        return nil
    end
    local id = string.match(key, "^[who]:(%d+)$")
    return id and tonumber(id) or nil
end

function MatLog.CompactKey(link, source)
    local itemId = MatLog.ItemIdFromLink(link)
    if not itemId then
        return nil
    end
    return MatLog.SourceCode(source) .. ":" .. tostring(itemId)
end

function MatLog.KindEnum(kind)
    if type(kind) == "number" then
        return kind
    end
    return C.KIND_FROM_NAME[kind] or C.KIND_MATERIAL
end

function MatLog.KindName(kind)
    if type(kind) == "string" then
        return kind
    end
    return C.KIND_TO_NAME[kind] or "material"
end

-- Zeroed-quality link rebuilt from item id (matches prior stored form).
function MatLog.LinkFromItemId(itemId)
    if type(itemId) ~= "number" or itemId <= 0 then
        return nil
    end
    return string.format("|H0:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId)
end

function MatLog.RowLink(key, row)
    local itemId = MatLog.ItemIdFromKey(key)
    if itemId then
        return MatLog.LinkFromItemId(itemId)
    end
    return nil
end

function MatLog.SanitizeItemName(name)
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

function MatLog.ItemName(link, fallback)
    local name
    if type(link) == "string" and link ~= "" and type(GetItemLinkName) == "function" then
        name = GetItemLinkName(link)
    end
    if type(name) ~= "string" or name == "" then
        name = fallback
    end
    name = MatLog.SanitizeItemName(name)
    if type(name) == "string" and name ~= "" then
        return name
    end
    return "Item"
end

function MatLog.PriceGold(link)
    if type(link) ~= "string" or link == "" then
        return nil
    end
    local lib = rawget(_G, "LibPrice")
    if type(lib) ~= "table" or type(lib.ItemLinkToPriceGold) ~= "function" then
        return nil
    end
    local source = (S.saved and S.saved.matlogPriceSource) or "npc"
    local gold = lib.ItemLinkToPriceGold(link, source)
    if type(gold) ~= "number" then
        gold = lib.ItemLinkToPriceGold(link)
    end
    if type(gold) == "number" then
        return gold
    end
    return nil
end

function MatLog.FormatGold(amount)
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

function MatLog.HexRGB(rgb)
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

function MatLog.ColorGoldText(text, rgb)
    if type(text) ~= "string" or text == "" then
        return ""
    end
    local num, icon = string.match(text, "^([^|]+)(|t.*)$")
    local hex = MatLog.HexRGB(rgb)
    if num and icon then
        return "|c" .. hex .. num .. "|r" .. icon
    end
    return "|c" .. hex .. text .. "|r"
end

function MatLog.EnsureCharBucket(dayKey, charName)
    local log = MatLog.LogTable()
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

function MatLog.NowMs()
    if type(GetFrameTimeMilliseconds) == "function" then
        return GetFrameTimeMilliseconds()
    end
    return 0
end

function MatLog.AddItem(link, count, name, source, kind)
    if type(count) ~= "number" or count == 0 then
        return false
    end
    kind = kind or MatLog.ClassifyLink(link, name)
    if not kind then
        return false
    end
    source = MatLog.NormalizeSource(source)
    local key = MatLog.CompactKey(link, source)
    if not key then
        return false
    end
    local bucket = MatLog.EnsureCharBucket(MatLog.CurrentDayKey(), MatLog.CharName())
    if not bucket then
        return false
    end
    local row = bucket[key]
    if type(row) ~= "table" then
        row = { c = 0, k = MatLog.KindEnum(kind) }
        bucket[key] = row
    end
    row.c = (row.c or 0) + count
    row.k = MatLog.KindEnum(kind)
    MatLog.MarkLogDirty()
    return true
end

function MatLog.ItemCreditId(link, name)
    local id = MatLog.ItemIdFromLink(link)
    if id then
        return tostring(id)
    end
    return MatLog.ItemName(link, name)
end

function MatLog.PruneRecentWritCredit()
    local now = MatLog.NowMs()
    local i = 1
    while i <= #S.recentWritCredit do
        if now - S.recentWritCredit[i].ms > C.WRIT_CREDIT_DEDUPE_MS then
            table.remove(S.recentWritCredit, i)
        else
            i = i + 1
        end
    end
end

function MatLog.AlreadyCreditedWrit(link, count, name)
    MatLog.PruneRecentWritCredit()
    local id = MatLog.ItemCreditId(link, name)
    for i = 1, #S.recentWritCredit do
        local row = S.recentWritCredit[i]
        if row.id == id and row.count == count then
            table.remove(S.recentWritCredit, i)
            return true
        end
    end
    return false
end

function MatLog.NoteWritCredit(link, count, name)
    S.recentWritCredit[#S.recentWritCredit + 1] = {
        id = MatLog.ItemCreditId(link, name),
        count = count,
        ms = MatLog.NowMs(),
    }
end

function MatLog.AddWritItem(link, count, name)
    if MatLog.AlreadyCreditedWrit(link, count, name) then
        return false
    end
    if MatLog.AddItem(link, count, name, C.SOURCE_WRIT) then
        MatLog.NoteWritCredit(link, count, name)
        MatLog.NoteBagGain("writ", link, count)
        return true
    end
    return false
end

function MatLog.RefreshIfShown()
    S.refreshToken = (S.refreshToken or 0) + 1
    local token = S.refreshToken
    local function apply()
        if token ~= S.refreshToken then
            return
        end
        if BasaTools and BasaTools.IsShown and BasaTools.IsShown() then
            MatLog.RefreshReport()
        end
    end
    if type(zo_callLater) == "function" then
        zo_callLater(apply, C.REFRESH_DEBOUNCE_MS)
    else
        apply()
    end
end

function MatLog.PruneOldDays()
    local log = MatLog.LogTable()
    if not log then
        return
    end
    local cutoff = GetTimeStamp() - (C.RETENTION_DAYS * C.DAY_LENGTH)
    local changed = false
    for key in pairs(log) do
        local ts = tonumber(key)
        if ts and ts < cutoff then
            log[key] = nil
            changed = true
        end
    end
    if changed then
        MatLog.MarkLogDirty()
    end
end

function MatLog.SortedDayKeys()
    local log = MatLog.LogTable() or {}
    local keys = {}
    local current = MatLog.CurrentDayKey()
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
    for i = 1, math.min(#keys, C.RETENTION_DAYS) do
        kept[#kept + 1] = keys[i]
    end
    return kept
end

function MatLog.DayChars(dayKey)
    local log = MatLog.LogTable()
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
