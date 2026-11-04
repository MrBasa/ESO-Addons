-- MatLog UI: scroll list, filters, pricing.
local C = MatLog.C
local S = MatLog._

C.HEADER_SPECS = {
    { child = "Item", key = "item", label = "Item", align = TEXT_ALIGN_LEFT, dir = ZO_SORT_ORDER_UP },
    { child = "Qty", key = "qty", label = "Qty", align = TEXT_ALIGN_RIGHT, dir = ZO_SORT_ORDER_UP },
    { child = "Category", key = "category", label = "Category", align = TEXT_ALIGN_LEFT, dir = ZO_SORT_ORDER_UP },
    { child = "Character", key = "character", label = "Character", align = TEXT_ALIGN_LEFT, dir = ZO_SORT_ORDER_UP },
    { child = "Value", key = "value", label = "Gold", align = TEXT_ALIGN_RIGHT, dir = ZO_SORT_ORDER_DOWN },
}

function MatLog.GetList()
    local panel = MatLog.GetPanel()
    local backdrop = MatLog.Child(panel, "ListBackdrop")
    return MatLog.Child(backdrop, "List"), MatLog.Child(panel, "Totals")
end

function MatLog.GetHeaders()
    local panel = MatLog.GetPanel()
    local backdrop = MatLog.Child(panel, "ListBackdrop")
    return MatLog.Child(backdrop, "Headers")
end

function MatLog.SortOrderFromAsc(asc)
    if asc then
        return ZO_SORT_ORDER_UP
    end
    return ZO_SORT_ORDER_DOWN
end

function MatLog.OnSortHeaderClicked(key, order)
    if type(key) ~= "string" or not C.SORT_KEYS[key] then
        return
    end
    if S.showingHelp then
        return
    end
    S.sortKey = key
    S.sortAsc = (order == ZO_SORT_ORDER_UP)
    if S.saved then
        S.saved.matlogSortKey = S.sortKey
        S.saved.matlogSortAsc = S.sortAsc
    end
    MatLog.RefreshReport()
end

function MatLog.BindSortHeaders()
    if S.sortHeaderGroup then
        return
    end
    local headers = MatLog.GetHeaders()
    if not headers or type(ZO_SortHeader_Initialize) ~= "function" or type(ZO_SortHeaderGroup) ~= "table" then
        return
    end
    for i = 1, #C.HEADER_SPECS do
        local spec = C.HEADER_SPECS[i]
        local control = MatLog.Child(headers, spec.child)
        if control then
            ZO_SortHeader_Initialize(control, spec.label, spec.key, spec.dir, spec.align, "ZoFontGameBold")
        end
    end
    S.sortHeaderGroup = ZO_SortHeaderGroup:New(headers, true)
    local clicked = ZO_SortHeaderGroup.HEADER_CLICKED or "HeaderClicked"
    S.sortHeaderGroup:RegisterCallback(clicked, MatLog.OnSortHeaderClicked)
    if S.sortHeaderGroup.AddHeadersFromContainer then
        S.sortHeaderGroup:AddHeadersFromContainer()
    else
        for i = 1, #C.HEADER_SPECS do
            local control = MatLog.Child(headers, C.HEADER_SPECS[i].child)
            if control then
                S.sortHeaderGroup:AddHeader(control)
            end
        end
    end
    local suppress = ZO_SortHeaderGroup.SUPPRESS_CALLBACKS
    if S.sortHeaderGroup.SelectHeaderByKey then
        S.sortHeaderGroup:SelectHeaderByKey(S.sortKey, suppress, true, MatLog.SortOrderFromAsc(S.sortAsc))
    end
end

function MatLog.RefreshHeaders()
    MatLog.BindSortHeaders()
    if not S.sortHeaderGroup then
        return
    end
    local summary = S.saved and S.saved.matlogView == "summary"
    if S.sortHeaderGroup.SetHeaderHiddenForKey then
        S.sortHeaderGroup:SetHeaderHiddenForKey("character", summary and true or false)
    else
        local charHdr = MatLog.Child(MatLog.GetHeaders(), "Character")
        if charHdr and charHdr.SetHidden then
            charHdr:SetHidden(summary and true or false)
        end
    end
end

function MatLog.SetHeadersVisible(visible)
    local panel = MatLog.GetPanel()
    local backdrop = MatLog.Child(panel, "ListBackdrop")
    local headers = MatLog.Child(backdrop, "Headers")
    local list = MatLog.Child(backdrop, "List")
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
        MatLog.RefreshHeaders()
    end
end

function MatLog.HideTooltip()
    if ItemTooltip then
        ClearTooltip(ItemTooltip)
    end
end

function MatLog.ShowItemTooltip(control, link)
    if not control or type(link) ~= "string" or link == "" or not ItemTooltip then
        return
    end
    InitializeTooltip(ItemTooltip, control, LEFT, 0, 0, RIGHT)
    if ItemTooltip.SetLink then
        ItemTooltip:SetLink(link)
    end
end

function MatLog.SetupMatLogRow(control, data)
    local icon = MatLog.Child(control, "Icon")
    local item = MatLog.Child(control, "Item")
    local qty = MatLog.Child(control, "Qty")
    local category = MatLog.Child(control, "Category")
    local character = MatLog.Child(control, "Character")
    local value = MatLog.Child(control, "Value")
    local valueTotal = value and MatLog.Child(value, "Total")
    local valueUnit = value and MatLog.Child(value, "Unit")
    local divider = MatLog.Child(control, "RowDivider")
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
        local totalText = MatLog.ColorGoldText(data.valueTotal, C.COL_GOLD_TOTAL)
        valueTotal:SetText(totalText)
        valueTotal:SetColor(C.COL_GOLD_TOTAL[1], C.COL_GOLD_TOTAL[2], C.COL_GOLD_TOTAL[3], 1)
        valueTotal:SetHidden(hideValue or totalText == "")
    end
    if valueUnit then
        local unitText = MatLog.ColorGoldText(data.valueUnit, C.COL_GOLD_UNIT)
        valueUnit:SetText(unitText)
        valueUnit:SetColor(C.COL_GOLD_UNIT[1], C.COL_GOLD_UNIT[2], C.COL_GOLD_UNIT[3], 1)
        valueUnit:SetHidden(hideValue or unitText == "")
    end
    if control.SetHandler then
        control:SetHandler("OnMouseEnter", function(self)
            MatLog.ShowItemTooltip(self, data.link)
        end)
        control:SetHandler("OnMouseExit", function()
            MatLog.HideTooltip()
        end)
    end
end

function MatLog.SetupLineRow(control, data)
    local label = MatLog.Child(control, "Line")
    if not label then
        return
    end
    label:SetText(data.text or "")
    label:SetColor(data.r or 0.9, data.g or 0.9, data.b or 0.85, 1)
end

function MatLog.EnsureListTypes()
    if S.listTypesReady then
        return
    end
    local list = MatLog.GetList()
    if not list or type(ZO_ScrollList_AddDataType) ~= "function" then
        return
    end
    ZO_ScrollList_AddDataType(list, 1, "MatLogRow", 42, MatLog.SetupMatLogRow)
    ZO_ScrollList_AddDataType(list, 2, "BasaToolsOutputLineRow", 22, MatLog.SetupLineRow)
    S.listTypesReady = true
end

function MatLog.ItemIcon(link)
    if type(link) == "string" and link ~= "" and type(GetItemLinkIcon) == "function" then
        local tex = GetItemLinkIcon(link)
        if type(tex) == "string" and tex ~= "" then
            return tex
        end
    end
    return "EsoUI/Art/Icons/icon_missing.dds"
end

function MatLog.CollectRows()
    local dayKey = S.selectedDayKey or MatLog.CurrentDayKey()
    local names, day = MatLog.DayChars(dayKey)
    local summary = S.saved and S.saved.matlogView == "summary"
    local rows = {}
    local stacked = {}
    local stackOrder = {}
    local totalValue = 0
    local priced = false
    local priceCache = {}

    local function cachedPrice(link)
        if type(link) ~= "string" or link == "" then
            return nil
        end
        if priceCache[link] ~= nil then
            local v = priceCache[link]
            if v == false then
                return nil
            end
            return v
        end
        local gold = MatLog.PriceGold(link)
        priceCache[link] = gold or false
        return gold
    end

    local function wantChar(name)
        return S.selectedChar == "all" or S.selectedChar == name
    end

    local function wantCategory(source)
        return S.selectedCategory == "all" or S.selectedCategory == source
    end

    local function consider(charName, rowKey, entry)
        if type(entry) ~= "table" then
            return
        end
        local source = MatLog.SourceFromKey(rowKey)
        if not wantCategory(source) then
            return
        end
        local kindName = MatLog.KindName(entry.k)
        local link = MatLog.RowLink(rowKey, entry)
        local color = summary and MatLog.KindColor(kindName) or MatLog.SourceColor(source)
        local unit = cachedPrice(link)
        local count = entry.c or 0
        local lineValue = nil
        if unit then
            lineValue = unit * count
            totalValue = totalValue + lineValue
            priced = true
        end
        local displayName = MatLog.ItemName(link)
        if summary then
            local stackKey = tostring(MatLog.ItemIdFromKey(rowKey) or rowKey)
            local slot = stacked[stackKey]
            if not slot then
                slot = {
                    link = link,
                    name = displayName,
                    count = 0,
                    category = kindName,
                    unit = unit,
                    icon = MatLog.ItemIcon(link),
                    r = color[1],
                    g = color[2],
                    b = color[3],
                }
                stacked[stackKey] = slot
                stackOrder[#stackOrder + 1] = stackKey
            end
            slot.count = slot.count + count
            if unit then
                slot.unit = unit
            end
            if type(link) == "string" and link ~= "" then
                slot.link = link
            end
        else
            rows[#rows + 1] = {
                kind = "item",
                qty = tostring(count),
                qtyNum = count,
                item = displayName,
                category = C.SOURCE_LABEL[source] or "Hireling",
                character = charName,
                valueTotal = unit and MatLog.FormatGold(lineValue) or "",
                valueUnit = unit and MatLog.FormatGold(unit) or "",
                valueNum = lineValue or 0,
                icon = MatLog.ItemIcon(link),
                link = link,
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
                        local la = MatLog.RowLink(a)
                        local lb = MatLog.RowLink(b)
                        local na = MatLog.ItemName(la)
                        local nb = MatLog.ItemName(lb)
                        return na < nb
                    end)
                    for k = 1, #keys do
                        consider(charName, keys[k], bucket[keys[k]])
                    end
                end
            end
        end
    end

    if summary then
        -- Reuse unit prices already cached during consider (no second LibPrice pass).
        totalValue = 0
        priced = false
        for i = 1, #stackOrder do
            local entry = stacked[stackOrder[i]]
            local unit = entry.unit
            local count = entry.count or 0
            local lineValue = nil
            if unit then
                lineValue = unit * count
                totalValue = totalValue + lineValue
                priced = true
            end
            local displayName = entry.name or "Item"
            rows[#rows + 1] = {
                kind = "item",
                qty = tostring(count),
                qtyNum = count,
                item = displayName,
                category = C.KIND_LABEL[entry.category] or "",
                character = "",
                valueTotal = unit and MatLog.FormatGold(lineValue) or "",
                valueUnit = unit and MatLog.FormatGold(unit) or "",
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
        if S.sortKey == "qty" then
            ka, kb = a.qtyNum or 0, b.qtyNum or 0
        elseif S.sortKey == "value" then
            ka, kb = a.valueNum or 0, b.valueNum or 0
        elseif S.sortKey == "category" then
            ka, kb = string.lower(a.category or ""), string.lower(b.category or "")
        elseif S.sortKey == "character" then
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
        if S.sortAsc then
            return ka < kb
        end
        return ka > kb
    end)

    return rows, { count = #rows, totalValue = totalValue, priced = priced, summary = summary }
end

function MatLog.FillList(entries, lineMode, showHeaders)
    MatLog.EnsureListTypes()
    MatLog.SetHeadersVisible(showHeaders and true or false)
    local list, totalsLabel = MatLog.GetList()
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

function MatLog.TotalsText(info)
    info = info or {}
    local parts = {}
    if info.summary then
        parts[#parts + 1] = string.format("%d stacked item(s)", info.count or 0)
        if info.priced then
            parts[#parts + 1] = "Total " .. MatLog.FormatGold(info.totalValue)
        else
            local lib = rawget(_G, "LibPrice")
            if type(lib) ~= "table" then
                parts[#parts + 1] = "(LibPrice not loaded — values blank)"
            end
        end
    else
        parts[#parts + 1] = string.format("%d row(s)", info.count or 0)
        if info.priced then
            parts[#parts + 1] = "Total " .. MatLog.FormatGold(info.totalValue)
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
    S.showingHelp = true
    local lines = {
        { text = "MatLog — materials, surveys, and master writs you gather.", r = C.COL_HEADER[1], g = C.COL_HEADER[2], b = C.COL_HEADER[3] },
        { text = "Enable — record world loot, daily-writ coffer contents (including auto-loot by Lazy Writ Crafter), and hireling mail (including Take all into the craft bag). Player mail is not logged. Guild-store mail taken by itself is skipped; a mixed System-mail Take all may include those attachments as Hireling. Off keeps existing rows until they age out." },
        { text = "Kept for three daily-reset days. Use the day dropdown to switch." },
        { text = "Full — one row per item per character. Category is Writ (quest), Hireling (mail), or World (loot). The Category dropdown filters that column; the footer totals follow the filter." },
        { text = "Summary — stack by item across characters. Gold is inventory-style: stack total on top, unit price below." },
        { text = "Click a column header to sort. Click again to reverse. Gold sorts by stack total." },
        { text = "Does not track gold, vendor purchases, or guild-store buys." },
    }
    local totalsLabel = MatLog.FillList(lines, true, false)
    if totalsLabel then
        totalsLabel:SetText("Help")
    end
end

function MatLog.ComboCallback(setter)
    return function(_combo, _text, choice)
        setter(choice and choice.value)
        S.showingHelp = false
        zo_callLater(function()
            MatLog.RefreshFilterCombos()
            MatLog.RefreshReport()
        end, 1)
    end
end

function MatLog.RebuildCombo(combo, items, selectedValue, selectedText)
    if not combo then
        return
    end
    combo:ClearItems()
    for i = 1, #items do
        local item = items[i]
        local entry = combo:CreateItemEntry(item.text, MatLog.ComboCallback(item.setter or function() end))
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

function MatLog.RefreshFilterCombos()
    local panel = MatLog.GetPanel()
    if not panel then
        return
    end
    local dayCombo = ZO_ComboBox_ObjectFromContainer(MatLog.Child(panel, "DayDrop"))
    local charCombo = ZO_ComboBox_ObjectFromContainer(MatLog.Child(panel, "CharDrop"))
    local categoryCombo = ZO_ComboBox_ObjectFromContainer(MatLog.Child(panel, "CategoryDrop"))
    local dayKeys = MatLog.SortedDayKeys()
    if not S.selectedDayKey then
        S.selectedDayKey = MatLog.CurrentDayKey()
    end
    local dayItems = {}
    for i = 1, #dayKeys do
        local key = dayKeys[i]
        dayItems[#dayItems + 1] = {
            text = MatLog.FormatDayKey(key),
            value = key,
            setter = function(value)
                S.selectedDayKey = value
                S.selectedChar = "all"
                if S.saved then
                    S.saved.matlogDayKey = value
                    S.saved.matlogChar = "all"
                end
            end,
        }
    end
    if dayCombo then
        dayCombo:SetSortsItems(false)
        MatLog.RebuildCombo(dayCombo, dayItems, S.selectedDayKey)
        dayCombo:SetSelectedItem(MatLog.FormatDayKey(S.selectedDayKey))
    end

    local names = MatLog.DayChars(S.selectedDayKey or MatLog.CurrentDayKey())
    local charItems = {
        {
            text = "All characters",
            value = "all",
            setter = function(value)
                S.selectedChar = value
                if S.saved then
                    S.saved.matlogChar = value
                end
            end,
        },
    }
    for i = 1, #names do
        charItems[#charItems + 1] = {
            text = names[i],
            value = names[i],
            setter = function(value)
                S.selectedChar = value
                if S.saved then
                    S.saved.matlogChar = value
                end
            end,
        }
    end
    if charCombo then
        charCombo:SetSortsItems(false)
        MatLog.RebuildCombo(charCombo, charItems, S.selectedChar)
        if S.selectedChar == "all" then
            charCombo:SetSelectedItem("All characters")
        else
            charCombo:SetSelectedItem(S.selectedChar)
        end
    end

    local categoryItems = {
        {
            text = "All categories",
            value = "all",
            setter = function(value)
                S.selectedCategory = value
                if S.saved then
                    S.saved.matlogCategory = value
                end
            end,
        },
    }
    local categoryOrder = { C.SOURCE_WRIT, C.SOURCE_HIRELING, C.SOURCE_WORLD }
    for i = 1, #categoryOrder do
        local value = categoryOrder[i]
        categoryItems[#categoryItems + 1] = {
            text = C.SOURCE_LABEL[value],
            value = value,
            setter = function(choice)
                S.selectedCategory = choice
                if S.saved then
                    S.saved.matlogCategory = choice
                end
            end,
        }
    end
    if categoryCombo then
        categoryCombo:SetSortsItems(false)
        MatLog.RebuildCombo(categoryCombo, categoryItems, S.selectedCategory)
        if S.selectedCategory == "all" then
            categoryCombo:SetSelectedItem("All categories")
        else
            categoryCombo:SetSelectedItem(C.SOURCE_LABEL[S.selectedCategory] or "All categories")
        end
    end
end

function MatLog.BindPriceSourceCombo(panel)
    local combo = ZO_ComboBox_ObjectFromContainer(MatLog.Child(panel, "PriceSourceDrop"))
    if not combo then
        return
    end
    local current = (S.saved and S.saved.matlogPriceSource) or "npc"
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
            if S.saved then
                S.saved.matlogPriceSource = choice.value
            end
            S.showingHelp = false
            MatLog.RefreshReport()
        end)
        entry.value = choice.value
        combo:AddItem(entry)
        if choice.value == current then
            combo:SetSelectedItem(choice.text)
        end
    end
end

function MatLog.BindPanel(panel)
    if panel then
        S.boundPanel = panel
    end
    panel = MatLog.GetPanel()
    if not panel then
        return
    end
    MatLog.BindPriceSourceCombo(panel)
    S.panelBound = true
    BasaTools.BindCheck(
        MatLog.Child(panel, "CheckEnable"),
        "Enable",
        "Record gathered materials, surveys, and master writs. Existing rows stay until they age out of the 3-day window.",
        function()
            return S.saved and S.saved.matlogEnabled ~= false
        end,
        function(checked)
            if S.saved then
                S.saved.matlogEnabled = checked and true or false
            end
            MatLog.SetEnabled(checked)
            S.showingHelp = false
            MatLog.RefreshReport()
        end
    )
    BasaTools.BindCheck(
        MatLog.Child(panel, "CheckSummary"),
        "Summary",
        "Stack by item across characters. Gold shows stack total on top and unit price below. Unchecked is the full per-character list.",
        function()
            return S.saved and S.saved.matlogView == "summary"
        end,
        function(checked)
            if S.saved then
                S.saved.matlogView = checked and "summary" or "full"
            end
            S.showingHelp = false
            MatLog.RefreshReport()
        end
    )
    MatLog.RefreshFilterCombos()
    MatLog.RefreshHeaders()
end

function MatLog.SortBy(key)
    if type(key) ~= "string" or not C.SORT_KEYS[key] then
        return
    end
    if S.showingHelp then
        return
    end
    if S.sortHeaderGroup and S.sortHeaderGroup.HeaderForKey and S.sortHeaderGroup.OnHeaderClicked then
        local header = S.sortHeaderGroup:HeaderForKey(key)
        if header then
            S.sortHeaderGroup:OnHeaderClicked(header)
            return
        end
    end
    if S.sortKey == key then
        S.sortAsc = not S.sortAsc
    else
        S.sortKey = key
        S.sortAsc = (key ~= "value")
    end
    if S.saved then
        S.saved.matlogSortKey = S.sortKey
        S.saved.matlogSortAsc = S.sortAsc
    end
    MatLog.RefreshReport()
end

function MatLog_SortBy(key)
    MatLog.SortBy(key)
end

function MatLog.OnPanelShown(panel)
    S.showingHelp = false
    MatLog.BindPanel(panel)
    MatLog.RefreshReport()
end

function MatLog.RefreshReport()
    if not S.panelBound then
        MatLog.BindPanel()
    end
    if S.showingHelp then
        return
    end
    local rows, info = MatLog.CollectRows()
    if #rows == 0 then
        local totalsLabel = MatLog.FillList({
            {
                text = "Nothing recorded for this day yet. Gather materials, surveys, or master writs with MatLog enabled.",
                r = C.COL_MUTED[1],
                g = C.COL_MUTED[2],
                b = C.COL_MUTED[3],
            },
        }, true, true)
        if totalsLabel then
            totalsLabel:SetText(MatLog.TotalsText(info or {}))
        end
        return
    end
    local totalsLabel = MatLog.FillList(rows, false, true)
    if totalsLabel then
        totalsLabel:SetText(MatLog.TotalsText(info))
    end
end
