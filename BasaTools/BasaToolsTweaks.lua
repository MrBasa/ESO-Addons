local ADDON_NAME = "BasaTools"
local OVERLAY_CHILD = "BasaToolsGv"
local HUD_TEXTURE = "BasaTools/textures/hud.dds"

BasaTools = BasaTools or {}
BasaTools.Tweaks = BasaTools.Tweaks or {}

local Tweaks = BasaTools.Tweaks
local saved = nil
local overlayHooked = {}
local hudFragment = nil

local INVENTORY_LISTS = {
    "ZO_PlayerInventoryList",
    "ZO_PlayerBankBackpack",
    "ZO_GuildBankBackpack",
    "ZO_HouseBankBackpack",
}

local function Child(parent, name)
    if BasaTools.Child then
        return BasaTools.Child(parent, name)
    end
    if parent and parent.GetNamedChild then
        return parent:GetNamedChild(name)
    end
    return nil
end

local function TweaksTable()
    if not saved then
        return nil
    end
    if type(saved.uiTweaks) ~= "table" then
        saved.uiTweaks = {}
    end
    return saved.uiTweaks
end

local function WritWorthyReady()
    local ww = rawget(_G, "WritWorthy")
    return type(ww) == "table" and type(ww.GetMatCost) == "function" and type(ww.ToVoucherCount) == "function"
end

local function FormatGoldPerVoucher(gold)
    if type(gold) ~= "number" then
        return ""
    end
    local n = zo_round(gold)
    if type(ZO_CommaDelimitNumber) == "function" then
        return ZO_CommaDelimitNumber(n) .. " g/v"
    end
    return tostring(n) .. " g/v"
end

local function EnsureGvLabel(row)
    local label = Child(row, OVERLAY_CHILD)
    if label then
        return label
    end
    if not WINDOW_MANAGER or not WINDOW_MANAGER.CreateControl then
        return nil
    end
    label = WINDOW_MANAGER:CreateControl(row:GetName() .. OVERLAY_CHILD, row, CT_LABEL)
    label:SetFont("ZoFontGameSmall")
    label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetDimensions(96, 18)
    label:SetDrawTier(DT_HIGH)
    label:SetHidden(true)
    local valueControl = Child(row, "SellPriceText") or Child(row, "SellPrice")
    if valueControl then
        label:SetAnchor(RIGHT, valueControl, LEFT, -6, 0)
    else
        label:SetAnchor(RIGHT, row, RIGHT, -80, 0)
    end
    return label
end

local function ClearGvLabel(row)
    local label = Child(row, OVERLAY_CHILD)
    if label then
        label:SetText("")
        label:SetHidden(true)
    end
end

local function OverlayRow(control, data)
    local tweaks = TweaksTable()
    if not tweaks or not tweaks.writVoucherOverlay then
        if control then
            ClearGvLabel(control)
        end
        return
    end
    if not control or type(data) ~= "table" then
        return
    end
    if not WritWorthyReady() then
        ClearGvLabel(control)
        return
    end
    local bagId, slotIndex = data.bagId, data.slotIndex
    if bagId == nil or slotIndex == nil or type(GetItemLink) ~= "function" then
        ClearGvLabel(control)
        return
    end
    local link = GetItemLink(bagId, slotIndex)
    if type(link) ~= "string" or link == "" then
        ClearGvLabel(control)
        return
    end
    if GetItemLinkItemType(link) ~= ITEMTYPE_MASTER_WRIT then
        ClearGvLabel(control)
        return
    end
    local vouchers = WritWorthy.ToVoucherCount(link)
    if type(vouchers) ~= "number" or vouchers <= 0 then
        ClearGvLabel(control)
        return
    end
    local matGold = WritWorthy.GetMatCost(link)
    if type(matGold) ~= "number" then
        ClearGvLabel(control)
        return
    end
    local label = EnsureGvLabel(control)
    if not label then
        return
    end
    label:SetText(FormatGoldPerVoucher(matGold / vouchers))
    label:SetHidden(false)
end

local function TryHookInventoryLists()
    if type(SecurePostHook) ~= "function" or type(ZO_ScrollList_GetDataTypeTable) ~= "function" then
        return
    end
    for i = 1, #INVENTORY_LISTS do
        local name = INVENTORY_LISTS[i]
        if not overlayHooked[name] then
            local list = rawget(_G, name)
            if list then
                local dataType = ZO_ScrollList_GetDataTypeTable(list, 1)
                if dataType and dataType.setupCallback then
                    SecurePostHook(dataType, "setupCallback", OverlayRow)
                    overlayHooked[name] = true
                end
            end
        end
    end
end

local function GetHudIcon()
    return rawget(_G, "BasaToolsHudIcon")
end

local function SaveHudPos()
    local icon = GetHudIcon()
    if not icon or not saved then
        return
    end
    if type(saved.iconPos) ~= "table" then
        saved.iconPos = {}
    end
    saved.iconPos.x = icon:GetLeft()
    saved.iconPos.y = icon:GetTop()
end

local function RestoreHudPos()
    local icon = GetHudIcon()
    if not icon or not saved then
        return
    end
    local pos = saved.iconPos
    local x = 40
    local y = 200
    if type(pos) == "table" then
        if type(pos.x) == "number" then
            x = pos.x
        end
        if type(pos.y) == "number" then
            y = pos.y
        end
    end
    if icon.ClearAnchors then
        icon:ClearAnchors()
    end
    icon:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

local function EnsureHudFragment()
    local icon = GetHudIcon()
    if not icon then
        return nil
    end
    if hudFragment then
        return hudFragment
    end
    if not ZO_SimpleSceneFragment or type(ZO_SimpleSceneFragment.New) ~= "function" then
        return nil
    end
    hudFragment = ZO_SimpleSceneFragment:New(icon)
    return hudFragment
end

local function SetHudFragmentEnabled(enable)
    local fragment = EnsureHudFragment()
    local icon = GetHudIcon()
    if icon then
        icon:SetHidden(not enable)
        local tex = Child(icon, "Icon")
        if tex and tex.SetTexture then
            tex:SetTexture(HUD_TEXTURE)
        end
    end
    if not fragment then
        return
    end
    local scenes = { HUD_SCENE, HUD_UI_SCENE }
    for i = 1, #scenes do
        local scene = scenes[i]
        if scene then
            if enable then
                if scene.AddFragment then
                    scene:AddFragment(fragment)
                end
            elseif scene.RemoveFragment then
                scene:RemoveFragment(fragment)
            end
        end
    end
end

function Tweaks.ApplyHudIcon()
    local tweaks = TweaksTable()
    local enable = tweaks and tweaks.floatingIcon and true or false
    local icon = GetHudIcon()
    if enable then
        RestoreHudPos()
        if icon and icon.SetHandler then
            icon:SetHandler("OnMouseUp", function(_, button, upInside)
                if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
                    BasaTools.Toggle()
                end
            end)
            icon:SetHandler("OnMoveStop", function()
                SaveHudPos()
            end)
            icon:SetHandler("OnMouseEnter", function()
                ZO_Tooltips_ShowTextTooltip(icon, BOTTOM, "BasaTools — click to toggle (/basatools)")
            end)
            icon:SetHandler("OnMouseExit", function()
                ZO_Tooltips_HideTextTooltip()
            end)
        end
    end
    SetHudFragmentEnabled(enable)
end

function Tweaks.ApplyOverlay()
    TryHookInventoryLists()
end

local boundChecks = {}

local function BindCheck(control, label, tooltip, getFn, setFn)
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
            local tipLabel = control.label or Child(control, "Label")
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

local function OverlayTooltip()
    if WritWorthyReady() then
        return "Show crafting-mat gold per writ voucher on sealed master writs in inventory. Does not replace the sell-price column."
    end
    return "Requires WritWorthy. Enable WritWorthy to show mat-cost gold per voucher on sealed master writs."
end

local function WidenCheckLabel(control)
    local tipLabel = control and (control.label or Child(control, "Label"))
    if tipLabel and tipLabel.SetWidth then
        tipLabel:SetWidth(640)
    end
    if tipLabel and tipLabel.SetWrapMode and TEXT_WRAP_MODE_ELLIPSIS then
        tipLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
end

function Tweaks.BindPanel(panel)
    if not panel then
        local win = BasaTools.GetWindow and BasaTools.GetWindow()
        panel = Child(win, "PanelUITweaks")
    end
    if not panel then
        return
    end
    local tweaks = TweaksTable()
    if not tweaks then
        return
    end

    local intro = Child(panel, "Intro")
    if intro and intro.SetText then
        intro:SetText("Options below are saved for the whole account.")
    end

    BindCheck(
        Child(panel, "CheckOverlay"),
        "Show gold per voucher on sealed master writs in inventory",
        OverlayTooltip(),
        function()
            return tweaks.writVoucherOverlay and true or false
        end,
        function(checked)
            tweaks.writVoucherOverlay = checked and true or false
            Tweaks.ApplyOverlay()
        end
    )
    WidenCheckLabel(Child(panel, "CheckOverlay"))
    BindCheck(
        Child(panel, "CheckIcon"),
        "Show a movable HUD icon to open this window",
        "Click the HUD icon to toggle BasaTools (same as /basatools). Drag to reposition.",
        function()
            return tweaks.floatingIcon and true or false
        end,
        function(checked)
            tweaks.floatingIcon = checked and true or false
            Tweaks.ApplyHudIcon()
        end
    )
    WidenCheckLabel(Child(panel, "CheckIcon"))
end

function Tweaks.OnPanelShown(panel)
    Tweaks.BindPanel(panel)
end

function Tweaks.Initialize(savedVars)
    saved = savedVars
    local tweaks = TweaksTable()
    if tweaks then
        if tweaks.writVoucherOverlay == nil then
            tweaks.writVoucherOverlay = false
        end
        if tweaks.floatingIcon == nil then
            tweaks.floatingIcon = false
        end
    end
    Tweaks.ApplyOverlay()
    Tweaks.ApplyHudIcon()
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Tweaks", EVENT_PLAYER_ACTIVATED, function()
        TryHookInventoryLists()
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "Tweaks", EVENT_PLAYER_ACTIVATED)
    end)
end

BasaTools.RegisterTab({
    id = "UITweaks",
    title = "Tweaks",
    tooltip = "Inventory overlay and HUD icon.",
    texture = HUD_TEXTURE,
    panelTemplate = "BasaToolsTweaksPanel",
    usesOutput = false,
    fillPanel = true,
    available = function()
        return true
    end,
    buildPanel = function(panel)
        Tweaks.BindPanel(panel)
    end,
    onShown = function(panel)
        Tweaks.OnPanelShown(panel)
    end,
    onInit = function(savedVars)
        Tweaks.Initialize(savedVars)
    end,
})
