-- Native Encounter Timeline connector.

local ADDON_NAME = ...
local M = _G[ADDON_NAME]
if not M then return end

local function isSecretValue(value)
	return type(issecretvalue) == "function" and issecretvalue(value)
end

local function getTimelineEventList()
	if not C_EncounterTimeline then return nil end
	if type(C_EncounterTimeline.GetSortedEventList) == "function" then
		local ok, result = pcall(C_EncounterTimeline.GetSortedEventList, nil, nil, true, false)
		if ok and type(result) == "table" then
			return result
		end
	end
	if type(C_EncounterTimeline.GetEventList) == "function" then
		local ok, result = pcall(C_EncounterTimeline.GetEventList)
		if ok and type(result) == "table" then
			return result
		end
	end
	return nil
end

local function isTerminalEventState(state)
	if not (Enum and Enum.EncounterTimelineEventState) then return false end
	return state == Enum.EncounterTimelineEventState.Finished
		or state == Enum.EncounterTimelineEventState.Canceled
end

local function isQueuedTrack(track)
	if not (Enum and Enum.EncounterTimelineTrack) then return false end
	return track == Enum.EncounterTimelineTrack.Queued
end

local function resolveTimelineLabel(info, spellID)
	if type(info) == "table" then
		local candidates = {
			info.spellName,
			info.name,
			info.text,
			info.title,
			info.label,
			info.overrideName,
		}
		for i = 1, #candidates do
			local label = candidates[i]
			if isSecretValue(label) then
				return label
			end
			if type(label) == "string" and label ~= "" then
				return label
			end
		end
	end

	if type(spellID) == "number" then
		if C_Spell and type(C_Spell.GetSpellName) == "function" then
			local ok, name = pcall(C_Spell.GetSpellName, spellID)
			if ok and type(name) == "string" and name ~= "" then
				return name
			end
		end
		if type(GetSpellInfo) == "function" then
			local ok, name = pcall(GetSpellInfo, spellID)
			if ok and type(name) == "string" and name ~= "" then
				return name
			end
		end
	end

	return ""
end

local function resolveTimelineIcon(info, spellID)
	if type(info) == "table" then
		local icon = info.iconFileID or info.icon
		if icon ~= nil then
			return icon
		end
	end

	if type(spellID) == "number" then
		if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
			local ok, spellInfo = pcall(C_Spell.GetSpellInfo, spellID)
			if ok and type(spellInfo) == "table" and spellInfo.iconID then
				return spellInfo.iconID
			end
		end
		if type(GetSpellInfo) == "function" then
			local ok, _, _, icon = pcall(GetSpellInfo, spellID)
			if ok and icon then
				return icon
			end
		end
	end

	return nil
end

local connector = {
	id = "timeline",
	label = "Timeline",
}

function connector:IsAvailable()
	if not C_EncounterTimeline then
		return false, "Encounter Timeline API unavailable"
	end
	if type(C_EncounterTimeline.GetEventInfo) ~= "function" then
		return false, "Encounter Timeline API unavailable"
	end
	if type(C_EncounterTimeline.GetEventTimeRemaining) ~= "function" then
		return false, "Encounter Timeline API unavailable"
	end
	return true
end

function connector:CollectEvents(_, now)
	now = now or ((GetTime and GetTime()) or 0)
	local events = {}
	local list = getTimelineEventList()
	if type(list) ~= "table" then
		return events
	end

	for _, eventID in ipairs(list) do
		local idType = type(eventID)
		if idType == "number" or idType == "string" then
			local info
			if type(C_EncounterTimeline.GetEventInfo) == "function" then
				local ok, eventInfo = pcall(C_EncounterTimeline.GetEventInfo, eventID)
				if ok then
					info = eventInfo
				end
			end

			if info then
				local track
				if type(C_EncounterTimeline.GetEventTrack) == "function" then
					local ok, value = pcall(C_EncounterTimeline.GetEventTrack, eventID)
					if ok then
						track = value
					end
				end

				local state
				if type(C_EncounterTimeline.GetEventState) == "function" then
					local ok, value = pcall(C_EncounterTimeline.GetEventState, eventID)
					if ok then
						state = value
					end
				end

				local isTerminal = isTerminalEventState(state)
				local queued = isQueuedTrack(track) and not isTerminal

				local blocked = false
				if type(C_EncounterTimeline.IsEventBlocked) == "function" then
					local ok, value = pcall(C_EncounterTimeline.IsEventBlocked, eventID)
					if ok and value == true then
						blocked = true
					end
				end

				local paused = false
				if Enum and Enum.EncounterTimelineEventState then
					paused = (state == Enum.EncounterTimelineEventState.Paused)
				end

				local remaining
				if type(C_EncounterTimeline.GetEventTimeRemaining) == "function" then
					local ok, value = pcall(C_EncounterTimeline.GetEventTimeRemaining, eventID)
					if ok then
						remaining = value
					end
				end

					if not isTerminal and (queued or (type(remaining) == "number" and remaining > 0)) then
						local spellID = info.spellID
						if spellID == nil then
							spellID = info.spellId
						end
						local displayName = resolveTimelineLabel(info, spellID)
						local iconFileID = resolveTimelineIcon(info, spellID)
						local iconsMask = info.icons
						if not isSecretValue(iconsMask) and type(iconsMask) ~= "number" then
							iconsMask = nil
						end

						events[#events + 1] = {
							id = eventID,
							eventInfo = {
								name = displayName,
								spellID = spellID,
								icon = iconFileID,
								icons = iconsMask,
								timelineEventID = eventID,
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

M:RegisterConnector(connector)
