local ADDON_NAME = "BasaTools"

BasaTools = BasaTools or {}

local saved = nil
local outputLines = {}
local tabsBound = false

local TAB_WRITMATCH = "WritMatch"
local TAB_LIBSCANNER = "LibScanner"

local TAB_SPEC = {
    {
        descriptor = TAB_WRITMATCH,
        control = "TabWritMatch",
        tooltip = "Reconcile sealed master writs with backpack gear.",
    },
    {
        descriptor = TAB_LIBSCANNER,
        control = "TabLibScanner",
        tooltip = "Scan enabled add-ons for library dependency problems.",
    },
}

local MAX_EDIT_CHARS = 20000
-- Chat input trims large StartTextEntry payloads; keep this short (LibScanner lesson).
local MAX_CHAT_COPY_CHARS = 700

local function Child(parent, name)
    if parent and parent.GetNamedChild then
        return parent:GetNamedChild(name)
    end
    return nil
end

local function GetWindow()
    return rawget(_G, "BasaToolsWindow")
end

local function GetOutputEdit()
    local backdrop = Child(GetWindow(), "OutputBackdrop")
    return Child(backdrop, "Edit")
end

--- Convert |H…|hName|h item links to plain names, then strip pipe markup.
--- EditBox applies ZO rich-text rules and truncates; do not feed |c / |H through.
local function SanitizeForEditBox(text)
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

local function RefreshEditBox()
    local edit = GetOutputEdit()
    if not edit or not edit.SetText then
        return
    end
    local text = table.concat(outputLines, "\n")
    if string.len(text) > MAX_EDIT_CHARS then
        text = string.sub(text, 1, MAX_EDIT_CHARS - 80)
            .. "\n... (truncated; select in this box, or use per-bucket copy for long lists)"
    end
    edit:SetText(text)
end

function BasaTools.ClearOutput()
    outputLines = {}
    RefreshEditBox()
end

function BasaTools.AppendLine(msg)
    outputLines[#outputLines + 1] = SanitizeForEditBox(msg)
    RefreshEditBox()
end

function BasaTools.IsShown()
    local win = GetWindow()
    return win and win.IsHidden and not win:IsHidden()
end

local function ToolSink(msg)
    BasaTools.AppendLine(msg)
end

local function BindSinks()
    if WritMatch and type(WritMatch.SetOutputSink) == "function" then
        WritMatch.SetOutputSink(ToolSink)
    end
    if LibScanner and type(LibScanner.SetOutputSink) == "function" then
        LibScanner.SetOutputSink(ToolSink)
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

local function ToolReady(name)
    local t = rawget(_G, name)
    return type(t) == "table" and type(t.Run) == "function"
end

local function SetControlHidden(control, hidden)
    if control and control.SetHidden then
        control:SetHidden(hidden)
    end
end

local function SetLabelInterfaceColor(label, textColor)
    if not label or not label.SetColor or type(GetInterfaceColor) ~= "function" then
        return
    end
    local r, g, b, a = GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, textColor)
    if r then
        label:SetColor(r, g, b, a or 1)
    end
end

local function ApplyTabColors(selected)
    local win = GetWindow()
    if not win then
        return
    end
    for i = 1, #TAB_SPEC do
        local spec = TAB_SPEC[i]
        local label = Child(win, spec.control)
        if label then
            if spec.descriptor == selected then
                SetLabelInterfaceColor(label, INTERFACE_TEXT_COLOR_SELECTED)
            else
                SetLabelInterfaceColor(label, INTERFACE_TEXT_COLOR_CONTRAST)
            end
        end
    end
end

local function LayoutTabs()
    local win = GetWindow()
    if not win then
        return
    end
    local x = 20
    for i = 1, #TAB_SPEC do
        local spec = TAB_SPEC[i]
        local label = Child(win, spec.control)
        local ready = ToolReady(spec.descriptor)
        SetControlHidden(label, not ready)
        if ready and label then
            if label.ClearAnchors then
                label:ClearAnchors()
            end
            label:SetAnchor(TOPLEFT, win, TOPLEFT, x, 52)
            local width = 130
            if label.GetTextWidth then
                local tw = label:GetTextWidth()
                if type(tw) == "number" then
                    width = math.max(tw + 12, 80)
                end
            end
            x = x + width + 20
        end
    end
end

local function BindTextTabs()
    if tabsBound then
        return
    end
    local win = GetWindow()
    if not win then
        return
    end
    for i = 1, #TAB_SPEC do
        local spec = TAB_SPEC[i]
        local label = Child(win, spec.control)
        if label and label.SetHandler then
            label:SetHandler("OnMouseUp", function(_, button, upInside)
                if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
                    BasaTools.SetTab(spec.descriptor)
                end
            end)
            label:SetHandler("OnMouseEnter", function(self)
                local selected = saved and saved.lastTab
                if spec.descriptor ~= selected then
                    SetLabelInterfaceColor(self, INTERFACE_TEXT_COLOR_HIGHLIGHT)
                end
                ZO_Tooltips_ShowTextTooltip(self, BOTTOM, spec.tooltip)
            end)
            label:SetHandler("OnMouseExit", function()
                ZO_Tooltips_HideTextTooltip()
                ApplyTabColors(saved and saved.lastTab)
            end)
        end
    end
    tabsBound = true
end

local function RefreshTabs()
    local win = GetWindow()
    if not win then
        return
    end
    BindTextTabs()
    LayoutTabs()

    local writReady = ToolReady(TAB_WRITMATCH)
    local libReady = ToolReady(TAB_LIBSCANNER)
    local panelWrit = Child(win, "WritMatchPanel")
    local panelLib = Child(win, "LibScannerPanel")
    local noTools = Child(win, "NoTools")

    SetControlHidden(noTools, writReady or libReady)

    local tab = saved and saved.lastTab or TAB_WRITMATCH
    if tab == TAB_WRITMATCH and not writReady then
        tab = libReady and TAB_LIBSCANNER or nil
    elseif tab == TAB_LIBSCANNER and not libReady then
        tab = writReady and TAB_WRITMATCH or nil
    end

    if tab == TAB_WRITMATCH then
        SetControlHidden(panelWrit, false)
        SetControlHidden(panelLib, true)
    elseif tab == TAB_LIBSCANNER then
        SetControlHidden(panelWrit, true)
        SetControlHidden(panelLib, false)
    else
        SetControlHidden(panelWrit, true)
        SetControlHidden(panelLib, true)
    end

    if saved and tab then
        saved.lastTab = tab
    end
    ApplyTabColors(tab)
end

function BasaTools.SetTab(tabName)
    if tabName ~= TAB_WRITMATCH and tabName ~= TAB_LIBSCANNER then
        return
    end
    if not ToolReady(tabName) then
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
    RefreshTabs()
    BindSinks()
    win:SetHidden(false)
    if #outputLines == 0 then
        BasaTools.AppendLine("BasaTools — pick a tab, then a button. Help on each tab explains that tool.")
        BasaTools.AppendLine("Output here is selectable. Chat still gets item links.")
    end
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

local function PutTextInChatInput(body, label)
    if type(body) ~= "string" or body == "" then
        BasaTools.AppendLine(string.format("%s: (nothing to copy).", label))
        return
    end
    if string.len(body) > MAX_CHAT_COPY_CHARS then
        BasaTools.AppendLine(
            string.format(
                "%s is %d characters — too long for chat input. Select text in the output box and Ctrl+C, or use per-bucket copy.",
                label,
                string.len(body)
            )
        )
        return
    end
    local chatAvailable = rawget(_G, "IsChatSystemAvailableForCurrentPlatform")
    if type(chatAvailable) == "function" and chatAvailable() and ZO_GetChatSystem then
        local chat = ZO_GetChatSystem()
        if chat and chat.StartTextEntry then
            chat:StartTextEntry(body, nil, nil, true)
            BasaTools.AppendLine(string.format("%s — in chat input line, Ctrl+C to copy.", label))
            return
        end
    end
    if type(StartChatInput) == "function" then
        StartChatInput(body)
        BasaTools.AppendLine(string.format("%s — in chat input line, Ctrl+C to copy.", label))
        return
    end
    BasaTools.AppendLine(string.format("%s: chat input unavailable. Select text in the output box.", label))
end

function BasaTools.CopyPaneToChat()
    local body = table.concat(outputLines, "\n")
    PutTextInChatInput(body, "Pane")
end

function BasaTools.ShowHelp(tabName)
    BasaTools.ClearOutput()
    local tool = rawget(_G, tabName)
    if tool and type(tool.GetHelpText) == "function" then
        local help = tool.GetHelpText()
        if type(help) == "string" then
            for line in string.gmatch(help, "[^\n]+") do
                BasaTools.AppendLine(line)
            end
            return
        end
    end
    BasaTools.AppendLine(tabName .. " is not loaded.")
end

function BasaTools.RunWritMatch(op)
    if not ToolReady(TAB_WRITMATCH) then
        BasaTools.ClearOutput()
        BasaTools.AppendLine("WritMatch is not loaded.")
        return
    end
    BasaTools.ClearOutput()
    BindSinks()
    WritMatch.Run(op)
end

function BasaTools.RunLibScanner(op)
    if not ToolReady(TAB_LIBSCANNER) then
        BasaTools.ClearOutput()
        BasaTools.AppendLine("LibScanner is not loaded.")
        return
    end
    if op ~= "open" and op ~= "debug" then
        BasaTools.ClearOutput()
    end
    BindSinks()
    LibScanner.Run(op)
end

function BasaTools.CopyLibScannerBucket(kind)
    if not ToolReady(TAB_LIBSCANNER) then
        BasaTools.AppendLine("LibScanner is not loaded.")
        return
    end
    if type(LibScanner.CopyBucket) == "function" then
        LibScanner.CopyBucket(kind)
    else
        BasaTools.AppendLine("LibScanner copy API is missing. Run Scan first.")
    end
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

function BasaTools_CopyLibScannerBucket(kind)
    BasaTools.CopyLibScannerBucket(kind)
end

function BasaTools_CopyPaneToChat()
    BasaTools.CopyPaneToChat()
end

function BasaTools_ClearOutput()
    BasaTools.ClearOutput()
end

local function Initialize()
    saved = ZO_SavedVars:NewAccountWide("BasaToolsSaved", 1, nil, { lastTab = TAB_WRITMATCH })

    local win = GetWindow()
    if win then
        if win.SetHandler then
            win:SetHandler("OnShow", function()
                BindSinks()
                RefreshTabs()
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
