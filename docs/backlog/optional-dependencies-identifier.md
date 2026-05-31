# ESO Addon Enhancement: Reverse-Mapping Optional Dependencies

This document outlines the technical problem, structural logic, and specific API hooks needed to build an Elder Scrolls Online (ESO) addon enhancement that displays which parent addons are requesting an optional library.

---

## Part 1: The Core Problem (One-Way Mapping)

The reason the base game UI (and managers like Votan's or Addon Selector) do not show what an optional library is used for comes down to the game engine's data structure. It is strictly **top-down**.

1. **Parent-to-Child:** An addon knows exactly what libraries it needs (parsed from the `DependsOn` and `OptionalDependsOn` lines in the `.txt` manifest).
2. **Child-to-Parent:** A library has absolutely no idea which addons are looking for it. 

To solve this without lagging the game menu, you must perform a reverse-lookup exactly once during the UI initialization phase, cache the results in memory, and inject that data into the game's tooltip system on demand.

---

## Part 2: Implementation Blueprint

### Phase 1: Build a Reverse-Map Cache
Instead of querying on demand, build a lookup table when your addon initializes (e.g., hook to `EVENT_ADD_ON_LOADED`). 

You will iterate over all installed addons using the game's global `AddOnManager` to construct a Lua table where keys are library names and values are arrays of the parent addons requesting them.

```lua
local optionalRequesters = {}
local manager = GetAddOnManager()

-- Iterate through every addon installed
for i = 1, manager:GetNumAddOns() do
    -- Get baseline info
    local addonName, _, _, _, _, _, isOptional = manager:GetAddOnInfo(i)
    
    -- Iterate through the dependencies of this specific addon
    for j = 1, manager:GetAddOnNumDependencies(i) do
        local depName, depActive, depRequired = manager:GetAddOnDependencyInfo(i, j)
        
        -- If it's NOT required, it is an optional dependency
        if not depRequired then
            -- Initialize the table for this dependency if it doesn't exist
            if not optionalRequesters[depName] then
                optionalRequesters[depName] = {}
            end
            
            -- Add the parent addon to this dependency's list
            table.insert(optionalRequesters[depName], addonName)
        end
    end
end
```

### Phase 2: Hooking the Vanilla UI Tooltip

To display this data, you need to intercept the game's UI rendering when a user hovers over an item in the addon list.

**The ZOS Target File & Function:**
* **Source File:** `esoui/pregameandingame/addons/zo_addonmanager.lua`
* **Target Object:** `ZO_AddOnManager`
* **Target Function:** `OnMouseEnter(control)`
* **Tooltip Control:** `InformationTooltip`

When a user hovers over an addon row, `ZO_AddOnManager:OnMouseEnter(control)` is fired to populate the tooltip with dependency information. You can use `SecurePostHook` to append your custom data immediately after the vanilla UI finishes drawing its text.

```lua
-- Hook into the AddOnManager's mouse enter event
SecurePostHook(ZO_AddOnManager, "OnMouseEnter", function(self, control)
    -- Ensure the row has data
    if not control or not control.data then return end
    
    -- Grab the name of the addon/library being hovered over
    local hoveredName = control.data.addOnName
    
    -- Check if our cached table has this name recorded as an optional dependency
    if optionalRequesters[hoveredName] then
        -- We have a match! Concatenate the list of requesters
        local requestersString = table.concat(optionalRequesters[hoveredName], ", ")
        
        -- Inject into the vanilla tooltip
        -- Adds a visual divider line first
        ZO_Tooltip_AddDivider(InformationTooltip)
        
        -- Add our custom text (You can color code this using ZO_ColorDef)
        InformationTooltip:AddLine("Optional for: " .. requestersString, "ZoFontGame", 1, 1, 1, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_LEFT, true)
    end
end)
```

### Summary of Workflow
1. Game loads `EVENT_ADD_ON_LOADED`.
2. Your script silently scans all `GetAddOnDependencyInfo()` arrays and maps every optional library back to its parent.
3. User opens the Add-Ons menu.
4. User hovers over `LibCustomMenu`.
5. Vanilla UI fires `ZO_AddOnManager:OnMouseEnter`.
6. Vanilla UI draws standard tooltip text.
7. Your `SecurePostHook` fires, checks the cache for `LibCustomMenu`, sees it is requested by 3 addons, and appends that list to the bottom of the active tooltip.
