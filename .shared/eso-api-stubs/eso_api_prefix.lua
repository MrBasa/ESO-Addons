---@meta
-- Live-checked ESO API overrides for LuaLS. Listed first in workspace.library
-- so these signatures win when FlatBadger eso-api disagrees.
-- Editor-only. Does not replace runtime APIs from the game.
-- Edit only when live ESO or an installed reference addon (LibDebugLogger,
-- WritWorthy, …) disagrees. Do not regenerate from UESP.

-- NOTE: ESO uses Lua 5.1 in practice; LuaLS will still parse/diagnose stubs correctly.

--- Add-on list rows are returned **positionally** from `AddOnManager:GetAddOnInfo` (see below). Older docs/stubs sometimes listed extra booleans; live clients commonly use **six** returns with `state` = `ADDON_STATE_*` (see `ESO-LuaAPI-RULE.md`).

---@class AddOnManager
AddOnManager = {}

---@see https://wiki.esoui.com/wiki/GetAddOnManager
---@return AddOnManager
function GetAddOnManager() end

---@see https://wiki.esoui.com/wiki/AddOnManager:GetNumAddOns
---@param self AddOnManager
---@return integer
function AddOnManager.GetNumAddOns(self) end

---@see https://wiki.esoui.com/wiki/AddOnManager:GetAddOnInfo
--- Live-aligned six-return pattern (e.g. LibDebugLogger): `state` is `ADDON_STATE_*` (integer).
---@param self AddOnManager
---@param index integer
---@return string name
---@return string title
---@return string author
---@return string description
---@return boolean enabled
---@return integer state
function AddOnManager.GetAddOnInfo(self, index) end

---@see https://wiki.esoui.com/wiki/AddOnManager:GetAddOnVersion
---@param self AddOnManager
---@param index integer
---@return string|number version
function AddOnManager.GetAddOnVersion(self, index) end

---@see https://wiki.esoui.com/wiki/AddOnManager:GetAddOnNumDependencies
---@param self AddOnManager
---@param index integer
---@return integer
function AddOnManager.GetAddOnNumDependencies(self, index) end

---@see https://wiki.esoui.com/wiki/AddOnManager:GetAddOnDependencyInfo
--- Live-aligned six-return pattern (ESOUI `ESOUIDocumentation.txt`): sixth value is **`isLibrary`** (boolean), not optional-vs-required.
---@param self AddOnManager
---@param index integer
---@param dependencyIndex integer
---@return string dependencyName
---@return boolean dependencyExists
---@return boolean dependencyActive
---@return integer|string dependencyMinVersion
---@return integer|string dependencyVersion
---@return boolean|nil isLibrary
function AddOnManager.GetAddOnDependencyInfo(self, index, dependencyIndex) end

---@class EventManager
EVENT_MANAGER = {}

---@see https://wiki.esoui.com/wiki/EVENT_MANAGER:RegisterForEvent
---@param self EventManager
---@param addonName string
---@param eventCode integer|string
---@param callback fun(eventCodeOrNil:any, addonNameOrNil:any)
function EVENT_MANAGER.RegisterForEvent(self, addonName, eventCode, callback) end

---@see https://wiki.esoui.com/wiki/EVENT_MANAGER:UnregisterForEvent
---@param self EventManager
---@param addonName string
---@param eventCode integer|string
function EVENT_MANAGER.UnregisterForEvent(self, addonName, eventCode) end

-- Common ESO event codes (type is intentionally broad).
---@see https://wiki.esoui.com/wiki/EVENT_ADD_ON_LOADED
---@type integer|string
EVENT_ADD_ON_LOADED = 0

-- Slash commands table.
---@see https://wiki.esoui.com/wiki/SLASH_COMMANDS
---@type table<string, fun(...):nil>
SLASH_COMMANDS = {}

-- UI list helpers (used by LibScanner).
---@see https://wiki.esoui.com/wiki/ZO_ScrollList_GetDataList
---@return table<number, any>
function ZO_ScrollList_GetDataList(listControl) end

---@see https://wiki.esoui.com/wiki/ZO_ScrollList_Clear
function ZO_ScrollList_Clear(listControl) end

---@see https://wiki.esoui.com/wiki/ZO_ScrollList_CreateDataEntry
---@param rowType integer
---@param data any
function ZO_ScrollList_CreateDataEntry(rowType, data) end

---@see https://wiki.esoui.com/wiki/ZO_ScrollList_Commit
function ZO_ScrollList_Commit(listControl) end

---@see https://wiki.esoui.com/wiki/ZO_ScrollList_AddDataType
---@param listControl any
---@param rowType integer
---@param templateName string
---@param rowHeight integer
---@param setupRowFunction fun(control:any, data:any)
function ZO_ScrollList_AddDataType(listControl, rowType, templateName, rowHeight, setupRowFunction) end

-- Provide a few common globals referenced by runtime UI code patterns.
---@see https://wiki.esoui.com/wiki/ZO_ScrollList
---@type table<string, any>
ZO_ScrollList = {}

-- LibScanner XML-created controls: declare as Lua diagnostics globals in
-- .luarc.json and .vscode/settings.json.
