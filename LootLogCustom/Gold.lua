local LEJ = LibExtendedJournal
local LootLog = LootLog

--------------------------------------------------------------------------------
-- Extended Journal
--------------------------------------------------------------------------------

local TAB_NAME = "LootLogGold"
local FRAME = LootLogGoldFrame
local DATA_TYPE = 1
local SORT_TYPE = 1

local Initialized = false
local Dirtiness = 0

function LootLog.InitializeGold()
    LEJ.RegisterTab(TAB_NAME, {
		title = SI_LOOTLOG_TITLE,
		subtitle = "Gold",
		order = 120,
		--icon = "EsoUI/Art/currency/currency_gold.dds"
		--iconPrefix = "/esoui/art/inventory/inventory_currencytab_accountwide_",
		iconPrefix = "/esoui/art/tradinghouse/tradinghouse_sell_tabicon_",
		--icon = "/esoui/art/vendor/vendor_tabicon_sell_up.dds",
		--iconPrefix = "/esoui/art/inventory/inventory_tabicon_currency_",
		--iconPrefix = "/esoui/art/inventory/inventory_tabicon_gold_",
		control = FRAME,
		settingsPanel = LootLog.settingsPanel,
		callbackShow = function()
			LootLog.LazyInitializeGold()
			LootLog.RefreshGold(true)
			LootLog.SetRetentionText(FRAME:GetNamedChild("History"))
        end,
    })
end

function LootLog.LazyInitializeGold()
    if (not Initialized) then
        Initialized = true
        LootLog.gold = LootLogGold:New(FRAME)
        table.insert(LootLog.refreshCallbacks, function(refreshLevel)
            if (Dirtiness < refreshLevel) then
                Dirtiness = refreshLevel
            end
            LootLog.RefreshGold()
        end)
    end
end

function LootLog.RefreshGold(noActiveCheck)
    if (Initialized and Dirtiness > 0 and (noActiveCheck or LEJ.IsTabActive(TAB_NAME))) then
        if (Dirtiness == 1) then
            LootLog.gold:RefreshFilters()
        else
            LootLog.gold:RefreshData()
        end
        Dirtiness = 0
    end
end

--------------------------------------------------------------------------------
-- LootLogGold
--------------------------------------------------------------------------------

LootLogGold = ExtendedJournalSortFilterList:Subclass()
local LootLogGold = LootLogGold

function LootLogGold:Setup()
    ZO_ScrollList_AddDataType(self.list, DATA_TYPE, "LootLogGoldRow", 30, function(...) self:SetupItemRow(...) end)
    ZO_ScrollList_EnableHighlight(self.list, "ZO_ThinListHighlight")
    self:SetAlternateRowBackgrounds(true)

    self.masterList = {}
    self.scratch = { processed = {} }

    local sortKeys = {
		["time"] = { isNumeric = true },
		["amount"] = { isNumeric = true, tiebreaker = "time", tieBreakerSortOrder = ZO_SORT_ORDER_DOWN },
		["reason"] = { caseInsensitive = true, tiebreaker = "time", tieBreakerSortOrder = ZO_SORT_ORDER_DOWN },
		["recipient"] = { caseInsensitive = true, tiebreaker = "time", tieBreakerSortOrder = ZO_SORT_ORDER_DOWN },
	}

    self.currentSortKey = "time"
    self.currentSortOrder = ZO_SORT_ORDER_DOWN
    self.sortHeaderGroup:SelectAndResetSortForKey(self.currentSortKey)
    self.sortFunction = function(listEntry1, listEntry2)
        return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, sortKeys, self.currentSortOrder)
    end

    self.searchBox = self.frame:GetNamedChild("SearchFieldBox")
    self.searchBox:SetHandler("OnTextChanged", function() self:RefreshFilters() end)
    self.search = self:InitializeSearch(SORT_TYPE)

    self:RefreshData()
end

function LootLogGold:BuildMasterList()
    if (Dirtiness == 3) then
        self.masterList = {}
        self.scratch = { processed = {} }
    end

    for key, group in pairs(LootLog.goldhistory) do
        if (not self.scratch.processed[key]) then
            self.scratch.processed[key] = 0
        end
        for i = self.scratch.processed[key] + 1, #group do
			self.scratch.processed[key] = i
			local entry = LootLog.UnpackGold(group[i])
            
			local reasonCode = entry[3]
			local reasonText = LootLog.MoneyReasonToString[reasonCode] or string.format("Unknown (%d)", reasonCode)

			table.insert(self.masterList, {
				type = SORT_TYPE,
				time = entry[1],
				reason = reasonText,
				amount = entry[2],
				recipient = entry[4] and string.format("%s (%s)", entry[4], entry[5]) or entry[5],
			})
        end
    end
end

function LootLogGold:FilterScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    ZO_ClearNumericallyIndexedTable(scrollData)

    local searchInput = self.searchBox:GetText()
    local totalGained = 0
    local totalSpent = 0

    for _, data in ipairs(self.masterList) do
        if (searchInput == "" or self.search:IsMatch(searchInput, data)) then
            table.insert(scrollData, ZO_ScrollList_CreateDataEntry(DATA_TYPE, data))
             if data.amount > 0 then
               totalGained = totalGained + data.amount
             else
               totalSpent = totalSpent - data.amount
             end
        end
    end

    local summaryText = string.format("Gained: %s%s   Spent: %s%s   Net: %s%s",
        LootLog.FormatCurrency(totalGained), LootLog.GOLD_ICON,
        LootLog.FormatCurrency(totalSpent), LootLog.GOLD_ICON,
        LootLog.FormatCurrency(totalGained - totalSpent), LootLog.GOLD_ICON
    )
    self.frame:GetNamedChild("Counter"):SetText(summaryText)
end

function LootLogGold:SetupItemRow(control, data)
    self:SetupRow(control, data)

    local cell

    -- Set text to white using the more direct SetColor() function
    cell = control:GetNamedChild("Time")
    cell:SetColor(1, 1, 1, 1) -- White
    cell:SetText(os.date("%H:%M:%S", data.time))

    cell = control:GetNamedChild("Reason")
    cell:SetColor(1, 1, 1, 1) -- White
    cell:SetText(data.reason)
    
    cell = control:GetNamedChild("Amount")
    local amount = data.amount
    if amount > 0 then
        cell:SetColor(0.6, 1, 0.6) -- Light Green
        cell:SetText("+" .. LootLog.FormatCurrency(amount) .. LootLog.GOLD_ICON)
    else
        cell:SetColor(1, 0.6, 0.6) -- Light Red
        cell:SetText(LootLog.FormatCurrency(amount) .. LootLog.GOLD_ICON)
    end

    cell = control:GetNamedChild("Recipient")
    cell:SetColor(1, 1, 1, 1) -- White
    cell:SetText(data.recipient)
end

function LootLogGold:ProcessItemEntry(stringSearch, data, searchTerm, cache)
    if (zo_plainstrfind(data.reason:lower(), searchTerm) or zo_plainstrfind(data.recipient:lower(), searchTerm)) then
		return true
	end
	
	return false
end