-- Shared helpers for BasaTools suite tools (WritMatch, LibScanner, MatLog).
BasaTools = BasaTools or {}

local loggers = {}
local boundChecks = {}

local function ChatSystem(msg)
    if CHAT_ROUTER and type(CHAT_ROUTER.AddSystemMessage) == "function" then
        CHAT_ROUTER:AddSystemMessage(msg)
    elseif type(d) == "function" then
        d(msg)
    end
end

--- Chat progress for SavedVariables / data migrations (suite-wide).
--- phase: "start" | "ok" | "fail"
function BasaTools.NotifyMigration(addonName, description, phase, detail)
    local who = addonName or "BasaTools"
    local what = description or "data migration"
    local suffix = ""
    if type(detail) == "string" and detail ~= "" then
        suffix = " — " .. detail
    end
    if phase == "start" then
        ChatSystem(string.format("[%s] Migrating: %s…", who, what))
        return
    end
    if phase == "ok" then
        ChatSystem(string.format("[%s] Migration OK: %s%s", who, what, suffix))
        return
    end
    if phase == "fail" then
        ChatSystem(string.format("[%s] Migration FAILED: %s%s", who, what, suffix))
        return
    end
    ChatSystem(string.format("[%s] Migration (%s): %s%s", who, tostring(phase), what, suffix))
end

function BasaTools.GetLogger(addonName)
    local name = addonName or "BasaTools"
    if loggers[name] then
        return loggers[name]
    end
    local lib = rawget(_G, "LibDebugLogger")
    local logger
    if type(lib) == "function" then
        logger = lib(name)
    elseif type(lib) == "table" and type(lib.Create) == "function" then
        logger = lib.Create(name)
    else
        logger = {
            Debug = function() end,
            Info = function() end,
            Warn = function(_, msg)
                if type(d) == "function" then
                    d(name .. ": " .. tostring(msg))
                end
            end,
            Error = function(_, msg)
                if type(d) == "function" then
                    d(name .. " ERROR: " .. tostring(msg))
                end
            end,
        }
    end
    loggers[name] = logger
    return logger
end

function BasaTools.Child(parent, name)
    if parent and parent.GetNamedChild then
        return parent:GetNamedChild(name)
    end
    return nil
end

--- Sanitize pipe markup for panel / EditBox display.
--- opts.stripItemLinks (default true): replace |H links with names
--- opts.editBoxStrict (default false): also strip /c mangled colors and trim
function BasaTools.SanitizeMarkup(text, opts)
    opts = opts or {}
    if text == nil then
        return ""
    end
    local s = tostring(text)
    local stripLinks = opts.stripItemLinks ~= false
    if stripLinks then
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
    end
    s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|C%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    s = string.gsub(s, "|R", "")
    if opts.editBoxStrict then
        s = string.gsub(s, "/c%x%x%x%x%x%x%x%x", "")
        s = string.gsub(s, "/C%x%x%x%x%x%x%x%x", "")
        s = string.gsub(s, "/r", "")
        s = string.gsub(s, "/R", "")
    end
    s = string.gsub(s, "|", " ")
    s = string.gsub(s, "%[", "(")
    s = string.gsub(s, "%]", ")")
    if opts.editBoxStrict then
        s = string.gsub(s, "^%s+", "")
        s = string.gsub(s, "%s+$", "")
    end
    return s
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

function BasaTools.ColorizeLine(text, r, g, b)
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

function BasaTools.BindCheck(control, label, tooltip, getFn, setFn)
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
            local tipLabel = control.label or BasaTools.Child(control, "Label")
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

--- Clear a ZO_ScrollList and commit data entries of a single type.
function BasaTools.CommitScrollList(list, entries, dataType, resetToTop)
    if not list or type(ZO_ScrollList_Clear) ~= "function" then
        return
    end
    dataType = dataType or 1
    ZO_ScrollList_Clear(list)
    local scrollData = ZO_ScrollList_GetDataList(list)
    for i = 1, #entries do
        table.insert(scrollData, ZO_ScrollList_CreateDataEntry(dataType, entries[i]))
    end
    ZO_ScrollList_Commit(list)
    if resetToTop ~= false and type(ZO_ScrollList_ResetToTop) == "function" then
        ZO_ScrollList_ResetToTop(list)
    end
end
