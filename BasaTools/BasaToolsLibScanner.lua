BasaTools = BasaTools or {}

local panelBound = false
local setTabWrapped = false

local function PersistLibTab(tabName)
    local s = BasaTools.GetSaved and BasaTools.GetSaved()
    if s and type(tabName) == "string" and tabName ~= "" then
        s.libScannerTab = tabName
    end
end

local function WrapSetTab()
    if setTabWrapped or type(LibScanner_SetTab) ~= "function" then
        return
    end
    local orig = LibScanner_SetTab
    function LibScanner_SetTab(tabName)
        orig(tabName)
        PersistLibTab(tabName)
    end
    setTabWrapped = true
end

local function Child(parent, name)
    if BasaTools.Child then
        return BasaTools.Child(parent, name)
    end
    if parent and parent.GetNamedChild then
        return parent:GetNamedChild(name)
    end
    return nil
end

local function BindDebugCheck(panel)
    local control = Child(panel, "CheckDebug")
    if not control or not LibScanner then
        return
    end
    local on = type(LibScanner.IsDebug) == "function" and LibScanner.IsDebug()
    if on then
        ZO_CheckButton_SetChecked(control)
    else
        ZO_CheckButton_SetUnchecked(control)
    end
    ZO_CheckButton_SetLabelText(control, "Debug")
    ZO_CheckButton_SetToggleFunction(control, function()
        if type(LibScanner.SetDebug) == "function" then
            LibScanner.SetDebug(ZO_CheckButton_IsChecked(control))
        elseif type(LibScanner.Run) == "function" then
            LibScanner.Run("debug")
        end
    end)
    local label = control.label or Child(control, "Label")
    if label and label.SetHandler then
        label:SetHandler("OnMouseEnter", function()
            ZO_Tooltips_ShowTextTooltip(label, TOP, "Verbose LibScanner chat. Default is off. Same as /libscandebug.")
        end)
        label:SetHandler("OnMouseExit", function()
            ZO_Tooltips_HideTextTooltip()
        end)
    end
end

local function HostPanel(panel)
    if not panel or not LibScanner or type(LibScanner.SetHost) ~= "function" then
        BindDebugCheck(panel)
        return
    end
    if not panelBound then
        local libsPane = Child(panel, "LibsPane")
        local versionsPane = Child(panel, "VersionsPane")
        local libsBackdrop = Child(libsPane, "Backdrop")
        local libsEdit = Child(libsBackdrop, "Edit")
        local versionsList = Child(versionsPane, "List")
        LibScanner.SetHost({
            versionsList = versionsList,
            libsEdit = libsEdit,
            libsPanel = libsPane,
            versionsPanel = versionsPane,
            show = function()
                BasaTools.Show()
                BasaTools.SetTab("LibScanner")
            end,
        })
        WrapSetTab()
        local s = BasaTools.GetSaved and BasaTools.GetSaved()
        local inner = (s and s.libScannerTab) or "Libs"
        if type(LibScanner_SetTab) == "function" then
            LibScanner_SetTab(inner)
        end
        panelBound = true
    end
    BindDebugCheck(panel)
end

BasaTools.RegisterTab({
    id = "LibScanner",
    title = "LibScanner",
    tooltip = "Scan enabled add-ons for library dependency problems.",
    texture = "EsoUI/Art/Journal/journal_tabIcon_loreLibrary_up.dds",
    panelTemplate = "BasaToolsLibScannerPanel",
    usesOutput = false,
    fillPanel = true,
    available = function()
        local t = rawget(_G, "LibScanner")
        return type(t) == "table" and type(t.Run) == "function"
    end,
    buildPanel = function(panel)
        HostPanel(panel)
    end,
    onShown = function(panel)
        HostPanel(panel)
        BindDebugCheck(panel)
    end,
    onHelp = function()
        if LibScanner and type(LibScanner.ShowHostHelp) == "function" then
            LibScanner.ShowHostHelp()
        end
    end,
})
