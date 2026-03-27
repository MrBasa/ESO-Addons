local addonData = {}
local currentSort = "name"
local sortAsc = true

-- Tab Switching
function LibScanner_SetTab(tabName)
    LibScannerWindowLibsPanel:SetHidden(tabName ~= "Libs")
    LibScannerWindowVersionsPanel:SetHidden(tabName ~= "Versions")
end

-- Sorting Trigger
function LibScanner_SortBy(key)
    if currentSort == key then
        sortAsc = not sortAsc -- Toggle order if clicking the same column
    else
        currentSort = key
        sortAsc = true
    end
    LibScanner_RefreshList()
end

-- Sorting Logic
local function SortAddonData()
    table.sort(addonData, function(a, b)
        local valA = a[currentSort]
        local valB = b[currentSort]
        
        -- Make string sorting case-insensitive
        if currentSort == "name" or currentSort == "version" then
            valA = string.lower(tostring(valA))
            valB = string.lower(tostring(valB))
        end
        
        -- Fallback to name if values are identical
        if valA == valB then 
            return string.lower(a.name) < string.lower(b.name)
        end
        
        if sortAsc then
            return valA < valB
        else
            return valA > valB
        end
    end)
end

-- Bind data to the UI Row
local function SetupRow(control, data)
    control:GetNamedChild("Name"):SetText(data.name)
    control:GetNamedChild("Status"):SetText(data.statusText)
    control:GetNamedChild("Version"):SetText(data.version)
    
    local missingDepsLabel = control:GetNamedChild("MissingDeps")
    missingDepsLabel:SetText(data.missingDepsStr)
    
    if data.missingDepsStr == "" then
        missingDepsLabel:SetHidden(true)
    else
        missingDepsLabel:SetHidden(false)
    end
end

-- Redraw the List
function LibScanner_RefreshList()
    SortAddonData()
    local scrollData = ZO_ScrollList_GetDataList(LibScannerWindowVersionsPanelList)
    ZO_ScrollList_Clear(LibScannerWindowVersionsPanelList)
    
    for _, data in ipairs(addonData) do
        table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, data))
    end
    ZO_ScrollList_Commit(LibScannerWindowVersionsPanelList)
end

-- Main Scan Execution
local function RunScan()
    local numAddOns = AddOnManager:GetNumAddOns()
    local requiredLibs = {}
    local installedLibs = {}
    local missingLibs = {}

    local function LooksLikeLibrary(addonName)
        return addonName ~= nil and string.find(string.lower(addonName), "^lib") ~= nil
    end
    
    addonData = {}
    LibScannerWindowLibsPanelText:Clear()

    -- Pass 1: catalog installed libraries from ESO's `isLibrary` flag.
    for i = 1, numAddOns do
        local name, _, _, _, _, _, _, isLibrary = AddOnManager:GetAddOnInfo(i)
        if isLibrary then
            installedLibs[name] = true
        end
    end

    -- Pass 2: analyze enabled addons' dependencies to compute:
    -- - required libraries
    -- - missing libraries (for required deps that aren't installed)
    for i = 1, numAddOns do
        local name, title, _, _, enabled, _, isOutOfDate, isLibrary = AddOnManager:GetAddOnInfo(i)
        local version = AddOnManager:GetAddOnVersion(i)

        if enabled then
            local myMissingDeps = {}
            local numDeps = AddOnManager:GetAddOnNumDependencies(i)
            
            for j = 1, numDeps do
                local depName, depExists = AddOnManager:GetAddOnDependencyInfo(i, j)
                
                -- Record any missing dependency for this specific addon's row
                if not depExists then
                    table.insert(myMissingDeps, depName)
                end
                
                -- Keep cataloging global library dependencies for the Libraries tab
                if installedLibs[depName] then
                    requiredLibs[depName] = true
                elseif (not depExists) and LooksLikeLibrary(depName) then
                    -- We only know "library-ness" for missing dependencies via naming heuristic.
                    requiredLibs[depName] = true
                    missingLibs[depName] = true
                end
            end
            
            -- Process Addon Data for Versions Tab (skip libraries to reduce clutter)
            if not isLibrary and not LooksLikeLibrary(name) then
                -- ESO color codes are `|c` + 8 hex digits.
                local cleanTitle = string.gsub(title, "|c%x%x%x%x%x%x%x%x", "")
                cleanTitle = string.gsub(cleanTitle, "|r", "")
                
                local statusText = isOutOfDate and "|cFF3333No|r" or "|c33FF33Yes|r"
                local sortStatus = isOutOfDate and 1 or 2
                
                -- Format the missing dependencies string for the sub-label
                local missingStr = ""
                if #myMissingDeps > 0 then
                    missingStr = "Missing: " .. table.concat(myMissingDeps, ", ")
                end
                
                table.insert(addonData, {
                    name = cleanTitle,
                    status = sortStatus,
                    statusText = statusText,
                    version = tostring(version),
                    missingDepsStr = missingStr
                })
            end
        end
    end

    -- Identify orphaned libraries
    local unusedLibs = {}
    for libName, _ in pairs(installedLibs) do
        if not requiredLibs[libName] then
            table.insert(unusedLibs, libName)
        end
    end
    table.sort(unusedLibs)

    -- Print to Libraries Panel (Global Overview)
    LibScannerWindowLibsPanelText:AddMessage("|cFF3333--- Missing Libraries (Global) ---|r")
    local missingLibNames = {}
    for libName, _ in pairs(missingLibs) do
        table.insert(missingLibNames, libName)
    end
    table.sort(missingLibNames)
    if #missingLibNames == 0 then
        LibScannerWindowLibsPanelText:AddMessage("None! All library dependencies met.")
    else
        for _, libName in ipairs(missingLibNames) do
            LibScannerWindowLibsPanelText:AddMessage("- " .. libName)
        end
    end

    LibScannerWindowLibsPanelText:AddMessage("\n|c33FF33--- Unused Libraries (Safe to Delete) ---|r")
    if #unusedLibs == 0 then
        LibScannerWindowLibsPanelText:AddMessage("None! All installed libraries are actively used.")
    else
        for _, libName in ipairs(unusedLibs) do
            LibScannerWindowLibsPanelText:AddMessage("- " .. libName)
        end
    end

    LibScanner_RefreshList()
end

local function Initialize()
    -- Link the XML List Template to the Lua Logic (Notice row height is now 50)
    ZO_ScrollList_AddDataType(LibScannerWindowVersionsPanelList, 1, "LibScannerVersionRow", 50, SetupRow)
    
    -- Register the single command to open the UI
    SLASH_COMMANDS["/libscan"] = function()
        RunScan()
        LibScannerWindow:SetHidden(false)
    end
end

-- Wait for the addon to load before initializing
EVENT_MANAGER:RegisterForEvent("LibScanner", EVENT_ADD_ON_LOADED, function(event, addonName)
    if addonName == "LibScanner" then
        Initialize()
        EVENT_MANAGER:UnregisterForEvent("LibScanner", EVENT_ADD_ON_LOADED)
    end
end)
