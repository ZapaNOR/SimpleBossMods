-- Timeline event collection for SimpleBossMods.

local ADDON_NAME = ...
local M = _G[ADDON_NAME]
if not M then return end

-- Cache C_EncounterTimeline functions for performance
local ET = C_EncounterTimeline
if not ET then return end

local GetEventList = ET.GetSortedEventList or ET.GetEventList
local GetEventInfo = ET.GetEventInfo
local GetEventTrack = ET.GetEventTrack
local GetEventState = ET.GetEventState
local IsEventBlocked = ET.IsEventBlocked
local GetEventTimeRemaining = ET.GetEventTimeRemaining

local Enum_EncounterTimelineEventState = Enum and Enum.EncounterTimelineEventState
local Enum_EncounterTimelineTrack = Enum and Enum.EncounterTimelineTrack
local encounterEventFallbackCache = {}
local wipeTable = _G.wipe or function(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

local function isSecretValue(value)
	return type(issecretvalue) == "function" and issecretvalue(value)
end

local function getTimelineEventList()
	if type(GetEventList) == "function" then
		-- Try GetSortedEventList arguments first (maxEvents, maxDuration, excludeTerminal, excludeHidden)
		-- If it's GetEventList, these args are ignored or might error if not handled, but usually Lua is lenient with extra args.
		-- However, to be safe and optimized:
		if ET.GetSortedEventList then
			return ET.GetSortedEventList(nil, nil, false, false)
		else
			return ET.GetEventList()
		end
	end
	return nil
end

local function isTerminalEventState(state)
	if not Enum_EncounterTimelineEventState then return false end
	return state == Enum_EncounterTimelineEventState.Finished
		or state == Enum_EncounterTimelineEventState.Canceled
end

function M:SetTimelineEventTerminalState(eventID, state)
	local idType = type(eventID)
	if idType ~= "number" and idType ~= "string" then
		return
	end

	if state == nil and C_EncounterTimeline and C_EncounterTimeline.GetEventState then
		state = C_EncounterTimeline.GetEventState(eventID)
	end

	local terminalStates = self._timelineTerminalStateByID
	if type(terminalStates) ~= "table" then
		terminalStates = {}
		self._timelineTerminalStateByID = terminalStates
	end

	if isTerminalEventState(state) then
		terminalStates[eventID] = state
	else
		terminalStates[eventID] = nil
	end
end

local function isQueuedTrack(track)
	if not Enum_EncounterTimelineTrack then return false end
	return track == Enum_EncounterTimelineTrack.Queued
end

local function resolveTimelineLabel(info, spellID)
	-- Check info fields first
	if type(info) == "table" then
		-- IMPORTANT: Check for secret values BEFORE comparing strings or lengths.
		-- Encounter timeline fields can be secret during real boss fights.
		if isSecretValue(info.spellName) then
			return info.spellName
		end
		if type(info.spellName) == "string" and info.spellName ~= "" then
			return info.spellName
		end
		
		-- Fallback fields occasionally used in custom/older implementations
		local candidates = { info.name, info.text, info.title, info.label, info.overrideName }
		for _, label in ipairs(candidates) do
			if isSecretValue(label) then
				return label
			end
			if type(label) == "string" and label ~= "" then
				return label
			end
		end
	end

	-- Fallback to Spell API
	if type(spellID) == "number" and not isSecretValue(spellID) then
		if C_Spell and C_Spell.GetSpellName then
			local name = C_Spell.GetSpellName(spellID)
			if name and name ~= "" then
				return name
			end
		elseif GetSpellInfo then
			local name = GetSpellInfo(spellID)
			if name and name ~= "" then
				return name
			end
		end
	end

	return ""
end

local function resolveTimelineIcon(info, spellID)
	if type(info) == "table" then
		local icon = info.iconFileID or info.icon
		if icon then
			return icon
		end
	end

	if type(spellID) == "number" then
		if C_Spell and C_Spell.GetSpellInfo then
			local spellInfo = C_Spell.GetSpellInfo(spellID)
			if spellInfo and spellInfo.iconID then
				return spellInfo.iconID
			end
		elseif GetSpellInfo then
			local _, _, _, icon = GetSpellInfo(spellID)
			if icon then
				return icon
			end
		end
	end

	return nil
end

local function resolveEncounterEventFallback(encounterEventID)
	if type(encounterEventID) ~= "number" or encounterEventID <= 0 then
		return nil, nil, nil
	end

	local cached = encounterEventFallbackCache[encounterEventID]
	if cached then
		return cached.label, cached.spellID, cached.iconFileID
	end

	if not (C_EncounterEvents and type(C_EncounterEvents.GetEventInfo) == "function") then
		return nil, nil, nil
	end

	local ok, info = pcall(C_EncounterEvents.GetEventInfo, encounterEventID)
	if not ok or type(info) ~= "table" then
		return nil, nil, nil
	end

	local label = nil
	local candidates = { info.spellName, info.name, info.text, info.title, info.label, info.overrideName }
	for _, candidate in ipairs(candidates) do
		if not isSecretValue(candidate) and type(candidate) == "string" and candidate ~= "" then
			label = candidate
			break
		end
	end

	local rawSpellID = info.spellID or info.spellId
	local spellID = nil
	if isSecretValue(rawSpellID) then
		spellID = rawSpellID
	else
		local numericSpellID = tonumber(rawSpellID)
		if type(numericSpellID) == "number" and numericSpellID > 0 then
			spellID = numericSpellID
		end
	end

	if not label and type(spellID) == "number" then
		if C_Spell and C_Spell.GetSpellName then
			local spellName = C_Spell.GetSpellName(spellID)
			if type(spellName) == "string" and spellName ~= "" then
				label = spellName
			end
		elseif GetSpellInfo then
			local spellName = GetSpellInfo(spellID)
			if type(spellName) == "string" and spellName ~= "" then
				label = spellName
			end
		end
	end

	local iconFileID = info.iconFileID or info.icon
	if isSecretValue(iconFileID) then
		iconFileID = nil
	end
	if not iconFileID and type(spellID) == "number" then
		if C_Spell and C_Spell.GetSpellInfo then
			local spellInfo = C_Spell.GetSpellInfo(spellID)
			iconFileID = spellInfo and spellInfo.iconID or nil
		elseif GetSpellInfo then
			local _, _, _, icon = GetSpellInfo(spellID)
			iconFileID = icon
		end
	end

	if label or spellID or iconFileID then
		encounterEventFallbackCache[encounterEventID] = {
			label = label,
			spellID = spellID,
			iconFileID = iconFileID,
		}
	end

	return label, spellID, iconFileID
end

function M:ClearEncounterEventFallbackCache()
	if not next(encounterEventFallbackCache) then
		return
	end
	wipeTable(encounterEventFallbackCache)
end

function M:CollectTimelineEvents(now)
	now = now or (GetTime and GetTime() or 0)
	local events = {}
	local terminalStates = self._timelineTerminalStateByID
	if type(terminalStates) ~= "table" then
		terminalStates = {}
		self._timelineTerminalStateByID = terminalStates
	end
	
	local list = getTimelineEventList()
	if type(list) ~= "table" then
		return events
	end

	for _, eventID in ipairs(list) do
		-- info
		local info = GetEventInfo(eventID)
		if info then
			-- track
			local track = GetEventTrack(eventID)

			-- state
			local state = GetEventState(eventID)

			local isTerminal = isTerminalEventState(state)
			if isTerminal then
				terminalStates[eventID] = state
			else
				terminalStates[eventID] = nil
			end
			local queued = isQueuedTrack(track) and not isTerminal

			-- blocked
			local blocked = IsEventBlocked(eventID)

			-- paused
			local paused = false
			if Enum_EncounterTimelineEventState then
				paused = (state == Enum_EncounterTimelineEventState.Paused)
			end

			-- remaining
			local remaining = GetEventTimeRemaining(eventID)

			if not isTerminal and (queued or (type(remaining) == "number" and remaining > 0)) then
				local rawSpellID = info.spellID or info.spellId
				local spellID = nil
				if isSecretValue(rawSpellID) then
					spellID = rawSpellID
				else
					local numericSpellID = tonumber(rawSpellID)
					if type(numericSpellID) == "number" and numericSpellID > 0 then
						spellID = numericSpellID
					end
				end

				local encounterEventID = tonumber(info.encounterEventID or info.encounterEventId or info.eventID or info.eventId)
				local fallbackLabel, fallbackSpellID, fallbackIconFileID = resolveEncounterEventFallback(encounterEventID)
				if not spellID and fallbackSpellID then
					spellID = fallbackSpellID
				end
				local displayName = resolveTimelineLabel(info, spellID)
				if not isSecretValue(displayName) and displayName == "" and type(fallbackLabel) == "string" and fallbackLabel ~= "" then
					displayName = fallbackLabel
				end

				local relevant = true
				if encounterEventID and M.IsEncounterEventRelevant then
					relevant = M:IsEncounterEventRelevant(encounterEventID)
				end

				if relevant then
					local iconFileID = resolveTimelineIcon(info, spellID)
					if not iconFileID and fallbackIconFileID then
						iconFileID = fallbackIconFileID
					end
					local iconsMask = info.icons
					local eventColor = info.color

					-- Store in array (faster than table.insert)
					events[#events + 1] = {
						id = eventID,
						eventInfo = {
							name = displayName,
							spellName = info.spellName,
							spellID = spellID,
							icon = iconFileID,
							icons = iconsMask,
							severity = info.severity,
							timelineEventID = eventID,
							encounterEventID = encounterEventID,
							source = info.source,
							color = eventColor,
							state = state,
						},
						remaining = remaining,
						isQueued = queued,
						isPaused = paused,
						isBlocked = blocked,
					}
				end
			end
		end
	end

	return events
end
