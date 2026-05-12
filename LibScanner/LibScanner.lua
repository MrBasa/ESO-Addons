local LibScannerSavedVars

local ADDON_NAME = "LibScanner"

local addonData = {}
local currentSort = "name"
local sortAsc = true
local libsOutputLines = {}
local latestUnusedLibs = {}

local function RefreshLibsOutput()
    local outputControl = _G["LibScannerWindowLibsPanelOutput"]
    if outputControl then
        outputControl:SetText(table.concat(libsOutputLines, "\n"))
    end
end

local function ClearLibsOutput()
    libsOutputLines = {}
    RefreshLibsOutput()
end

local function AddLibsOutputLine(line)
    table.insert(libsOutputLines, tostring(line))
    RefreshLibsOutput()
end

function LibScanner_CopyUnusedLibs()
    local outputControl = _G["LibScannerWindowLibsPanelOutput"]
    if not outputControl then
        return
    end

    local copyLines = {"Unused Libraries (Safe to Delete):"}
    if #latestUnusedLibs == 0 then
        table.insert(copyLines, "None")
    else
        for _, libName in ipairs(latestUnusedLibs) do
            table.insert(copyLines, libName)
        end
    end

    outputControl:SetText(table.concat(copyLines, "\n"))
    outputControl:TakeFocus()
end

local function AddDebugMessage(message)
    local line = "|c9999FF[LibScanner]|r " .. tostring(message)
    AddLibsOutputLine(line)
    if type(d) == "function" then
        d("[LibScanner] " .. tostring(message))
    end
end

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
    addonData = {}
    ClearLibsOutput()

    local getAddOnManager = rawget(_G, "GetAddOnManager")
    AddDebugMessage("type(GetAddOnManager)=" .. tostring(type(getAddOnManager)))
    if type(getAddOnManager) ~= "function" then
        AddLibsOutputLine("|cFF3333Error: GetAddOnManager() unavailable.|r")
        return
    end

    local okManager, addOnManager = pcall(getAddOnManager)
    AddDebugMessage("GetAddOnManager() ok=" .. tostring(okManager) .. " type=" .. tostring(type(addOnManager)))
    if not okManager then
        AddLibsOutputLine("|cFF3333Error: GetAddOnManager() call failed.|r")
        return
    end

    if not addOnManager then
        AddLibsOutputLine("|cFF3333Error: AddOn manager unavailable.|r")
        return
    end

    local okNum, numAddOnsRaw = pcall(function() return addOnManager:GetNumAddOns() end)
    AddDebugMessage("GetNumAddOns() ok=" .. tostring(okNum) .. " value=" .. tostring(numAddOnsRaw))
    local numAddOns = okNum and (tonumber(numAddOnsRaw) or 0) or 0
    if numAddOns <= 0 then
        AddLibsOutputLine("|cFF3333Error: API returned 0 addons.|r")
        return
    end
    local requiredLibs = {}
    local installedLibs = {}
    local missingLibs = {}

    local function LooksLikeLibrary(addonName)
        return addonName ~= nil and string.find(string.lower(addonName), "^lib") ~= nil
    end
    
    -- Pass 1: catalog installed libraries from ESO's `isLibrary` flag.
    for i = 1, numAddOns do
        local name, _, _, _, _, _, _, isLibrary = addOnManager:GetAddOnInfo(i)
        if isLibrary then
            installedLibs[name] = true
        end
    end

    -- Pass 2: analyze enabled addons' dependencies to compute:
    -- - required libraries
    -- - missing libraries (for required deps that aren't installed)
    for i = 1, numAddOns do
        local name, title, _, _, enabled, _, isOutOfDate, isLibrary = addOnManager:GetAddOnInfo(i)
        local version = addOnManager:GetAddOnVersion(i)

        if enabled then
            local myMissingDeps = {}
            local numDeps = tonumber(addOnManager:GetAddOnNumDependencies(i)) or 0
            
            for j = 1, numDeps do
                local depName, depExists = addOnManager:GetAddOnDependencyInfo(i, j)
                
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
                    folder = name,
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
    latestUnusedLibs = unusedLibs

    -- Print to Libraries Panel (Global Overview)
    AddLibsOutputLine("|cFF3333--- Missing Libraries (Global) ---|r")
    local missingLibNames = {}
    for libName, _ in pairs(missingLibs) do
        table.insert(missingLibNames, libName)
    end
    table.sort(missingLibNames)
    if #missingLibNames == 0 then
        AddLibsOutputLine("None! All library dependencies met.")
    else
        for _, libName in ipairs(missingLibNames) do
            AddLibsOutputLine("- " .. libName)
        end
    end

    AddLibsOutputLine("")
    AddLibsOutputLine("|c33FF33--- Unused Libraries (Safe to Delete) ---|r")
    if #unusedLibs == 0 then
        AddLibsOutputLine("None! All installed libraries are actively used.")
    else
        for _, libName in ipairs(unusedLibs) do
            AddLibsOutputLine("- " .. libName)
        end
    end

    LibScanner_RefreshList()

    -- TSV for offline merge: see live/SavedVariables/LibScanner.lua → LibScannerSavedVars["lastExport"]
    local exportLines = { "folder\ttitle\tout_of_date\tversion\tmissing_deps" }
    for _, row in ipairs(addonData) do
        local ood = row.status == 1 and "yes" or "no"
        local md = row.missingDepsStr or ""
        md = string.gsub(md, "\t", " ")
        table.insert(
            exportLines,
            string.format("%s\t%s\t%s\t%s\t%s", row.folder or "", row.name or "", ood, row.version or "", md)
        )
    end
    LibScannerSavedVars.lastExport = table.concat(exportLines, "\n")
    LibScannerSavedVars.lastExportVersion = 1
end

local function Initialize()
    LibScannerSavedVars = ZO_SavedVars:NewAccountWide("LibScannerSavedVars", 1, nil, {
        lastExport = "",
        lastExportVersion = 0,
    })

    -- Link the XML List Template to the Lua Logic (Notice row height is now 50)
    ZO_ScrollList_AddDataType(LibScannerWindowVersionsPanelList, 1, "LibScannerVersionRow", 50, SetupRow)
    
    -- Register the single command to open the UI
    SLASH_COMMANDS["/libscan"] = function()
        RunScan()
        LibScannerWindow:SetHidden(false)
    end

    SLASH_COMMANDS["/libscanexport"] = function()
        RunScan()
        LibScannerWindow:SetHidden(false)
        local s = LibScannerSavedVars.lastExport or ""
        if type(d) == "function" then
            d("[LibScanner] TSV export length=" .. tostring(string.len(s)) .. " (also in LibScannerSavedVars.lastExport ; /reloadui then open SavedVariables/LibScanner.lua)")
        end
    end
end

-- Wait for the addon to load before initializing
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(event, addonName)
    if addonName == ADDON_NAME then
        Initialize()
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    end
end)
