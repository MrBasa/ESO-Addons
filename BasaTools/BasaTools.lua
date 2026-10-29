local ADDON_NAME = "BasaTools"

BasaTools = BasaTools or {}

local saved = nil
local registeredTabs = {}
local tabsBuilt = false
local outputLines = {}
local helpEntries = {}
local listTypesReady = false
local outputChromeBound = false
local showingHelp = false
local hScroll = 0
local updatingSlider = false
local lastShowHScroll = nil

local HELP_PAD = 4
local HELP_GAP = 8
local HELP_ACTION_W = 160
local HELP_SLASH_W = 190
local HELP_EFFECT_MIN_W = 726
local HELP_MIN_WIDTH = HELP_PAD + HELP_ACTION_W + HELP_GAP + HELP_SLASH_W + HELP_GAP + HELP_EFFECT_MIN_W + HELP_PAD

local WIN_MIN_W, WIN_MIN_H = 820, 500
local WIN_MAX_W, WIN_MAX_H = 1600, 1100
local WIN_DEFAULT_W, WIN_DEFAULT_H = 820, 660
local TAB_GAP = 12
local TAB_HEIGHT = 32
local TAB_ROW_Y = 42
local TAB_ROW_X = 20
local PANEL_TOP = 88
local BUTTONS_PANEL_H = 92
local COMPACT_PANEL_H = 40

local COL_OK = { 0.35, 0.85, 0.35 }
local COL_INFO = { 0.55, 0.82, 0.98 }
local COL_BAD = { 1, 0.45, 0.45 }
local COL_WARN = { 1, 0.52, 0.35 }
local COL_HEADER = { 0.93, 0.86, 0.55 }

local function RGB(c)
    return c[1], c[2], c[3]
end

local function Child(parent, name)
    if parent and parent.GetNamedChild then
        return parent:GetNamedChild(name)
    end
    return nil
end

local function GetWindow()
    return rawget(_G, "BasaToolsWindow")
end

local function GetOutputBackdrop()
    return Child(GetWindow(), "OutputBackdrop")
end

local function GetOutputEdit()
    return Child(GetOutputBackdrop(), "Edit")
end

local function GetHelpList()
    return Child(GetOutputBackdrop(), "HelpList")
end

local function GetHScroll()
    return Child(GetOutputBackdrop(), "HScroll")
end

local function SpecAvailable(spec)
    if type(spec.available) == "function" then
        return spec.available() and true or false
    end
    return true
end

local function FindSpec(id)
    for i = 1, #registeredTabs do
        if registeredTabs[i].id == id then
            return registeredTabs[i]
        end
    end
    return nil
end

local function CurrentSpec()
    return FindSpec(saved and saved.lastTab)
end

function BasaTools.RegisterTab(spec)
    if type(spec) ~= "table" or type(spec.id) ~= "string" or spec.id == "" then
        return
    end
    for i = 1, #registeredTabs do
        if registeredTabs[i].id == spec.id then
            registeredTabs[i] = spec
            return
        end
    end
    registeredTabs[#registeredTabs + 1] = spec
end

function BasaTools.GetSaved()
    return saved
end

function BasaTools.GetWindow()
    return GetWindow()
end

function BasaTools.Child(parent, name)
    return Child(parent, name)
end

--- Convert |H…|hName|h item links to plain names, then strip leftover pipe markup.
--- Color is re-applied with |c via ColorizeLine for the selectable EditBox
--- (ALLOW_MARKUP_TYPE_COLOR_ONLY). Help labels use the plain string + SetColor.
local function SanitizeForPanel(text)
    if text == nil then
        return ""
    end
    local s = tostring(text)
    s = string.gsub(s, "(|H.-|h.-|h)", function(link)
        if type(GetItemLinkName) == "function" then
            local name = GetItemLinkName(link)
            if type(name) == "string" and name ~= "" then
                return name
            end
        end
        local inner = string.match(link, "|h(.-)|h")
        if inner and inner ~= "" then
            return inner
        end
        return "[item]"
    end)
    s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|C%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    s = string.gsub(s, "|R", "")
    s = string.gsub(s, "/c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "/C%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "/r", "")
    s = string.gsub(s, "/R", "")
    s = string.gsub(s, "|", " ")
    s = string.gsub(s, "%[", "(")
    s = string.gsub(s, "%]", ")")
    return s
end

local function InterfaceRGB(textColor, fallback)
    if type(GetInterfaceColor) == "function" and textColor then
        local r, g, b = GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, textColor)
        if r then
            return r, g, b
        end
    end
    if fallback then
        return fallback[1], fallback[2], fallback[3]
    end
    return 0.9, 0.9, 0.85
end

local function InferColor(text)
    local t = string.lower(text or "")
    if string.find(t, "error", 1, true) or string.find(t, "not loaded", 1, true) or string.find(t, "failed", 1, true) then
        return COL_BAD[1], COL_BAD[2], COL_BAD[3]
    end
    if string.find(t, "warning", 1, true) or string.find(t, "auto-craft is on", 1, true)
        or string.find(t, "auto-craft is still on", 1, true) or string.find(t, "expertise", 1, true)
    then
        return COL_WARN[1], COL_WARN[2], COL_WARN[3]
    end
    if string.match(text, "^Complete") then
        return COL_OK[1], COL_OK[2], COL_OK[3]
    end
    if string.match(text, "^Improve") then
        return COL_INFO[1], COL_INFO[2], COL_INFO[3]
    end
    if string.match(text, "^Unmatched") then
        return COL_BAD[1], COL_BAD[2], COL_BAD[3]
    end
    if string.match(text, "^Orphans") then
        return COL_WARN[1], COL_WARN[2], COL_WARN[3]
    end
    if string.match(text, "^WritMatch") or string.match(text, "^LibScanner") or string.match(text, "^BasaTools") then
        return COL_HEADER[1], COL_HEADER[2], COL_HEADER[3]
    end
    return InterfaceRGB(INTERFACE_TEXT_COLOR_NORMAL, { 0.9, 0.9, 0.85 })
end

local function ColorByte(x)
    local n = math.floor((tonumber(x) or 1) * 255 + 0.5)
    if n < 0 then
        n = 0
    elseif n > 255 then
        n = 255
    end
    return n
end

local function ColorizeLine(text, r, g, b)
    if type(text) ~= "string" or text == "" then
        return text or ""
    end
    if ZO_ColorDef and ZO_ColorDef.New then
        local def = ZO_ColorDef:New(r, g, b, 1)
        if def and def.Colorize then
            return def:Colorize(text)
        end
    end
    return string.format("|cFF%02X%02X%02X%s|r", ColorByte(r), ColorByte(g), ColorByte(b), text)
end

local function ConfigureOutputEdit(edit)
    if not edit then
        return
    end
    if edit.SetMaxInputChars then
        edit:SetMaxInputChars(50000)
    end
    if edit.SetAllowMarkupType then
        if ALLOW_MARKUP_TYPE_COLOR_ONLY then
            edit:SetAllowMarkupType(ALLOW_MARKUP_TYPE_COLOR_ONLY)
        elseif ALLOW_MARKUP_TYPE_ALL then
            edit:SetAllowMarkupType(ALLOW_MARKUP_TYPE_ALL)
        elseif ALLOW_MARKUP_TYPE_NONE then
            edit:SetAllowMarkupType(ALLOW_MARKUP_TYPE_NONE)
        end
    end
    if edit.SetMultiLine then
        edit:SetMultiLine(true)
    end
    if edit.SetEditEnabled then
        edit:SetEditEnabled(false)
    end
    if edit.SetMouseEnabled then
        edit:SetMouseEnabled(true)
    end
end

local function RefreshOutputEdit()
    local edit = GetOutputEdit()
    if not edit then
        return
    end
    ConfigureOutputEdit(edit)
    edit:SetText(table.concat(outputLines, "\n"))
    if edit.SetCursorPosition then
        edit:SetCursorPosition(0)
    end
end

local function HelpContentWidth()
    local list = GetHelpList()
    local viewW = (list and list.GetWidth and list:GetWidth()) or WIN_DEFAULT_W
    if viewW < 1 then
        viewW = WIN_DEFAULT_W
    end
    return math.max(HELP_MIN_WIDTH, viewW)
end

local function HelpMaxOffset()
    if not showingHelp or #helpEntries == 0 then
        return 0
    end
    local list = GetHelpList()
    local viewW = (list and list.GetWidth and list:GetWidth()) or 0
    return math.max(0, HelpContentWidth() - viewW)
end

local function LayoutHelpList(showBar)
    local backdrop = GetOutputBackdrop()
    local list = GetHelpList()
    if not backdrop or not list then
        return
    end
    if lastShowHScroll == showBar then
        return
    end
    lastShowHScroll = showBar
    local bottom = showBar and -20 or -4
    if list.ClearAnchors then
        list:ClearAnchors()
    end
    list:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 4, 4)
    list:SetAnchor(BOTTOMRIGHT, backdrop, BOTTOMRIGHT, -4, bottom)
end

local function ApplyHScrollToVisibleRows()
    local list = GetHelpList()
    if list and type(ZO_ScrollList_RefreshVisible) == "function" then
        ZO_ScrollList_RefreshVisible(list)
    end
end

local function UpdateHScrollBar()
    local slider = GetHScroll()
    local maxOff = HelpMaxOffset()
    if hScroll > maxOff then
        hScroll = maxOff
    end
    if hScroll < 0 then
        hScroll = 0
    end
    local showBar = showingHelp and maxOff > 1
    LayoutHelpList(showBar)
    if slider then
        if slider.SetHidden then
            slider:SetHidden(not showBar)
        end
        if showBar and slider.SetMinMax then
            updatingSlider = true
            slider:SetMinMax(0, maxOff)
            if slider.SetValueStep then
                slider:SetValueStep(8)
            end
            slider:SetValue(hScroll)
            updatingSlider = false
        end
    end
    ApplyHScrollToVisibleRows()
end

local function SetupLineRow(control, data)
    local label = control:GetNamedChild("Line")
    if not label then
        return
    end
    label:SetText(data.text or "")
    local r, g, b = data.r or 0.9, data.g or 0.9, data.b or 0.85
    if label.SetColor then
        label:SetColor(r, g, b, 1)
    end
end

local function SetupHelpRow(control, data)
    local clip = control:GetNamedChild("HClip")
    local inner = clip and clip:GetNamedChild("Inner")
    local action = inner and inner:GetNamedChild("Action")
    local slash = inner and inner:GetNamedChild("Slash")
    local effect = inner and inner:GetNamedChild("Effect")
    local r, g, b = data.r or COL_HEADER[1], data.g or COL_HEADER[2], data.b or COL_HEADER[3]
    local contentW = HelpContentWidth()
    local effectW = contentW - HELP_PAD - HELP_ACTION_W - HELP_GAP - HELP_SLASH_W - HELP_GAP - HELP_PAD
    if inner and inner.SetWidth then
        inner:SetWidth(contentW)
    end
    if action then
        action:SetText(data.action or "")
        action:SetColor(r, g, b, 1)
        if action.SetWidth then
            action:SetWidth(HELP_ACTION_W)
        end
    end
    if slash then
        slash:SetText(data.slash or "")
        slash:SetColor(r, g, b, 1)
        if slash.SetWidth then
            slash:SetWidth(HELP_SLASH_W)
        end
    end
    if effect then
        effect:SetText(data.effect or "")
        effect:SetColor(r, g, b, 1)
        if effect.SetWidth then
            effect:SetWidth(effectW)
        end
    end
    if clip and clip.SetHorizontalScroll then
        clip:SetHorizontalScroll(hScroll)
    end
end

local function EnsureListTypes()
    if listTypesReady then
        return
    end
    local list = GetHelpList()
    if not list or type(ZO_ScrollList_AddDataType) ~= "function" then
        return
    end
    ZO_ScrollList_AddDataType(list, 1, "BasaToolsOutputLineRow", 22, SetupLineRow)
    ZO_ScrollList_AddDataType(list, 2, "BasaToolsHelpRow", 24, SetupHelpRow)
    listTypesReady = true
end

local function SetOutputMode(helpMode)
    showingHelp = helpMode and true or false
    local edit = GetOutputEdit()
    local list = GetHelpList()
    if edit and edit.SetHidden then
        edit:SetHidden(showingHelp)
    end
    if list and list.SetHidden then
        list:SetHidden(not showingHelp)
    end
    if not showingHelp then
        lastShowHScroll = nil
        local slider = GetHScroll()
        if slider and slider.SetHidden then
            slider:SetHidden(true)
        end
    end
end

local function RefreshHelpList()
    EnsureListTypes()
    local list = GetHelpList()
    if not list or not ZO_ScrollList_Clear or not ZO_ScrollList_GetDataList then
        return
    end
    SetOutputMode(true)
    local viewW = (list.GetWidth and list:GetWidth()) or 0
    local needBar = math.max(HELP_MIN_WIDTH, viewW) - viewW > 1
    LayoutHelpList(needBar)
    ZO_ScrollList_Clear(list)
    local scrollData = ZO_ScrollList_GetDataList(list)
    for i = 1, #helpEntries do
        local e = helpEntries[i]
        local rowType = e.kind == "help" and 2 or 1
        table.insert(scrollData, ZO_ScrollList_CreateDataEntry(rowType, e))
    end
    ZO_ScrollList_Commit(list)
    if type(ZO_ScrollList_ResetToTop) == "function" then
        ZO_ScrollList_ResetToTop(list)
    end
    UpdateHScrollBar()
end

function BasaTools.ClearOutput()
    outputLines = {}
    helpEntries = {}
    hScroll = 0
    SetOutputMode(false)
    RefreshOutputEdit()
end

function BasaTools.AppendLine(msg, r, g, b)
    local text = SanitizeForPanel(msg)
    if r == nil or g == nil or b == nil then
        r, g, b = InferColor(text)
    end
    outputLines[#outputLines + 1] = ColorizeLine(text, r, g, b)
    SetOutputMode(false)
    RefreshOutputEdit()
end

local function AppendHelpRow(action, slash, effect, r, g, b)
    helpEntries[#helpEntries + 1] = {
        kind = "help",
        action = SanitizeForPanel(action),
        slash = SanitizeForPanel(slash),
        effect = SanitizeForPanel(effect),
        r = r,
        g = g,
        b = b,
        text = SanitizeForPanel(string.format("%s  %s  %s", action or "", slash or "", effect or "")),
    }
end

function BasaTools.IsShown()
    local win = GetWindow()
    return win and win.IsHidden and not win:IsHidden()
end

local function ToolSink(msg, r, g, b)
    BasaTools.AppendLine(msg, r, g, b)
end

local function BindSinks()
    if WritMatch and type(WritMatch.SetOutputSink) == "function" then
        WritMatch.SetOutputSink(ToolSink)
    end
end

local function UnbindSinks()
    if WritMatch and type(WritMatch.SetOutputSink) == "function" then
        WritMatch.SetOutputSink(nil)
    end
    if LibScanner and type(LibScanner.SetOutputSink) == "function" then
        LibScanner.SetOutputSink(nil)
    end
end

local function SetControlHidden(control, hidden)
    if control and control.SetHidden then
        control:SetHidden(hidden)
    end
end

local function SetLabelInterfaceColor(label, textColor)
    if not label or not label.SetColor then
        return
    end
    local r, g, b = InterfaceRGB(textColor, COL_HEADER)
    label:SetColor(r, g, b, 1)
end

local function ApplyTabVisuals(selected, hoverId)
    for i = 1, #registeredTabs do
        local spec = registeredTabs[i]
        local tab = spec.tabControl
        if tab then
            local label = Child(tab, "Label")
            local icon = Child(tab, "Icon")
            local isSelected = spec.id == selected
            local isHover = spec.id == hoverId and not isSelected
            if label then
                if isSelected then
                    SetLabelInterfaceColor(label, INTERFACE_TEXT_COLOR_SELECTED)
                elseif isHover then
                    SetLabelInterfaceColor(label, INTERFACE_TEXT_COLOR_HIGHLIGHT)
                else
                    SetLabelInterfaceColor(label, INTERFACE_TEXT_COLOR_CONTRAST)
                end
            end
            if icon and icon.SetColor then
                if isSelected or isHover then
                    icon:SetColor(1, 1, 1, 1)
                else
                    icon:SetColor(0.55, 0.55, 0.5, 1)
                end
            end
        end
    end
end

local function FitTabWidth(tab, spec)
    local label = Child(tab, "Label")
    local title = (spec and spec.title) or ""
    local textW = math.max(48, math.ceil(#title * 9.5))
    if label then
        if label.SetText then
            label:SetText(title)
        end
        if label.GetStringWidth then
            local measured = label:GetStringWidth(title)
            if type(measured) == "number" and measured > 0 then
                textW = math.max(textW, math.ceil(measured))
            end
        end
        if label.SetDimensions then
            label:SetDimensions(textW + 4, 28)
        end
    end
    local w = 6 + 28 + 6 + textW + 10
    if w < 90 then
        w = 90
    end
    tab:SetDimensions(w, TAB_HEIGHT)
    return w
end

local function RaiseHeaderChrome()
    local win = GetWindow()
    if not win then
        return
    end
    local close = Child(win, "Close")
    if close then
        close:SetDimensions(32, 32)
        if close.SetHitInsets then
            close:SetHitInsets(-8, -8, 8, 8)
        end
        close:SetDrawTier(DT_HIGH)
        close:SetDrawLayer(DL_OVERLAY)
        close:SetDrawLevel(100)
        close:SetMouseEnabled(true)
    end
    local closeHit = Child(win, "CloseHit")
    if closeHit then
        closeHit:SetDrawTier(DT_HIGH)
        closeHit:SetDrawLayer(DL_OVERLAY)
        closeHit:SetDrawLevel(90)
        closeHit:SetMouseEnabled(true)
        if closeHit.SetAlpha then
            closeHit:SetAlpha(0)
        end
    end
end

local function LayoutTabs()
    local win = GetWindow()
    if not win then
        return
    end
    local x = TAB_ROW_X
    for i = 1, #registeredTabs do
        local spec = registeredTabs[i]
        local tab = spec.tabControl
        local ready = SpecAvailable(spec)
        SetControlHidden(tab, not ready)
        if ready and tab then
            local w = FitTabWidth(tab, spec)
            if tab.ClearAnchors then
                tab:ClearAnchors()
            end
            tab:SetAnchor(TOPLEFT, win, TOPLEFT, x, TAB_ROW_Y)
            x = x + w + TAB_GAP
        end
    end
    RaiseHeaderChrome()
end

local function FirstAvailableId()
    for i = 1, #registeredTabs do
        if SpecAvailable(registeredTabs[i]) then
            return registeredTabs[i].id
        end
    end
    return nil
end

local function BuildTabs()
    if tabsBuilt then
        return
    end
    local win = GetWindow()
    if not win or not WINDOW_MANAGER or not WINDOW_MANAGER.CreateControlFromVirtual then
        return
    end
    for i = 1, #registeredTabs do
        local spec = registeredTabs[i]
        if SpecAvailable(spec) then
            local tab = WINDOW_MANAGER:CreateControlFromVirtual(win:GetName() .. "Tab" .. spec.id, win, "BasaToolsTab")
            spec.tabControl = tab
            local icon = Child(tab, "Icon")
            local label = Child(tab, "Label")
            if icon and icon.SetTexture and spec.texture then
                icon:SetTexture(spec.texture)
            end
            if label and label.SetText then
                label:SetText(spec.title or spec.id)
            end
            if tab.SetHandler then
                tab:SetHandler("OnMouseUp", function(_, button, upInside)
                    if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
                        BasaTools.SetTab(spec.id)
                    end
                end)
                tab:SetHandler("OnMouseEnter", function()
                    ApplyTabVisuals(saved and saved.lastTab, spec.id)
                    ZO_Tooltips_ShowTextTooltip(tab, BOTTOM, spec.tooltip or spec.title or spec.id)
                end)
                tab:SetHandler("OnMouseExit", function()
                    ZO_Tooltips_HideTextTooltip()
                    ApplyTabVisuals(saved and saved.lastTab, nil)
                end)
            end

            local template = spec.panelTemplate or "BasaToolsWritMatchPanel"
            local panel = WINDOW_MANAGER:CreateControlFromVirtual(win:GetName() .. "Panel" .. spec.id, win, template)
            spec.panelControl = panel
            if panel then
                panel:SetHidden(true)
                if spec.fillPanel then
                    panel:ClearAnchors()
                    panel:SetAnchor(TOPLEFT, win, TOPLEFT, 20, PANEL_TOP)
                    panel:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -20, -20)
                else
                    local height = spec.usesOutput and BUTTONS_PANEL_H or COMPACT_PANEL_H
                    panel:ClearAnchors()
                    panel:SetAnchor(TOPLEFT, win, TOPLEFT, 20, PANEL_TOP)
                    panel:SetAnchor(TOPRIGHT, win, TOPRIGHT, -20, PANEL_TOP)
                    panel:SetHeight(height)
                end
                if type(spec.buildPanel) == "function" then
                    spec.buildPanel(panel)
                end
            end
        end
    end
    tabsBuilt = true
end

local function ShowOutputChrome(show)
    local win = GetWindow()
    SetControlHidden(Child(win, "OutputLabel"), not show)
    SetControlHidden(Child(win, "ClearOutput"), not show)
    SetControlHidden(GetOutputBackdrop(), not show)
end

function BasaTools.ForceShowOutput()
    ShowOutputChrome(true)
end

local function RefreshTabs()
    local win = GetWindow()
    if not win then
        return
    end
    BuildTabs()
    LayoutTabs()

    local tab = saved and saved.lastTab
    local spec = FindSpec(tab)
    if not spec or not SpecAvailable(spec) then
        tab = FirstAvailableId()
        spec = FindSpec(tab)
    end
    if saved and tab then
        saved.lastTab = tab
    end

    for i = 1, #registeredTabs do
        local s = registeredTabs[i]
        SetControlHidden(s.panelControl, s.id ~= tab)
    end

    local showOutput = spec and spec.usesOutput and true or false
    ShowOutputChrome(showOutput)
    ApplyTabVisuals(tab, nil)

    if spec and type(spec.onShown) == "function" then
        spec.onShown(spec.panelControl)
    end
end

function BasaTools.SetTab(tabName)
    local spec = FindSpec(tabName)
    if not spec or not SpecAvailable(spec) then
        return
    end
    if saved then
        saved.lastTab = tabName
    end
    RefreshTabs()
end

function BasaTools.Show()
    local win = GetWindow()
    if not win then
        return
    end
    EnsureListTypes()
    ConfigureOutputEdit(GetOutputEdit())
    RefreshTabs()
    BindSinks()
    win:SetHidden(false)
end

function BasaTools.Hide()
    local win = GetWindow()
    if win then
        win:SetHidden(true)
    end
    UnbindSinks()
end

function BasaTools.Toggle()
    if BasaTools.IsShown() then
        BasaTools.Hide()
    else
        BasaTools.Show()
    end
end

function BasaTools.ShowHelp(tabName)
    local spec = FindSpec(tabName) or CurrentSpec()
    if spec and type(spec.onHelp) == "function" then
        spec.onHelp(spec.panelControl)
        return
    end
    BasaTools.ClearOutput()
    ShowOutputChrome(true)
    local tool = rawget(_G, tabName)
    if not tool then
        BasaTools.AppendLine((tabName or "?") .. " is not loaded.", RGB(COL_BAD))
        return
    end
    if type(tool.GetHelpEntries) == "function" then
        local entries = tool.GetHelpEntries()
        if type(entries) == "table" then
            helpEntries = {}
            local intro = entries.intro
            if type(intro) == "table" then
                for i = 1, #intro do
                    local line = intro[i]
                    local text = type(line) == "table" and line.text or line
                    local r, g, b = COL_HEADER[1], COL_HEADER[2], COL_HEADER[3]
                    if i > 1 then
                        r, g, b = InterfaceRGB(INTERFACE_TEXT_COLOR_NORMAL, { 0.85, 0.85, 0.8 })
                    end
                    helpEntries[#helpEntries + 1] = { kind = "line", text = SanitizeForPanel(text), r = r, g = g, b = b }
                end
            end
            local rows = entries.rows
            if type(rows) == "table" and #rows > 0 then
                helpEntries[#helpEntries + 1] = { kind = "line", text = "", r = 1, g = 1, b = 1 }
                AppendHelpRow("Action", "Slash", "Effect", COL_HEADER[1], COL_HEADER[2], COL_HEADER[3])
                local nr, ng, nb = InterfaceRGB(INTERFACE_TEXT_COLOR_NORMAL, { 0.85, 0.85, 0.8 })
                for i = 1, #rows do
                    local row = rows[i]
                    AppendHelpRow(row.action, row.slash, row.effect, nr, ng, nb)
                end
            end
            RefreshHelpList()
            return
        end
    end
    if type(tool.GetHelpText) == "function" then
        local help = tool.GetHelpText()
        if type(help) == "string" then
            for line in string.gmatch(help, "[^\n]+") do
                BasaTools.AppendLine(line)
            end
            return
        end
    end
    BasaTools.AppendLine((tabName or "?") .. " has no help text.", RGB(COL_WARN))
end

function BasaTools.RunWritMatch(op)
    if not (WritMatch and type(WritMatch.Run) == "function") then
        BasaTools.ClearOutput()
        BasaTools.AppendLine("WritMatch is not loaded.", RGB(COL_BAD))
        return
    end
    BasaTools.ClearOutput()
    BindSinks()
    ShowOutputChrome(true)
    WritMatch.Run(op)
end

function BasaTools.RunLibScanner(op)
    if not (LibScanner and type(LibScanner.Run) == "function") then
        return
    end
    LibScanner.Run(op)
end

function BasaTools_SetTab(tabName)
    BasaTools.SetTab(tabName)
end

function BasaTools_ShowHelp(tabName)
    BasaTools.ShowHelp(tabName)
end

function BasaTools_RunWritMatch(op)
    BasaTools.RunWritMatch(op)
end

function BasaTools_RunLibScanner(op)
    BasaTools.RunLibScanner(op)
end

function BasaTools_ClearOutput()
    BasaTools.ClearOutput()
end

local function BindOutputChrome()
    if outputChromeBound then
        return
    end
    local slider = GetHScroll()
    if slider then
        if slider.SetOrientation then
            slider:SetOrientation(ORIENTATION_HORIZONTAL)
        end
        if slider.SetHandler then
            slider:SetHandler("OnValueChanged", function(_, value)
                if updatingSlider then
                    return
                end
                hScroll = value or 0
                ApplyHScrollToVisibleRows()
            end)
        end
    end
    ConfigureOutputEdit(GetOutputEdit())
    outputChromeBound = true
end

local function ApplyWindowSize()
    local win = GetWindow()
    if not win then
        return
    end
    if win.SetResizeHandleSize then
        win:SetResizeHandleSize(12)
    end
    if win.SetDimensionConstraints then
        win:SetDimensionConstraints(WIN_MIN_W, WIN_MIN_H, WIN_MAX_W, WIN_MAX_H)
    end
    local w = (saved and saved.width) or WIN_DEFAULT_W
    local h = (saved and saved.height) or WIN_DEFAULT_H
    if w < WIN_MIN_W then
        w = WIN_MIN_W
    end
    if h < WIN_MIN_H then
        h = WIN_MIN_H
    end
    if w > WIN_MAX_W then
        w = WIN_MAX_W
    end
    if h > WIN_MAX_H then
        h = WIN_MAX_H
    end
    win:SetDimensions(w, h)
end

local function BindWindowResize()
    local win = GetWindow()
    if not win or not win.SetHandler then
        return
    end
    win:SetHandler("OnResizeStop", function(control)
        if saved then
            saved.width = control:GetWidth()
            saved.height = control:GetHeight()
        end
        if showingHelp then
            UpdateHScrollBar()
            local list = GetHelpList()
            if list and type(ZO_ScrollList_Commit) == "function" then
                ZO_ScrollList_Commit(list)
            end
        end
    end)
end

local function Initialize()
    local defaults = {
        lastTab = "WritMatch",
        width = WIN_DEFAULT_W,
        height = WIN_DEFAULT_H,
        uiTweaks = {
            writVoucherOverlay = false,
            floatingIcon = false,
        },
        iconPos = { x = 40, y = 200 },
        matlogEnabled = true,
        matlogView = "full",
        matlogPriceSource = "npc",
        matlogDayKey = nil,
        matlogChar = "all",
        matlogCategory = "all",
        libScannerTab = "Libs",
        matlog = {},
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
    saved = ZO_SavedVars:NewAccountWide("BasaToolsSaved", 2, nil, defaults, profile, displayName)

    for i = 1, #registeredTabs do
        local spec = registeredTabs[i]
        if type(spec.onInit) == "function" then
            spec.onInit(saved)
        end
    end

    local win = GetWindow()
    if win then
        ApplyWindowSize()
        BindWindowResize()
        RaiseHeaderChrome()
        BindOutputChrome()
        EnsureListTypes()
        if win.SetHandler then
            win:SetHandler("OnShow", function()
                BindSinks()
                RefreshTabs()
                BindOutputChrome()
                if showingHelp then
                    UpdateHScrollBar()
                end
            end)
            win:SetHandler("OnHide", function()
                UnbindSinks()
            end)
        end
        RefreshTabs()
    end

    SLASH_COMMANDS["/basatools"] = function()
        BasaTools.Toggle()
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName == ADDON_NAME then
        Initialize()
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    end
end)
