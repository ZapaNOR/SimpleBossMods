-- DBM connector.

local ADDON_NAME = ...
local M = _G[ADDON_NAME]
if not M then return end

local records = {}
local DBT_PRUNE_GRACE = 0.8
local connector = nil
local timelineEventColorMap = {}
local timelineEventMetaMap = {}
local DBM_COLOR_SUFFIX = {
	[0] = "",
	[1] = "A",
	[2] = "AE",
	[3] = "D",
	[4] = "I",
	[5] = "R",
	[6] = "P",
	[7] = "UI",
	[8] = "I2",
}

local function nowTime()
	return (GetTime and GetTime()) or 0
end

local function useDBMColorsEnabled()
	local cfg = SimpleBossModsDB and SimpleBossModsDB.cfg
	local connectors = cfg and cfg.connectors
	if type(connectors) ~= "table" then
		return true
	end
	return connectors.useDBMColors ~= false
end

local function isSecretValue(value)
	return type(issecretvalue) == "function" and issecretvalue(value)
end

local function toNumber(value)
	if isSecretValue(value) then
		return nil
	end
	local n = tonumber(value)
	if type(n) == "number" and not isSecretValue(n) then
		return n
	end
	return nil
end

local function normalizeColorType(value)
	local n = toNumber(value)
	if type(n) ~= "number" then
		return nil
	end
	n = math.floor(n + 0.5)
	if not DBM_COLOR_SUFFIX[n] then
		return nil
	end
	return n
end

local function parseSpellID(value)
	if isSecretValue(value) then
		return value
	end
	if type(value) == "number" then
		return value
	end
	if type(value) == "string" then
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
	return nil
end

local function parseSpellIDFromSourceID(sourceID)
	if isSecretValue(sourceID) or sourceID == nil then
		return nil
	end
	local s = tostring(sourceID)
	if s == "" then
		return nil
	end
	local base = s:match("^([^\t]+)") or s
	local spellID = base:match("^Timer(%d+)")
	if spellID then
		return tonumber(spellID)
	end
	local ejID = base:match("^Timerej(%d+)")
	if ejID then
		return tonumber(ejID)
	end
	return nil
end

local function sanitizeLabel(value)
	if isSecretValue(value) then
		return value
	end
	if type(value) == "string" then
		value = value:gsub("|T.-|t", "")
		value = value:match("^%s*(.-)%s*$") or value
		if value ~= "" then
			return value
		end
	end
	return nil
end

local function pickLabel(...)
	for i = 1, select("#", ...) do
		local value = sanitizeLabel(select(i, ...))
		if value ~= nil then
			return value
		end
	end
	return nil
end

local function getSpellName(spellID)
	if type(spellID) ~= "number" then
		return nil
	end
	if C_Spell and C_Spell.GetSpellName then
		local ok, name = pcall(C_Spell.GetSpellName, spellID)
		if ok and type(name) == "string" and name ~= "" then
			return name
		end
	end
	if GetSpellInfo then
		local ok, name = pcall(GetSpellInfo, spellID)
		if ok and type(name) == "string" and name ~= "" then
			return name
		end
	end
	return nil
end

local function getDisplayLabel(rec)
	local label = sanitizeLabel(rec and rec.label)
	local sourceID = sanitizeLabel(rec and rec.sourceID)
	if label ~= nil then
		if isSecretValue(label) then
			return label
		end
		if label ~= "DBM Timer" and label ~= sourceID then
			return label
		end
	end
	local spellLabel = sanitizeLabel(rec and rec.spellName)
	if spellLabel ~= nil then
		return spellLabel
	end
	local spellName = getSpellName(rec and rec.spellID)
	if spellName then
		return spellName
	end
	if sourceID then
		return sourceID
	end
	return "DBM Timer"
end

local function normalizeRecordID(id)
	if id == nil then
		return nil
	end
	return "dbm:" .. tostring(id)
end

local function getRecord(id)
	local sourceID = tostring(id)
	id = normalizeRecordID(id)
	if not id then return nil end
	local rec = records[id]
	if not rec then
		rec = { id = id, sourceID = sourceID }
		records[id] = rec
	elseif not rec.sourceID then
		rec.sourceID = sourceID
	end
	return rec
end

local function removeRecord(id)
	id = normalizeRecordID(id)
	if not id then return end
	records[id] = nil
end

local function parseTimelineStyleEventID(value)
	if isSecretValue(value) then
		return nil
	end
	if type(value) == "number" then
		return value
	end
	if type(value) == "string" then
		return tonumber(value) or tonumber(value:match("^(%d+)\t"))
	end
	return nil
end

local function cacheTimelineEventMeta(eventInfo)
	if type(eventInfo) ~= "table" then
		return nil, nil
	end
	local eventID = parseTimelineStyleEventID(eventInfo.id or eventInfo.eventID)
	if not eventID then
		return nil, nil
	end

	local meta = timelineEventMetaMap[eventID]
	if type(meta) ~= "table" then
		meta = {}
		timelineEventMetaMap[eventID] = meta
	end

	local spellID = parseSpellID(eventInfo.spellID)
	if spellID ~= nil then
		meta.spellID = spellID
	end

	local spellName = pickLabel(eventInfo.spellName, eventInfo.overrideName, eventInfo.name)
	if spellName ~= nil then
		meta.spellName = spellName
	end

	local icon = eventInfo.iconFileID or eventInfo.icon
	if icon ~= nil then
		meta.icon = icon
	end

	local color = eventInfo.color
	if type(color) == "table" then
		local rawR = color.r or color[1]
		local rawG = color.g or color[2]
		local rawB = color.b or color[3]
		local rawA = color.a or color[4] or 1
		local normalizedColor = nil
		if rawR ~= nil and rawG ~= nil and rawB ~= nil then
			if isSecretValue(rawR) or isSecretValue(rawG) or isSecretValue(rawB) or isSecretValue(rawA) then
				normalizedColor = { r = rawR, g = rawG, b = rawB, a = rawA }
			else
				local r, g, b = toNumber(rawR), toNumber(rawG), toNumber(rawB)
				local a = toNumber(rawA)
				if r and g and b then
					normalizedColor = { r = r, g = g, b = b, a = a or 1 }
				end
			end
		end
		if normalizedColor then
			meta.optionMappedColor = normalizedColor
			timelineEventColorMap[eventID] = normalizedColor
		end
	end

	return eventID, meta
end

local function getTimelineEventMeta(eventID)
	local parsedID = parseTimelineStyleEventID(eventID)
	if not parsedID then
		return nil, nil
	end

	local meta = timelineEventMetaMap[parsedID]
	if type(meta) == "table" then
		return parsedID, meta
	end

	if type(C_EncounterTimeline) == "table" and type(C_EncounterTimeline.GetEventInfo) == "function" then
		local ok, eventInfo = pcall(C_EncounterTimeline.GetEventInfo, parsedID)
		if ok and type(eventInfo) == "table" then
			local _, cached = cacheTimelineEventMeta(eventInfo)
			if type(cached) == "table" then
				return parsedID, cached
			end
		end
	end

	return parsedID, nil
end

local function applyTimelineEventMetaToRecord(rec, eventID)
	if type(rec) ~= "table" then
		return
	end
	local _, meta = getTimelineEventMeta(eventID)
	if type(meta) ~= "table" then
		return
	end

	if rec.spellID == nil and meta.spellID ~= nil then
		rec.spellID = meta.spellID
	end
	if rec.spellName == nil and meta.spellName ~= nil then
		rec.spellName = meta.spellName
	end
	if rec.icon == nil and meta.icon ~= nil then
		rec.icon = meta.icon
	end
	if rec.optionMappedColor == nil and meta.optionMappedColor ~= nil then
		rec.optionMappedColor = meta.optionMappedColor
	end
end

local function makeColorTable(r, g, b, a)
	if r == nil or g == nil or b == nil then
		return nil
	end
	if isSecretValue(r) or isSecretValue(g) or isSecretValue(b) or isSecretValue(a) then
		return {
			r = r,
			g = g,
			b = b,
			a = (a ~= nil) and a or 1,
		}
	end
	local nr, ng, nb, na = toNumber(r), toNumber(g), toNumber(b), toNumber(a or 1)
	if nr and ng and nb then
		return { r = nr, g = ng, b = nb, a = na or 1 }
	end
	return nil
end

local function normalizeColorTable(color)
	if type(color) ~= "table" then
		return nil
	end
	if type(color.GetRGBA) == "function" then
		local ok, r, g, b, a = pcall(color.GetRGBA, color)
		if ok then
			local resolved = makeColorTable(r, g, b, a)
			if resolved then
				return resolved
			end
		end
	end
	if type(color.GetRGB) == "function" then
		local ok, r, g, b = pcall(color.GetRGB, color)
		if ok then
			local resolved = makeColorTable(r, g, b, 1)
			if resolved then
				return resolved
			end
		end
	end
	return makeColorTable(color.r or color[1], color.g or color[2], color.b or color[3], color.a or color[4] or 1)
end

local function getTypeColorFromOptions(colorType, isEndColor)
	local opts = type(DBT) == "table" and type(DBT.Options) == "table" and DBT.Options or nil
	if not opts then
		return nil
	end
	local suffix = DBM_COLOR_SUFFIX[colorType]
	if not suffix then
		return nil
	end
	local prefix = isEndColor and "EndColor" or "StartColor"
	local r = toNumber(opts[prefix .. suffix .. "R"])
	local g = toNumber(opts[prefix .. suffix .. "G"])
	local b = toNumber(opts[prefix .. suffix .. "B"])
	if not r or not g or not b then
		return nil
	end
	return { r = r, g = g, b = b, a = 1 }
end

local function getBaseTimerID(sourceID)
	if isSecretValue(sourceID) then
		return nil
	end
	if sourceID == nil then
		return nil
	end
	local s = tostring(sourceID)
	if s == "" then
		return nil
	end
	local base = s:match("^([^\t]+)")
	if type(base) == "string" and base ~= "" then
		return base
	end
	return s
end

local function getModOptionColorType(rec)
	if type(rec) ~= "table" then
		return nil
	end
	if type(DBM) ~= "table" or type(DBM.GetModByName) ~= "function" then
		return nil
	end
	local modId = rec.modId
	if isSecretValue(modId) or modId == nil then
		return nil
	end
	local mod = DBM:GetModByName(tostring(modId))
	if type(mod) ~= "table" or type(mod.Options) ~= "table" then
		return nil
	end

	local options = mod.Options
	local baseTimerID = rec.baseTimerID or getBaseTimerID(rec.sourceID)
	if baseTimerID then
		rec.baseTimerID = baseTimerID
		local optionColorType = normalizeColorType(options[baseTimerID .. "TColor"])
		if optionColorType ~= nil then
			return optionColorType
		end
	end

	return nil
end

local function getDBMBarColors(rec, remaining)
	local customColor = normalizeColorTable(rec and rec.customColor)
	local optionMappedColor = normalizeColorTable(rec and rec.optionMappedColor)
	local renderedColor = normalizeColorTable(rec and rec.renderColor)

	-- Match DBT behavior: if bar has explicit color (self.color), use it directly.
	if customColor then
		return customColor, customColor, customColor
	end
	-- DBM timeline custom timer options feed event colors via C_EncounterEvents.SetEventColor.
	-- Use that mapped color when the raw bar color isn't readable from insecure code.
	if optionMappedColor then
		return optionMappedColor, optionMappedColor, optionMappedColor
	end

	if type(DBT) ~= "table" or type(DBT.GetColorForType) ~= "function" then
		local fallbackColor = renderedColor
		if fallbackColor then
			return fallbackColor, fallbackColor, fallbackColor
		end
		return nil, nil, nil
	end

	local function pickColorType(...)
		local sawZero = false
		for i = 1, select("#", ...) do
			local n = normalizeColorType(select(i, ...))
			if n ~= nil then
				if n ~= 0 then
					return n
				end
				sawZero = true
			end
		end
		if sawZero then
			return 0
		end
		return nil
	end

	local resolvedColorType = pickColorType(
		rec and rec.colorTypeBarRaw,
		rec and rec.colorTypeCreateRaw,
		rec and rec.colorTypeCallbackRaw,
		rec and rec.colorTypeBar,
		rec and rec.colorTypeCreate,
		rec and rec.colorTypeCallback,
		rec and rec.colorType,
		getModOptionColorType(rec)
	)

	if resolvedColorType == nil and renderedColor then
		return renderedColor, nil, nil
	end

	local colorType = resolvedColorType
	if colorType == nil then
		colorType = 0
	end
	if type(DBT.Options) == "table" and DBT.Options.ColorByType == false then
		colorType = 0
	end

	local okStart, sr, sg, sb = pcall(DBT.GetColorForType, DBT, colorType, false)
	sr, sg, sb = okStart and toNumber(sr) or nil, okStart and toNumber(sg) or nil, okStart and toNumber(sb) or nil
	if not sr or not sg or not sb then
		local fallbackType = normalizeColorType(colorType) or 0
		local fallbackColor = getTypeColorFromOptions(fallbackType, false)
		if not fallbackColor then
			local fallbackDirect = renderedColor
			if fallbackDirect then
				return fallbackDirect, fallbackDirect, fallbackDirect
			end
			return nil, nil, nil
		end
		sr, sg, sb = fallbackColor.r, fallbackColor.g, fallbackColor.b
	end
	local fromColor = { r = sr, g = sg, b = sb, a = 1 }

	local okEnd, er, eg, eb = pcall(DBT.GetColorForType, DBT, colorType, true)
	er, eg, eb = okEnd and toNumber(er) or nil, okEnd and toNumber(eg) or nil, okEnd and toNumber(eb) or nil
	if not er or not eg or not eb then
		local fallbackType = normalizeColorType(colorType)
		local fallbackEnd = fallbackType and getTypeColorFromOptions(fallbackType, true) or nil
		if fallbackEnd then
			er, eg, eb = fallbackEnd.r, fallbackEnd.g, fallbackEnd.b
		else
			er, eg, eb = sr, sg, sb
		end
	end
	local toColor = { r = er, g = eg, b = eb, a = 1 }

	local opts = type(DBT.Options) == "table" and DBT.Options or nil
	local dynamicColor = not (opts and opts.DynamicColor == false)
	local noFade = opts and opts.NoBarFade
	if not dynamicColor then
		return fromColor, fromColor, toColor
	end
	if noFade then
		if rec and rec.enlarged then
			return toColor, fromColor, toColor
		end
		return fromColor, fromColor, toColor
	end

	local dur = tonumber(rec and rec.duration)
	local rem = tonumber(remaining)
	if not dur or dur <= 0 or not rem then
		return fromColor, fromColor, toColor
	end

	local progress = (dur - rem) / dur
	if progress < 0 then progress = 0 end
	if progress > 1 then progress = 1 end
	return {
		r = fromColor.r + (toColor.r - fromColor.r) * progress,
		g = fromColor.g + (toColor.g - fromColor.g) * progress,
		b = fromColor.b + (toColor.b - fromColor.b) * progress,
		a = 1,
	}, fromColor, toColor
end

local function syncRecordFromDBTBar(bar, now)
	if type(bar) ~= "table" or bar.id == nil then
		return
	end
	local rec = getRecord(bar.id)
	if not rec then
		return
	end

	rec.keep = bar.keep and true or false
	rec.paused = bar.paused and true or false
	rec.enlarged = bar.enlarged and true or false
	rec.colorTypeBarRaw = bar.colorType
	rec.colorTypeBar = normalizeColorType(bar.colorType)
	if rec.colorTypeBar ~= nil then
		if rec.colorTypeBar ~= 0 or rec.colorType == nil or rec.colorType == 0 then
			rec.colorType = rec.colorTypeBar
		end
	end
	rec.customColor = normalizeColorTable(bar.color)
	rec.sourceID = tostring(bar.id)
	rec.spellID = rec.spellID or parseSpellIDFromSourceID(rec.sourceID)
	local timelineStyleEventID = parseTimelineStyleEventID(bar.id)
	applyTimelineEventMetaToRecord(rec, timelineStyleEventID or bar.id)
	if timelineStyleEventID and timelineEventColorMap[timelineStyleEventID] then
		rec.optionMappedColor = timelineEventColorMap[timelineStyleEventID]
	end

	local duration = tonumber(bar.totalTime)
	if duration and duration > 0 then
		rec.duration = duration
	end

	local remaining = tonumber(bar.timer)
	if remaining and remaining >= 0 then
		rec.remaining = remaining
	end

	if rec.duration and rec.remaining then
		rec.startTime = now - math.max(rec.duration - rec.remaining, 0)
	end

	rec.fromDBT = true
	rec._lastSeenDBT = now

	local frame = bar.frame
	if type(frame) == "table" and frame.GetName then
		local frameName = frame:GetName()
		if type(frameName) == "string" and frameName ~= "" then
			local sb = _G[frameName .. "Bar"]
			if sb and sb.GetStatusBarTexture then
				if sb.GetStatusBarColor then
					local ok, rr, rg, rb, ra = pcall(sb.GetStatusBarColor, sb)
					if ok then
						local resolved = makeColorTable(rr, rg, rb, ra)
						if resolved then
							rec.renderColor = resolved
						end
					end
				end
				local tex = sb:GetStatusBarTexture()
				if (not rec.renderColor) and tex and tex.GetVertexColor then
					local ok, rr, rg, rb, ra = pcall(tex.GetVertexColor, tex)
					if ok then
						local resolved = makeColorTable(rr, rg, rb, ra)
						if resolved then
							rec.renderColor = resolved
						end
					end
				end
			end

			local labelFS = _G[frameName .. "BarName"]
			if labelFS and labelFS.GetText then
				rec.label = pickLabel(labelFS:GetText(), rec.label)
			end

			local iconTex = _G[frameName .. "BarIcon1"]
			if iconTex and iconTex.GetTexture then
				local texture = iconTex:GetTexture()
				if texture ~= nil then
					rec.icon = texture
				end
			end
		end
	end
end

local function iterateDBTBars(onBar)
	if type(onBar) ~= "function" or type(DBT) ~= "table" then
		return
	end

	local iter, state, init = nil, nil, nil
	if type(DBT.GetBarIterator) == "function" then
		local ok, a, b, c = pcall(DBT.GetBarIterator, DBT)
		if ok and type(a) == "function" then
			iter, state, init = a, b, c
		end
	end

	if type(iter) == "function" then
		for bar in iter, state, init do
			if type(bar) == "table" and not bar.dummy then
				onBar(bar)
			end
		end
		return
	end

	if type(DBT.bars) ~= "table" then
		return
	end
	for bar in pairs(DBT.bars) do
		if type(bar) == "table" and not bar.dummy then
			onBar(bar)
		end
	end
end

local function syncRecordsFromDBTBars(now)
	local active = {}
	iterateDBTBars(function(bar)
		syncRecordFromDBTBar(bar, now)
		local id = normalizeRecordID(bar.id)
		if id then
			active[id] = true
		end
	end)
	return active
end

local function ensureDBTHooks()
	if not connector or connector._dbtHooksInstalled then
		return
	end
	if type(hooksecurefunc) ~= "function" or type(DBT) ~= "table" then
		return
	end

	if type(DBT.CreateBar) == "function" then
		hooksecurefunc(DBT, "CreateBar", function(_, timer, id, icon, _, _, color, isDummy, colorType)
			if not connector._dbtTapActive then
				return
			end
			if id == nil or isDummy then
				return
			end
			local now = nowTime()
			local bar = type(DBT.GetBar) == "function" and DBT:GetBar(id) or nil
			if type(bar) == "table" and not bar.dummy then
				syncRecordFromDBTBar(bar, now)
				return
			end

				local rec = getRecord(id)
				if not rec then
					return
				end
				rec.colorTypeCreateRaw = colorType
				rec.colorTypeCreate = normalizeColorType(colorType)
				if rec.colorTypeCreate ~= nil then
					rec.colorType = rec.colorTypeCreate
				end
				rec.sourceID = tostring(id)
				rec.spellID = rec.spellID or parseSpellIDFromSourceID(rec.sourceID)
				rec.label = pickLabel(rec.label, rec.spellName)
				rec.icon = icon or rec.icon
				rec.customColor = normalizeColorTable(color) or rec.customColor
				local timelineStyleEventID = parseTimelineStyleEventID(id)
				applyTimelineEventMetaToRecord(rec, timelineStyleEventID or id)
				if timelineStyleEventID and timelineEventColorMap[timelineStyleEventID] then
					rec.optionMappedColor = timelineEventColorMap[timelineStyleEventID]
				end
				rec.duration = tonumber(timer) or rec.duration or 0
				rec.remaining = rec.duration
				rec.startTime = now
			rec.paused = false
			rec.fromDBT = true
			rec._lastSeenDBT = now
		end)
	end

	if type(DBT.UpdateBar) == "function" then
		hooksecurefunc(DBT, "UpdateBar", function(_, id, elapsed, totalTime)
			if not connector._dbtTapActive or id == nil then
				return
			end
			local now = nowTime()
			local rec = records[normalizeRecordID(id)]
			if not rec then
				local bar = type(DBT.GetBar) == "function" and DBT:GetBar(id) or nil
				if type(bar) == "table" and not bar.dummy then
					syncRecordFromDBTBar(bar, now)
				end
				return
			end

			if type(totalTime) == "number" and totalTime > 0 then
				rec.duration = totalTime
			end
			if type(elapsed) == "number" and type(rec.duration) == "number" then
				rec.remaining = math.max(rec.duration - elapsed, 0)
				rec.startTime = now - elapsed
			end
			rec.fromDBT = true
			rec._lastSeenDBT = now
		end)
	end

	if type(DBT.CancelBar) == "function" then
		hooksecurefunc(DBT, "CancelBar", function(_, id)
			if not connector._dbtTapActive or id == nil then
				return
			end
			removeRecord(id)
		end)
	end

	if not connector._encounterEventColorHookInstalled
		and type(C_EncounterEvents) == "table"
		and type(C_EncounterEvents.SetEventColor) == "function"
	then
		hooksecurefunc(C_EncounterEvents, "SetEventColor", function(eventID, color)
			local parsedID = parseTimelineStyleEventID(eventID)
			if not parsedID then
				return
			end
			local normalizedColor = normalizeColorTable(color)
			if normalizedColor then
				timelineEventColorMap[parsedID] = normalizedColor
			end
		end)
		connector._encounterEventColorHookInstalled = true
	end

	if not connector._dbmTimelineEventHookInstalled
		and type(DBM) == "table"
		and type(DBM.ENCOUNTER_TIMELINE_EVENT_ADDED) == "function"
	then
		hooksecurefunc(DBM, "ENCOUNTER_TIMELINE_EVENT_ADDED", function(_, eventInfo)
			local eventID = cacheTimelineEventMeta(eventInfo)
			if not eventID then
				return
			end
			local rec = records[normalizeRecordID(eventID)]
			if rec then
				applyTimelineEventMetaToRecord(rec, eventID)
			end
		end)
		connector._dbmTimelineEventHookInstalled = true
	end

	connector._dbtHooksInstalled = true
end

connector = {
	id = "dbm",
	label = "DBM",
}

function connector:IsAvailable()
	if not DBM then
		return false, "DBM is not loaded"
	end
	if type(DBM.RegisterCallback) ~= "function" then
		return false, "DBM callback API unavailable"
	end
	return true
end

function connector:Activate()
	local available = select(1, self:IsAvailable())
	if not available then
		return false, "DBM is not loaded"
	end

	if self._registered then
		self._dbtTapActive = true
		return true
	end

	DBM:RegisterCallback("DBM_TimerBegin", self._onTimerBegin)
	DBM:RegisterCallback("DBM_TimerUpdate", self._onTimerUpdate)
	DBM:RegisterCallback("DBM_TimerStop", self._onTimerStop)
	DBM:RegisterCallback("DBM_TimerPause", self._onTimerPause)
	DBM:RegisterCallback("DBM_TimerResume", self._onTimerResume)
	DBM:RegisterCallback("DBM_TimerUpdateIcon", self._onTimerUpdateIcon)

	ensureDBTHooks()
	self._dbtTapActive = true
	self._registered = true
	return true
end

function connector:Deactivate()
	if DBM and type(DBM.UnregisterCallback) == "function" and self._registered then
		pcall(DBM.UnregisterCallback, DBM, "DBM_TimerBegin", self._onTimerBegin)
		pcall(DBM.UnregisterCallback, DBM, "DBM_TimerUpdate", self._onTimerUpdate)
		pcall(DBM.UnregisterCallback, DBM, "DBM_TimerStop", self._onTimerStop)
		pcall(DBM.UnregisterCallback, DBM, "DBM_TimerPause", self._onTimerPause)
		pcall(DBM.UnregisterCallback, DBM, "DBM_TimerResume", self._onTimerResume)
		pcall(DBM.UnregisterCallback, DBM, "DBM_TimerUpdateIcon", self._onTimerUpdateIcon)
	end
	self._dbtTapActive = nil
	self._registered = nil
	wipe(records)
	wipe(timelineEventColorMap)
	wipe(timelineEventMetaMap)
end

connector._onTimerBegin = function(_, id, msg, timer, icon, barType, spellId, colorType, modId, keep, fade, name)
	if not id then return end
	local rec = getRecord(id)
	if not rec then return end
	rec.sourceID = tostring(id)
	rec.spellName = pickLabel(name, rec.spellName)
	rec.label = pickLabel(msg, rec.label, rec.spellName)
	rec.icon = icon
	rec.duration = tonumber(timer) or rec.duration or 0
	rec.remaining = rec.duration
	rec.startTime = nowTime()
	rec.paused = false
	rec.enlarged = nil
	rec.customColor = nil
	rec.keep = keep and true or false
	rec.spellID = parseSpellID(spellId) or parseSpellIDFromSourceID(id) or rec.spellID
	rec.modId = modId
	rec.baseTimerID = getBaseTimerID(rec.sourceID) or rec.baseTimerID
	local timelineStyleEventID = parseTimelineStyleEventID(id)
	applyTimelineEventMetaToRecord(rec, timelineStyleEventID or id)
	if timelineStyleEventID and timelineEventColorMap[timelineStyleEventID] then
		rec.optionMappedColor = timelineEventColorMap[timelineStyleEventID]
	end
	rec.colorTypeCallbackRaw = colorType
	rec.colorTypeCallback = normalizeColorType(colorType)
	if rec.colorTypeCallback ~= nil then
		rec.colorType = rec.colorTypeCallback
	end
end

connector._onTimerUpdate = function(_, id, elapsed, total)
	if not id then return end
	local rec = getRecord(id)
	if not rec then return end
	if type(total) == "number" and total > 0 then
		rec.duration = total
	end
	if type(elapsed) == "number" and type(rec.duration) == "number" then
		rec.remaining = math.max(rec.duration - elapsed, 0)
		rec.startTime = nowTime() - elapsed
	end
end

connector._onTimerStop = function(_, id)
	removeRecord(id)
end

connector._onTimerPause = function(_, id)
	if not id then return end
	local rec = records[normalizeRecordID(id)]
	if not rec then return end
	if not rec.paused and rec.duration and rec.startTime then
		rec.remaining = math.max(rec.duration - (nowTime() - rec.startTime), 0)
	end
	rec.paused = true
end

connector._onTimerResume = function(_, id)
	if not id then return end
	local rec = records[normalizeRecordID(id)]
	if not rec then return end
	rec.paused = false
	if rec.duration and rec.remaining then
		rec.startTime = nowTime() - (rec.duration - rec.remaining)
	end
end

connector._onTimerUpdateIcon = function(_, id, icon)
	if not id then return end
	local rec = records[normalizeRecordID(id)]
	if not rec then return end
	rec.icon = icon
end

function connector:CollectEvents(_, now)
	now = now or nowTime()
	ensureDBTHooks()
	local activeDBTBars = syncRecordsFromDBTBars(now)
	local useDBMColors = useDBMColorsEnabled()
	local events = {}
	local remove = nil

	for id, rec in pairs(records) do
		local shouldRemove = false
		if rec.fromDBT and not activeDBTBars[id] then
			local lastSeenDBT = tonumber(rec._lastSeenDBT) or 0
			if (now - lastSeenDBT) > DBT_PRUNE_GRACE then
				shouldRemove = true
			end
		end

		if not shouldRemove then
			local remaining = rec.remaining
			if not rec.paused and rec.duration and rec.startTime then
				remaining = math.max(rec.duration - (now - rec.startTime), 0)
				rec.remaining = remaining
			end

			if type(remaining) == "number" and remaining <= 0 and not rec.keep then
				shouldRemove = true
			else
					local color, colorFrom, colorTo = nil, nil, nil
					if useDBMColors then
						color, colorFrom, colorTo = getDBMBarColors(rec, remaining)
					end
						events[#events + 1] = {
							id = id,
							eventInfo = {
								name = getDisplayLabel(rec),
								spellName = rec.spellName,
								icon = rec.icon,
								spellID = rec.spellID,
								color = color,
								colorFrom = colorFrom,
								colorTo = colorTo,
						},
						remaining = remaining,
						isPaused = rec.paused and true or false,
						isBlocked = false,
					isQueued = false,
				}
			end
		end

		if shouldRemove then
			remove = remove or {}
			remove[#remove + 1] = id
		end
	end

	if remove then
		for _, id in ipairs(remove) do
			records[id] = nil
		end
	end

	return events
end

M:RegisterConnector(connector)
