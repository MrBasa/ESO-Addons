local LibScannerSavedVars

local ADDON_NAME = "LibScanner"

LibScanner = LibScanner or {}

local addonData = {}
local currentSort = "name"
local sortAsc = true
local libsOutputLines = {}
local latestOptionalLibs = {}
local latestUnusedLibs = {}
local latestBrokenDeps = {}
local lastManifestReadCount = 0
local SetupRow

--- Optional line sink (BasaTools). Status/summary go to the sink; lists render in the host UI.
local outputSink = nil
local host = {
    versionsList = nil,
    libsEdit = nil,
    libsPanel = nil,
    versionsPanel = nil,
    show = nil,
    versionsTypeReady = false,
}

function LibScanner.SetOutputSink(fn)
    if fn == nil or type(fn) == "function" then
        outputSink = fn
    end
end

local function EmitStatus(msg, r, g, b)
    if type(outputSink) == "function" then
        outputSink(msg, r, g, b)
    end
end

--- Split manifest dependency tokens (e.g. LibFoo>=12) into bare add-on folder names.
local function AddManifestDependencyTokensToSet(line, set)
    if type(set) ~= "table" or line == nil or line == "" then
        return
    end
    for token in string.gmatch(line, "%S+") do
        local dep = string.match(token, "^([^>=%(]+)")
        if dep and dep ~= "" then
            set[dep] = true
        end
    end
end

--- Read ## DependsOn / ## OptionalDependsOn / ## PCDependsOn from disk (manifest). Returns depLine, optLine, readOk.
--- Note: `return "", "", false` must be explicit — `local empty = "", "", false` only binds the first value in Lua 5.1.
local function ReadManifestDependsOptional(addOnManager, i, folderName)
    if type(folderName) ~= "string" or folderName == "" then
        return "", "", false
    end
    if not io or type(io.open) ~= "function" then
        return "", "", false
    end
    local root = nil
    if type(addOnManager.GetAddOnRootDirectoryPath) == "function" then
        local okR, r = pcall(function()
            return addOnManager:GetAddOnRootDirectoryPath(i)
        end)
        if okR and type(r) == "string" and r ~= "" then
            root = r
        end
    end
    if not root then
        return "", "", false
    end
    root = string.gsub(root, "\\", "/")
    local last = string.sub(root, -1)
    if last ~= "/" and last ~= "\\" then
        root = root .. "/"
    end
    local candidates = {
        root .. folderName .. ".txt",
        root .. folderName .. ".addon",
        root .. "manifest.txt",
    }
    for _, path in ipairs(candidates) do
        local okOpen, file = pcall(io.open, path, "r")
        if okOpen and file then
            local content = file:read("*a")
            file:close()
            if type(content) == "string" and content ~= "" and string.find(content, "##%s*%a", 1) then
                local depParts = {}
                local optParts = {}
                for fileLine in string.gmatch(content, "[^\r\n]+") do
                    local key, val = string.match(fileLine, "^##%s*(%S-)%s*:%s*(.-)%s*$")
                    if key and val then
                        local kl = string.lower(key)
                        if kl == "dependson" then
                            table.insert(depParts, val)
                        elseif kl == "optionaldependson" then
                            table.insert(optParts, val)
                        elseif kl == "pcdependson" then
                            table.insert(depParts, val)
                        end
                    end
                end
                local depLine = table.concat(depParts, " ")
                local optLine = table.concat(optParts, " ")
                return depLine, optLine, true
            end
        end
    end
    return "", "", false
end

local function SanitizeForPanelText(text)
    if text == nil then
        return ""
    end
    local s = tostring(text)
    s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|C%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    s = string.gsub(s, "|R", "")
    s = string.gsub(s, "|", " ")
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

-- ZO EditBox rich text: `|c…|r`, `|H…|h`, `[…]` etc. can truncate or eat the rest of the string.
-- Converting `|` to `/` is NOT safe: `/c9999FF` is still treated as a color token.
local function SanitizeForEditBox(text)
    if text == nil then
        return ""
    end
    local s = tostring(text)
    -- Strip color resets and color starts (pipe and common mangled forms).
    s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|C%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    s = string.gsub(s, "|R", "")
    s = string.gsub(s, "/c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "/C%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "/r", "")
    s = string.gsub(s, "/R", "")
    -- Remove any remaining pipe-driven markup (links, etc.).
    s = string.gsub(s, "|", " ")
    -- Brackets can start link-style segments in some controls.
    s = string.gsub(s, "%[", "(")
    s = string.gsub(s, "%]", ")")
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    return s
end

local function GetVersionsList()
    return host.versionsList
end

local function GetLibsEdit()
    return host.libsEdit
end

local function ConfigureLibsEdit(edit)
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

local function SetLibsEditText(text)
    local edit = GetLibsEdit()
    if not edit or not edit.SetText then
        return
    end
    ConfigureLibsEdit(edit)
    edit:SetText(text or "")
    if edit.SetCursorPosition then
        edit:SetCursorPosition(0)
    end
end

---@return "editbox"|"none"
local function GetLibsOutputKind()
    if GetLibsEdit() then
        return "editbox"
    end
    return "none"
end

local function LibsOutputScrollToTop()
    local edit = GetLibsEdit()
    if edit and edit.SetCursorPosition then
        edit:SetCursorPosition(0)
    end
end

local function LibsOutputScrollToTopDeferred()
    LibsOutputScrollToTop()
end

local function ClearLibsOutput()
    libsOutputLines = {}
    SetLibsEditText("")
end

local function AddLibsOutputLine(line, r, g, b)
    local s = SanitizeForPanelText(line)
    table.insert(libsOutputLines, ColorizeLine(s, r or 0.9, g or 0.9, b or 0.85))
    SetLibsEditText(table.concat(libsOutputLines, "\n"))
end

local function FlushLibsReportToBuffer(entries)
    libsOutputLines = {}
    for i = 1, #entries do
        local e = entries[i]
        local s = SanitizeForPanelText(e.text)
        table.insert(libsOutputLines, ColorizeLine(s, e.r or 0.9, e.g or 0.9, e.b or 0.85))
    end
    SetLibsEditText(table.concat(libsOutputLines, "\n"))
end

--- Put a single comma-separated line into the chat input (short payload; avoids client truncation on full reports).
local function PutCommaSeparatedFolderNamesInChat(folderNames, categoryLabel)
    if type(folderNames) ~= "table" then
        if type(d) == "function" then
            d("[LibScanner] Nothing to copy (internal).")
        end
        return
    end
    if #folderNames == 0 then
        if type(d) == "function" then
            d(string.format("[LibScanner] %s: (none). Run /libscan if this looks stale.", categoryLabel))
        end
        return
    end
    local parts = {}
    for _, n in ipairs(folderNames) do
        if n and tostring(n) ~= "" then
            local s = SanitizeForEditBox(tostring(n))
            s = string.gsub(s, ",", " ")
            table.insert(parts, s)
        end
    end
    if #parts == 0 then
        if type(d) == "function" then
            d(string.format("[LibScanner] %s: (none after sanitize).", categoryLabel))
        end
        return
    end
    local body = table.concat(parts, ", ")
    local chatAvailable = rawget(_G, "IsChatSystemAvailableForCurrentPlatform")
    if type(chatAvailable) == "function" and chatAvailable() and ZO_GetChatSystem then
        local chat = ZO_GetChatSystem()
        if chat and chat.StartTextEntry then
            chat:StartTextEntry(body, nil, nil, true)
            if type(d) == "function" then
                d(string.format(
                    "[LibScanner] %s (%d) — in chat input line, Ctrl+C (Cmd+C) to copy.",
                    categoryLabel,
                    #parts
                ))
            end
            return
        end
    end
    if type(StartChatInput) == "function" then
        StartChatInput(body)
        return
    end
    if type(d) == "function" then
        d("[LibScanner] " .. categoryLabel .. ": " .. body)
    end
end

function LibScanner_CopyBrokenDepsToChat()
    PutCommaSeparatedFolderNamesInChat(latestBrokenDeps, "Broken dependency folder names")
end

function LibScanner_CopyOptionalLibsToChat()
    PutCommaSeparatedFolderNamesInChat(latestOptionalLibs, "Lib* optional-only manifest folder names")
end

function LibScanner_CopyUnusedLibsToChat()
    PutCommaSeparatedFolderNamesInChat(latestUnusedLibs, "Unused Lib* folder names")
end

function LibScanner_CopyUnusedLibs()
    LibScanner_CopyUnusedLibsToChat()
end

local function AddDebugMessage(message)
    if not LibScannerSavedVars or not LibScannerSavedVars.showDebug then
        return
    end
    if type(d) == "function" then
        d("[LibScanner] " .. tostring(message))
    end
end

function LibScanner.SetHost(spec)
    if type(spec) ~= "table" then
        host.versionsList = nil
        host.libsEdit = nil
        host.libsPanel = nil
        host.versionsPanel = nil
        host.show = nil
        host.versionsTypeReady = false
        return
    end
    host.versionsList = spec.versionsList
    host.libsEdit = spec.libsEdit
    host.libsPanel = spec.libsPanel
    host.versionsPanel = spec.versionsPanel
    host.show = spec.show
    host.versionsTypeReady = false
    ConfigureLibsEdit(host.libsEdit)
    if host.versionsList and type(ZO_ScrollList_AddDataType) == "function" then
        ZO_ScrollList_AddDataType(host.versionsList, 1, "LibScannerVersionRow", 50, SetupRow)
        host.versionsTypeReady = true
    end
    if #addonData > 0 then
        LibScanner_RefreshList()
    end
    if #libsOutputLines > 0 then
        SetLibsEditText(table.concat(libsOutputLines, "\n"))
    end
end

function LibScanner.SetDebug(on)
    if not LibScannerSavedVars then
        return
    end
    LibScannerSavedVars.showDebug = on and true or false
end

function LibScanner.IsDebug()
    return LibScannerSavedVars and LibScannerSavedVars.showDebug and true or false
end

-- Tab Switching (hosted BasaTools panels)
function LibScanner_SetTab(tabName)
    if host.libsPanel and host.libsPanel.SetHidden then
        host.libsPanel:SetHidden(tabName ~= "Libs")
    end
    if host.versionsPanel and host.versionsPanel.SetHidden then
        host.versionsPanel:SetHidden(tabName ~= "Versions")
    end
    if tabName == "Libs" then
        LibsOutputScrollToTopDeferred()
    end
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
function SetupRow(control, data)
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
    local list = GetVersionsList()
    if not list or not ZO_ScrollList_GetDataList then
        return
    end
    local scrollData = ZO_ScrollList_GetDataList(list)
    ZO_ScrollList_Clear(list)
    for _, data in ipairs(addonData) do
        table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, data))
    end
    ZO_ScrollList_Commit(list)
end

-- Main Scan Execution
local function RunScan()
    addonData = {}
    ClearLibsOutput()
    latestBrokenDeps = {}
    latestOptionalLibs = {}
    latestUnusedLibs = {}

    local getAddOnManager = rawget(_G, "GetAddOnManager")
    AddDebugMessage("type(GetAddOnManager)=" .. tostring(type(getAddOnManager)))
    if type(getAddOnManager) ~= "function" then
        AddLibsOutputLine("Error: GetAddOnManager() unavailable.", 1, 0.25, 0.25)
        LibsOutputScrollToTop()
        return false
    end

    local okManager, addOnManager = pcall(getAddOnManager)
    AddDebugMessage("GetAddOnManager() ok=" .. tostring(okManager) .. " type=" .. tostring(type(addOnManager)))
    if not okManager then
        AddLibsOutputLine("Error: GetAddOnManager() call failed.", 1, 0.25, 0.25)
        LibsOutputScrollToTop()
        return false
    end

    if not addOnManager then
        AddLibsOutputLine("Error: AddOn manager unavailable.", 1, 0.25, 0.25)
        LibsOutputScrollToTop()
        return false
    end

    local okNum, numAddOnsRaw = pcall(function() return addOnManager:GetNumAddOns() end)
    AddDebugMessage("GetNumAddOns() ok=" .. tostring(okNum) .. " value=" .. tostring(numAddOnsRaw))
    local numAddOns = okNum and (tonumber(numAddOnsRaw) or 0) or 0
    if numAddOns <= 0 then
        AddLibsOutputLine("Error: API returned 0 addons.", 1, 0.25, 0.25)
        LibsOutputScrollToTop()
        return false
    end

    local function scanErrorHandler(err)
        if type(debug) == "table" and type(debug.traceback) == "function" then
            return debug.traceback(tostring(err), 2)
        end
        return tostring(err)
    end

    local scanOk, scanErr = xpcall(function()
        local reportEntries = {}
        local function R(text, r, g, b)
            table.insert(reportEntries, { text = text, r = r or 1, g = g or 1, b = b or 1 })
        end
        if LibScannerSavedVars and LibScannerSavedVars.showDebug then
            R(string.format("LIBSCAN_UI=%s", GetLibsOutputKind()), 0.7, 0.7, 0.7)
        end

        local manifestRequired = {}
        local manifestOptional = {}
        local installedLibs = {}
        local missingLibs = {}
        local manifestReadCount = 0
        lastManifestReadCount = 0

        local function LooksLikeLibrary(addonName)
            return addonName ~= nil and string.find(string.lower(addonName), "^lib") ~= nil
        end

        -- Pass 1: treat add-on folders whose names start with "Lib" as library installs (GetAddOnInfo has no reliable isLibrary on live).
        for i = 1, numAddOns do
            local name = select(1, addOnManager:GetAddOnInfo(i))
            if LooksLikeLibrary(name) then
                installedLibs[name] = true
            end
        end

        -- Pass 2: versions list + problem deps; merge manifest DependsOn / OptionalDependsOn for Lib* buckets.
        for i = 1, numAddOns do
            local name, title, _, _, enabled, state = addOnManager:GetAddOnInfo(i)
            local isOutOfDate = state == ADDON_STATE_VERSION_MISMATCH
            local version = addOnManager:GetAddOnVersion(i)

            if enabled then
                local depLine, optLine, readOk = ReadManifestDependsOptional(addOnManager, i, name)
                if readOk then
                    manifestReadCount = manifestReadCount + 1
                end
                AddManifestDependencyTokensToSet(depLine, manifestRequired)
                AddManifestDependencyTokensToSet(optLine, manifestOptional)

                local optionalSet = {}
                AddManifestDependencyTokensToSet(optLine, optionalSet)

                local myMissingDeps = {}
                local numDeps = tonumber(addOnManager:GetAddOnNumDependencies(i)) or 0

                for j = 1, numDeps do
                    local dName, dExist, dActive, dMin, dVer, _isLibrary = addOnManager:GetAddOnDependencyInfo(i, j)
                    local tooLow = false
                    if type(dMin) == "number" and type(dVer) == "number" and dVer < dMin then
                        tooLow = true
                    end

                    local problem = nil
                    if not dExist then
                        problem = "missing"
                    elseif dExist and dActive == false then
                        problem = "disabled"
                    elseif dExist and dActive ~= false and tooLow then
                        problem = "version below manifest minimum"
                    end

                    if problem then
                        if problem == "missing" and dName and optionalSet[dName] then
                            -- Optional add-on not installed: not surfaced as a broken dependency.
                        else
                            table.insert(myMissingDeps, string.format("%s (%s)", tostring(dName), problem))
                            missingLibs[tostring(dName)] = problem
                        end
                    end
                end

                if not LooksLikeLibrary(name) then
                    local cleanTitle = string.gsub(title, "|c%x%x%x%x%x%x%x%x", "")
                    cleanTitle = string.gsub(cleanTitle, "|r", "")

                    local statusText = isOutOfDate and "|cFF3333No|r" or "|c33FF33Yes|r"
                    local sortStatus = isOutOfDate and 1 or 2

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
                        missingDepsStr = missingStr,
                    })
                end
            end
        end

        if manifestReadCount == 0 then
            AddDebugMessage("Manifest parse: 0 reads; Lib* buckets use API dependency names (no OptionalDependsOn split).")
            for ii = 1, numAddOns do
                local _, _, _, _, en2 = addOnManager:GetAddOnInfo(ii)
                if en2 then
                    local nDep = tonumber(addOnManager:GetAddOnNumDependencies(ii)) or 0
                    for jj = 1, nDep do
                        local dN2 = select(1, addOnManager:GetAddOnDependencyInfo(ii, jj))
                        if dN2 and dN2 ~= "" then
                            manifestRequired[dN2] = true
                        end
                    end
                end
            end
        end

        local optionalOnlyLibs = {}
        local unusedLibs = {}
        for libName, _ in pairs(installedLibs) do
            if not manifestRequired[libName] then
                if manifestOptional[libName] then
                    table.insert(optionalOnlyLibs, libName)
                elseif libName ~= ADDON_NAME then
                    -- This add-on is never a "dependency" of others; don't list our own folder as unused.
                    table.insert(unusedLibs, libName)
                end
            end
        end
        table.sort(optionalOnlyLibs)
        table.sort(unusedLibs)
        latestOptionalLibs = optionalOnlyLibs
        latestUnusedLibs = unusedLibs

        local brokenNames = {}
        for depName, _ in pairs(missingLibs) do
            table.insert(brokenNames, tostring(depName))
        end
        table.sort(brokenNames)
        latestBrokenDeps = brokenNames

        R("--- Broken dependencies (enabled add-ons) ---", 1, 0.35, 0.35)
        local missingLines = {}
        for depName, why in pairs(missingLibs) do
            table.insert(missingLines, string.format("- %s (%s)", depName, why))
        end
        table.sort(missingLines)
        if #missingLines == 0 then
            R("None detected (missing, disabled, or below minimum version).")
        else
            for _, ln in ipairs(missingLines) do
                R(ln, 1, 0.45, 0.45)
            end
        end

        R("")
        R("--- Lib* optional-only (manifest) ---", 0.45, 0.75, 0.95)
        if manifestReadCount == 0 then
            R("(No manifest reads succeeded — OptionalDependsOn was not scanned.)", 0.65, 0.65, 0.65)
            R("Not classified.", 0.55, 0.55, 0.55)
        else
            R("(Installed Lib* named only in OptionalDependsOn for an enabled add-on, not in DependsOn.)", 0.65, 0.65, 0.65)
            if #optionalOnlyLibs == 0 then
                R("None.")
            else
                for _, libName in ipairs(optionalOnlyLibs) do
                    R("- " .. libName, 0.55, 0.82, 0.98)
                end
            end
        end

        R("")
        R("--- Unused dependencies ---", 0.35, 0.85, 0.35)
        if manifestReadCount == 0 then
            R("(Lib* not listed by GetAddOnDependencyInfo for enabled add-ons. Optional-only libs may appear here when manifests are unreadable.)", 0.65, 0.65, 0.65)
        else
            R("(Lib* folders not in DependsOn or OptionalDependsOn of any enabled add-on.)", 0.65, 0.65, 0.65)
        end
        if #unusedLibs == 0 then
            R("None.")
        else
            for _, libName in ipairs(unusedLibs) do
                R("- " .. libName, 0.85, 0.95, 0.85)
            end
        end

        if manifestReadCount == 0 then
            local preamble = {
                { text = "", r = 1, g = 1, b = 1 },
                {
                    text = "GetAddOnNumDependencies lists required dependencies only; verify manifests before removing Lib* folders.",
                    r = 1,
                    g = 0.52,
                    b = 0.35,
                },
                {
                    text = "OptionalDependsOn is ignored. Libraries declared only as optional may appear under Unused dependencies.",
                    r = 1,
                    g = 0.48,
                    b = 0.3,
                },
                {
                    text = "WARNING: Manifest lines could not be read (io is unavailable for add-on Lua in this client).",
                    r = 1,
                    g = 0.42,
                    b = 0.22,
                },
            }
            for pi = 1, #preamble do
                table.insert(reportEntries, 1, preamble[pi])
            end
        end

        lastManifestReadCount = manifestReadCount
        FlushLibsReportToBuffer(reportEntries)
        LibScanner_RefreshList()
    end, scanErrorHandler)

    if not scanOk then
        AddLibsOutputLine("ERROR: Scan failed:")
        for line in string.gmatch(scanErr or "", "[^\n]+") do
            AddLibsOutputLine(line)
        end
    end

    LibsOutputScrollToTopDeferred()

    if LibScannerSavedVars then
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
        -- ESO rejects SavedVariables strings longer than ~2000 chars (becomes nil).
        -- Chunk the TSV so /libscanexport survives reload for merge_libscan_tsv.py.
        local MAX_CHUNK = 1800
        local full = table.concat(exportLines, "\n")
        local chunks = {}
        if string.len(full) <= MAX_CHUNK then
            chunks[1] = full
        else
            local buf = ""
            for i = 1, #exportLines do
                local line = exportLines[i]
                local candidate = (buf == "") and line or (buf .. "\n" .. line)
                if string.len(candidate) > MAX_CHUNK and buf ~= "" then
                    table.insert(chunks, buf)
                    buf = line
                else
                    buf = candidate
                end
            end
            if buf ~= "" then
                table.insert(chunks, buf)
            end
        end
        LibScannerSavedVars.lastExportChunks = chunks
        LibScannerSavedVars.lastExportChunkCount = #chunks
        -- Short status only in lastExport (fits SV limit); full data is in chunks.
        LibScannerSavedVars.lastExport = string.format("chunks:%d rows:%d", #chunks, #addonData)
        LibScannerSavedVars.lastExportVersion = 2
    end
    return scanOk and true or false
end

local function EmitScanSummary()
    EmitStatus("LibScanner scan complete.", 0.35, 0.85, 0.35)
    EmitStatus(string.format("  Versions: %d enabled non-Lib add-on(s).", #addonData))
    local br, bg, bb = 0.9, 0.9, 0.85
    if #latestBrokenDeps > 0 then
        br, bg, bb = 1, 0.45, 0.45
    end
    EmitStatus(string.format("  Broken dependencies: %d.", #latestBrokenDeps), br, bg, bb)
    if lastManifestReadCount == 0 then
        EmitStatus("  Lib* optional-only: not classified (no manifest reads).", 1, 0.52, 0.35)
    else
        EmitStatus(string.format("  Lib* optional-only: %d.", #latestOptionalLibs), 0.55, 0.82, 0.98)
    end
    EmitStatus(string.format("  Unused Lib*: %d.", #latestUnusedLibs), 0.35, 0.85, 0.35)
    EmitStatus("Lists are on the LibScanner tab (Versions / Libraries). Select text in Libraries to copy.")
end

local function ReportExport()
    if not LibScannerSavedVars then
        local msg = "No SavedVariables (export skipped)"
        EmitStatus("LibScanner: " .. msg)
        if type(d) == "function" then
            d("[LibScanner] " .. msg)
        end
        return
    end
    local chunks = LibScannerSavedVars.lastExportChunks
    local n = (type(chunks) == "table" and #chunks) or 0
    local total = 0
    if n > 0 then
        for i = 1, n do
            total = total + string.len(chunks[i] or "")
        end
    end
    local msg = string.format(
        "TSV export chunks=%s bytes=%s (LibScannerSavedVars.lastExportChunks ; /reloadui then merge_libscan_tsv.py --savedvars …/LibScanner.lua)",
        tostring(n),
        tostring(total)
    )
    EmitStatus("LibScanner: " .. msg)
    if type(d) == "function" then
        d("[LibScanner] " .. msg)
    end
end

function LibScanner.GetHelpEntries()
    return {
        intro = {
            { text = "LibScanner — scan enabled add-ons' library dependencies." },
            { text = "On live clients io is nil, so manifests are not read. Libraries shows a WARNING; optional-only Lib* is not classified." },
            { text = "Select text in the Libraries report to copy. Do not paste the full report into chat." },
            { text = "/scan is an alias for /libscan. Existing slash commands still work." },
        },
        rows = {
            { action = "Scan add-ons", slash = "/libscan", effect = "Run scan and show Versions + Libraries in BasaTools" },
            { action = "Export TSV", slash = "/libscanexport", effect = "Same scan, persist TSV in LibScannerSavedVars" },
            { action = "Debug", slash = "/libscandebug", effect = "Toggle verbose chat (default off)" },
        },
    }
end

function LibScanner.GetHelpText()
    local entries = LibScanner.GetHelpEntries()
    local lines = {}
    local intro = entries.intro
    for i = 1, #intro do
        lines[#lines + 1] = intro[i].text
    end
    lines[#lines + 1] = ""
    local rows = entries.rows
    for i = 1, #rows do
        local row = rows[i]
        lines[#lines + 1] = string.format("%s  %s  %s", row.action, row.slash, row.effect)
    end
    return table.concat(lines, "\n")
end

function LibScanner.ShowWindow()
    if type(host.show) == "function" then
        host.show()
        LibsOutputScrollToTopDeferred()
        return
    end
    EmitStatus("LibScanner: enable BasaTools to see Versions / Libraries.")
end

function LibScanner.ShowHostHelp()
    LibScanner_SetTab("Libs")
    local text = SanitizeForPanelText(LibScanner.GetHelpText())
    SetLibsEditText(ColorizeLine(text, 0.93, 0.86, 0.55))
end

function LibScanner.CopyBucket(kind)
    if kind == "broken" then
        LibScanner_CopyBrokenDepsToChat()
    elseif kind == "optional" then
        LibScanner_CopyOptionalLibsToChat()
    elseif kind == "unused" then
        LibScanner_CopyUnusedLibsToChat()
    end
end

function LibScanner.Run(op)
    op = zo_strtrim(tostring(op or "scan"))
    if op == "scan" then
        local ok = RunScan()
        LibScanner.ShowWindow()
        if ok then
            EmitScanSummary()
        else
            EmitStatus("LibScanner: scan failed. See the LibScanner window.", 1, 0.25, 0.25)
        end
    elseif op == "export" then
        local ok = RunScan()
        LibScanner.ShowWindow()
        if ok then
            EmitScanSummary()
        else
            EmitStatus("LibScanner: scan failed. See the LibScanner window.", 1, 0.25, 0.25)
        end
        ReportExport()
    elseif op == "debug" then
        if not LibScannerSavedVars then
            return
        end
        LibScannerSavedVars.showDebug = not LibScannerSavedVars.showDebug
        local msg = "showDebug=" .. tostring(LibScannerSavedVars.showDebug) .. " (re-run Scan / /libscan)"
        EmitStatus("LibScanner: " .. msg)
        if type(d) == "function" then
            d("[LibScanner] " .. msg)
        end
    elseif op == "open" then
        LibScanner.ShowWindow()
    else
        EmitStatus("LibScanner: unknown op. Use scan, export, or debug.")
        if type(d) == "function" then
            d("[LibScanner] unknown op. /libscan  |  /libscanexport  |  /libscandebug")
        end
    end
end

local function Initialize()
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
    LibScannerSavedVars = ZO_SavedVars:NewAccountWide("LibScannerSavedVars", 1, nil, {
        lastExport = "",
        lastExportChunks = {},
        lastExportChunkCount = 0,
        lastExportVersion = 0,
        showDebug = false,
    }, profile, displayName)

    SLASH_COMMANDS["/libscan"] = function()
        LibScanner.Run("scan")
    end
    SLASH_COMMANDS["/scan"] = function()
        LibScanner.Run("scan")
    end

    SLASH_COMMANDS["/libscanexport"] = function()
        LibScanner.Run("export")
    end

    SLASH_COMMANDS["/libscandebug"] = function()
        LibScanner.Run("debug")
    end
end

-- Wait for the addon to load before initializing
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(event, addonName)
    if addonName == ADDON_NAME then
        Initialize()
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    end
end)
