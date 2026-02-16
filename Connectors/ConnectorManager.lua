-- Connector manager for SimpleBossMods.

local ADDON_NAME = ...
local M = _G[ADDON_NAME]
if not M then return end

M.Connectors = M.Connectors or {}
local CM = M.Connectors

CM.registry = CM.registry or {}
CM.order = CM.order or { "timeline", "bigwigs", "dbm" }

local VALID_CONNECTOR_IDS = {
	timeline = true,
	bigwigs = true,
	dbm = true,
}

local function isSecretValue(value)
	return type(issecretvalue) == "function" and issecretvalue(value)
end

local function normalizeEventID(value)
	local valueType = type(value)
	if isSecretValue(value) then
		return nil
	end
	if valueType == "number" or valueType == "string" then
		return value
	end
	return nil
end

local function normalizeEventRefID(value)
	local valueType = type(value)
	if isSecretValue(value) then
		return value
	end
	if valueType == "number" or valueType == "string" then
		return value
	end
	return nil
end

local function normalizeNumber(value)
	if isSecretValue(value) then
		return nil
	end
	local n = tonumber(value)
	if type(n) == "number" then
		return n
	end
	return nil
end

local function normalizeText(value)
	if isSecretValue(value) then
		return value
	end
	if type(value) == "string" then
		return value
	end
	return ""
end

local function pickDisplayName(info)
	local keys = { "name", "text", "title", "label", "spellName" }
	for i = 1, #keys do
		local value = info[keys[i]]
		if isSecretValue(value) then
			return value
		end
		if type(value) == "string" and value ~= "" then
			return value
		end
	end
	return ""
end

local function normalizeColor(color)
	if type(color) ~= "table" then
		return nil
	end
	local rawR = color.r or color[1]
	local rawG = color.g or color[2]
	local rawB = color.b or color[3]
	local rawA = color.a or color[4] or 1

	if isSecretValue(rawR) or isSecretValue(rawG) or isSecretValue(rawB) or isSecretValue(rawA) then
		if rawR ~= nil and rawG ~= nil and rawB ~= nil then
			return {
				r = rawR,
				g = rawG,
				b = rawB,
				a = rawA,
			}
		end
		return nil
	end

	local r = normalizeNumber(rawR)
	local g = normalizeNumber(rawG)
	local b = normalizeNumber(rawB)
	local a = normalizeNumber(rawA)
	if not r or not g or not b then
		return nil
	end
	return { r = r, g = g, b = b, a = a or 1 }
end

local function normalizeSpellID(value)
	if isSecretValue(value) then
		return value
	end
	local valueType = type(value)
	if valueType == "number" then
		return value
	end
	if valueType == "string" then
		local trimmed = value:match("^%s*(.-)%s*$")
		if trimmed == "" then
			return nil
		end
		local numeric = tonumber(trimmed)
		if numeric ~= nil then
			return numeric
		end
		return trimmed
	end
	return normalizeNumber(value)
end

local function normalizeEventInfo(info, entryID)
	info = type(info) == "table" and info or {}

	local name = pickDisplayName(info)

	local icon = info.icon
	if icon == nil then
		icon = info.iconFileID
	end
	-- Keep opaque values as-is; consumers already guard secret paths.

	local spellID = normalizeSpellID(info.spellID or info.spellId)
	local icons = isSecretValue(info.icons) and info.icons or normalizeNumber(info.icons)
	local timelineEventID = normalizeEventRefID(info.timelineEventID)
		or normalizeEventRefID(info.eventID)
		or normalizeEventRefID(info.id)
		or normalizeEventRefID(entryID)

	local color = normalizeColor(info.color or info.barColor)
	local colorFrom = normalizeColor(info.colorFrom) or color
	local colorTo = normalizeColor(info.colorTo) or colorFrom

	return {
		name = name,
		icon = icon,
		spellID = spellID,
		icons = icons,
		timelineEventID = timelineEventID,
		isApproximate = info.isApproximate == true,
		color = color,
		colorFrom = colorFrom,
		colorTo = colorTo,
	}
end

local function normalizeConnectorEvent(entry)
	if type(entry) ~= "table" then
		return nil
	end

	-- Canonical connector event contract consumed by SBM:
	-- id: string|number
	-- eventInfo: { name, icon, spellID, icons, timelineEventID, isApproximate, color, colorFrom, colorTo }
	-- remaining, isPaused, isBlocked, isQueued, forceBar, isTest
	local id = normalizeEventID(entry.id)
	if not id then
		return nil
	end

	local normalized = {
		id = id,
		eventInfo = normalizeEventInfo(entry.eventInfo, id),
		remaining = normalizeNumber(entry.remaining),
		isPaused = entry.isPaused == true,
		isBlocked = entry.isBlocked == true,
		isQueued = entry.isQueued == true,
		forceBar = entry.forceBar == true,
	}

	if entry.isTest ~= nil then
		normalized.isTest = entry.isTest == true
	end

	return normalized
end

local function normalizeConnectorID(id)
	if type(id) ~= "string" then
		return nil
	end
	id = id:lower()
	if VALID_CONNECTOR_IDS[id] then
		return id
	end
	return nil
end

function M.NormalizeConnectorID(id)
	return normalizeConnectorID(id)
end

local function idInOrder(id)
	for _, current in ipairs(CM.order) do
		if current == id then
			return true
		end
	end
	return false
end

function M:RegisterConnector(connector)
	if type(connector) ~= "table" then
		return false
	end
	local id = normalizeConnectorID(connector.id)
	if not id then
		return false
	end
	connector.id = id
	connector.label = connector.label or id
	CM.registry[id] = connector
	if not idInOrder(id) then
		table.insert(CM.order, id)
	end
	return true
end

local function getRequestedConnectorID()
	local cfg = SimpleBossModsDB and SimpleBossModsDB.cfg
	if type(cfg) ~= "table" then
		return "timeline"
	end
	local connectors = cfg.connectors
	if type(connectors) ~= "table" then
		return "timeline"
	end
	return normalizeConnectorID(connectors.provider) or "timeline"
end

local function setRequestedConnectorID(id)
	local cfg = SimpleBossModsDB and SimpleBossModsDB.cfg
	if type(cfg) ~= "table" then
		return
	end
	cfg.connectors = cfg.connectors or {}
	cfg.connectors.provider = id
end

function M:IsConnectorAvailable(id)
	id = normalizeConnectorID(id)
	local connector = id and CM.registry[id] or nil
	if not connector then
		return false, "Connector not registered"
	end
	if type(connector.IsAvailable) ~= "function" then
		return true
	end
	local ok, available, reason = pcall(connector.IsAvailable, connector, M)
	if not ok then
		return false, "Availability check failed"
	end
	if available then
		return true
	end
	return false, reason or "Unavailable"
end

local function pickFallbackConnector(preferredID)
	local available = select(1, M:IsConnectorAvailable(preferredID))
	if available then
		return preferredID
	end
	local timelineAvailable = select(1, M:IsConnectorAvailable("timeline"))
	if timelineAvailable then
		return "timeline"
	end
	for _, id in ipairs(CM.order) do
		if select(1, M:IsConnectorAvailable(id)) then
			return id
		end
	end
	return preferredID
end

local function clearConnectorRecords()
	if M.ClearConnectorRecords then
		M:ClearConnectorRecords()
	end
end

local function notifyConnectorChanged(id)
	if M.OnActiveConnectorChanged then
		M:OnActiveConnectorChanged(id)
	end
end

local function deactivateConnector(id)
	local connector = id and CM.registry[id] or nil
	if connector and type(connector.Deactivate) == "function" then
		pcall(connector.Deactivate, connector, M)
	end
end

local function activateConnector(id)
	local connector = id and CM.registry[id] or nil
	if not connector then
		return false
	end
	if type(connector.Activate) ~= "function" then
		return true
	end
	local ok, activated, reason = pcall(connector.Activate, connector, M)
	if not ok then
		return false, activated
	end
	if activated == false then
		return false, reason
	end
	return true
end

function M:GetConnectorStatuses()
	local list = {}
	local requested = getRequestedConnectorID()
	local active = CM.activeID

	for _, id in ipairs(CM.order) do
		local connector = CM.registry[id]
		if connector then
			local available, reason = M:IsConnectorAvailable(id)
			list[#list + 1] = {
				id = id,
				label = connector.label or id,
				available = available,
				reason = reason,
				selected = (requested == id),
				active = (active == id),
			}
		end
	end

	return list
end

function M:GetRequestedConnectorID()
	return getRequestedConnectorID()
end

function M:GetActiveConnectorID()
	return CM.activeID
end

function M:SetConnector(id)
	id = normalizeConnectorID(id)
	if not id then
		return false, "Unknown connector"
	end
	local available, reason = M:IsConnectorAvailable(id)
	if not available then
		return false, reason or "Connector unavailable"
	end
	setRequestedConnectorID(id)
	M:RefreshConnectorState()
	return true
end

function M:RefreshConnectorState(opts)
	opts = opts or {}
	local requested = getRequestedConnectorID()
	local target = pickFallbackConnector(requested)
	if target ~= requested then
		setRequestedConnectorID(target)
	end
	if M.SyncLiveConfig then
		M.SyncLiveConfig()
	end

	if CM.activeID == target then
		return target
	end

	local previous = CM.activeID
	if previous then
		deactivateConnector(previous)
		CM.activeID = nil
	end

	local ok, reason = activateConnector(target)
	if not ok then
		if target ~= "timeline" and select(1, M:IsConnectorAvailable("timeline")) then
			target = "timeline"
			ok = activateConnector(target)
		end
		if not ok then
			if type(reason) == "string" and reason ~= "" then
				print("SimpleBossMods: failed to activate connector:", reason)
			end
			return previous
		end
	end

	if getRequestedConnectorID() ~= target then
		setRequestedConnectorID(target)
	end
	if M.SyncLiveConfig then
		M.SyncLiveConfig()
	end
	CM.activeID = target
	if not opts.skipClear then
		clearConnectorRecords()
	end
	notifyConnectorChanged(target)
	if M.Tick then
		M:Tick()
	end
	if M.LayoutAll then
		M:LayoutAll()
	end
	return target
end

function M:CollectConnectorEvents(now, connectorID)
	local id = normalizeConnectorID(connectorID) or CM.activeID
	if not id then
		return nil
	end
	local connector = CM.registry[id]
	if not connector or type(connector.CollectEvents) ~= "function" then
		return nil
	end
	local ok, events = pcall(connector.CollectEvents, connector, M, now)
	if not ok or type(events) ~= "table" then
		return nil
	end
	local normalized = {}
	for i = 1, #events do
		local entry = normalizeConnectorEvent(events[i])
		if entry then
			normalized[#normalized + 1] = entry
		end
	end
	return normalized
end
