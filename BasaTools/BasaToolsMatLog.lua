BasaTools = BasaTools or {}

BasaTools.RegisterTab({
    id = "MatLog",
    title = "MatLog",
    tooltip = "Track gathered materials, surveys, and master writs.",
    texture = "EsoUI/Art/Inventory/inventory_tabIcon_crafting_up.dds",
    panelTemplate = "MatLogPanel",
    usesOutput = false,
    fillPanel = true,
    available = function()
        local t = rawget(_G, "MatLog")
        return type(t) == "table" and type(t.BindPanel) == "function"
    end,
    buildPanel = function(panel)
        if MatLog and type(MatLog.BindPanel) == "function" then
            MatLog.BindPanel(panel)
        end
    end,
    onShown = function(panel)
        if MatLog and type(MatLog.OnPanelShown) == "function" then
            MatLog.OnPanelShown(panel)
        end
    end,
    onHelp = function()
        if MatLog and type(MatLog.ShowHelp) == "function" then
            MatLog.ShowHelp()
        end
    end,
})
