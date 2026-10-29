BasaTools = BasaTools or {}

BasaTools.RegisterTab({
    id = "WritMatch",
    title = "WritMatch",
    tooltip = "Reconcile sealed master writs with backpack gear.",
    texture = "EsoUI/Art/Tutorial/smithing_tabicon_creation_up.dds",
    panelTemplate = "BasaToolsWritMatchPanel",
    usesOutput = true,
    fillPanel = false,
    available = function()
        local t = rawget(_G, "WritMatch")
        return type(t) == "table" and type(t.Run) == "function"
    end,
})
