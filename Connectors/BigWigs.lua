-- BigWigs connector.

local ADDON_NAME = ...
local M = _G[ADDON_NAME]
if not M then return end

local records = {}
local barToRecord = setmetatable({}, { __mode = "k" })
local trackedBars = setmetatable({}, { __mode = "k" })
local barOriginalAlpha = setmetatable({}, { __mode = "k" })
local hideNativeBars = false

local function nowTime()
	return (GetTime and GetTime()) or 0
end

local function getBigWigsColorMode()
	local cfg = SimpleBossModsDB and SimpleBossModsDB.cfg
	local connectors = cfg and cfg.connectors
	if type(connectors) ~= "table" then
		return "normal"
	end
	local mode = connectors.bigWigsColorMode
	if type(mode) ~= "string" then
		return "normal"
	end
	mode = mode:lower()
	if mode == "emphasized" then
		return "emphasized"
	end
	return "normal"
end

local function setFrameAlpha(frame, alpha)
	if type(frame) ~= "table" or type(frame.SetAlpha) ~= "function" then
		return
	end
	pcall(frame.SetAlpha, frame, alpha)
end

local function getFrameAlpha(frame)
	if type(frame) ~= "table" or type(frame.GetAlpha) ~= "function" then
		return 1
	end
	local ok, alpha = pcall(frame.GetAlpha, frame)
	if ok and type(alpha) == "number" then
		return alpha
	end
	return 1
end

local function applyNativeBarsHiddenState()
	for bar in pairs(trackedBars) do
		if hideNativeBars then
			setFrameAlpha(bar, 0)
		else
			setFrameAlpha(bar, barOriginalAlpha[bar] or 1)
		end
	end
end

local function trackBarFrame(bar)
	if type(bar) ~= "table" or type(bar.SetAlpha) ~= "function" then
		return
	end
	if bar == UIParent then
		return
	end
	if type(bar.IsForbidden) == "function" then
		local ok, forbidden = pcall(bar.IsForbidden, bar)
		if ok and forbidden then
			return
		end
	end
	if not trackedBars[bar] then
		trackedBars[bar] = true
		barOriginalAlpha[bar] = getFrameAlpha(bar)
	end
	if hideNativeBars then
		setFrameAlpha(bar, 0)
	end
end

local function isSecretValue(value)
	return type(issecretvalue) == "function" and issecretvalue(value)
end

local function normalizeModuleKey(module)
	if isSecretValue(module) then return "" end
	if type(module) == "table" then
		local name = module.moduleName or module.name
		if type(name) == "string" and name ~= "" then
			return name
		end
		return tostring(module)
	end
	if module == nil then return "" end
	return tostring(module)
end

local function normalizeText(value)
	if isSecretValue(value) then return "" end
	if type(value) == "string" then
		return value
	end
	if value == nil then
		return ""
	end
	return tostring(value)
end

local function setRecordLabel(rec, value)
	if type(rec) ~= "table" or value == nil then
		return
	end
	if isSecretValue(value) then
		rec.label = value
		return
	end
	if type(value) == "string" then
		local trimmed = value:match("^%s*(.-)%s*$")
		if trimmed ~= "" then
			rec.label = trimmed
		end
		return
	end
	rec.label = tostring(value)
end

local function setRecordIcon(rec, value)
	if type(rec) ~= "table" or value == nil then
		return
	end
	if isSecretValue(value) then
		rec.icon = value
		return
	end
	rec.icon = value
end

local function safeNumber(value)
	if isSecretValue(value) then
		return nil
	end
	local n = tonumber(value)
	if type(n) == "number" then
		return n
	end
	return nil
end

local function normalizeOptionKey(value)
	if value == nil or isSecretValue(value) then
		return nil
	end
	return value
end

local function optionKeyToID(value)
	if value == nil or isSecretValue(value) then
		return nil
	end
	return tostring(value)
end

local function parseNumericSpellID(value)
	if value == nil then
		return nil
	end
	if isSecretValue(value) then
		local ok, asString = pcall(tostring, value)
		if not ok or type(asString) ~= "string" then
			return nil
		end
		local trimmed = asString:match("^%s*(.-)%s*$")
		if trimmed == "" then
			return nil
		end
		return tonumber(trimmed)
			or tonumber(trimmed:match("^spell:(%d+)$"))
			or tonumber(trimmed:match("^Timer(%d+)"))
			or tonumber(trimmed:match("^Timerej(%d+)"))
			or tonumber(trimmed:match("^ej(%d+)$"))
	end
	local n = tonumber(value)
	if type(n) == "number" then
		return n
	end
	return nil
end

local function parseSpellID(value)
	if isSecretValue(value) then
		return parseNumericSpellID(value)
	end
	local direct = parseNumericSpellID(value)
	if direct ~= nil then
		return direct
	end
	if type(value) == "table" then
		local direct = parseSpellID(value.spellID or value.spellId or value.id)
		if direct ~= nil then
			return direct
		end
		return parseSpellID(rawget(value, 1))
	end
	if type(value) == "string" then
		local trimmed = value:match("^%s*(.-)%s*$")
		if trimmed == "" then
			return nil
		end
		return parseNumericSpellID(trimmed)
	end
	return nil
end

local function getSpellNameByID(spellID)
	if type(spellID) ~= "number" then
		return nil
	end
	if C_Spell and type(C_Spell.GetSpellName) == "function" then
		local ok, name = pcall(C_Spell.GetSpellName, spellID)
		if ok and type(name) == "string" and name ~= "" and not isSecretValue(name) then
			return name
		end
	end
	if type(GetSpellInfo) == "function" then
		local ok, name = pcall(GetSpellInfo, spellID)
		if ok and type(name) == "string" and name ~= "" and not isSecretValue(name) then
			return name
		end
	end
	return nil
end

local function getSpellIconByID(spellID)
	if type(spellID) ~= "number" then
		return nil
	end
	if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
		local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
		if ok and type(info) == "table" and not isSecretValue(info.iconID) and info.iconID ~= nil then
			return info.iconID
		end
	end
	if type(GetSpellInfo) == "function" then
		local ok, _, _, icon = pcall(GetSpellInfo, spellID)
		if ok and icon ~= nil and not isSecretValue(icon) then
			return icon
		end
	end
	return nil
end

local function getBigWigsOptionDetails(moduleRef, optionKey)
	if moduleRef == nil or optionKey == nil then
		return nil, nil, nil
	end
	if type(BigWigs) ~= "table" or type(BigWigs.GetBossOptionDetails) ~= "function" then
		return nil, nil, nil
	end

	local ok, option, title, _, icon = pcall(BigWigs.GetBossOptionDetails, BigWigs, moduleRef, optionKey)
	if not ok then
		return nil, nil, nil
	end

	if isSecretValue(option) then
		option = nil
	end
	if isSecretValue(title) then
		title = nil
	end
	if isSecretValue(icon) then
		icon = nil
	end
	return option, title, icon
end

local function normalizeColor(r, g, b, a)
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
	r, g, b, a = tonumber(r), tonumber(g), tonumber(b), tonumber(a or 1)
	if type(r) == "number" and type(g) == "number" and type(b) == "number" then
		return { r = r, g = g, b = b, a = a or 1 }
	end
	return nil
end

local function getBigWigsColorsPlugin()
	if type(BigWigs) ~= "table" or type(BigWigs.GetPlugin) ~= "function" then
		return nil
	end
	local ok, plugin = pcall(BigWigs.GetPlugin, BigWigs, "Colors", true)
	if not ok or type(plugin) ~= "table" or type(plugin.GetColor) ~= "function" then
		return nil
	end
	return plugin
end

local function queryBigWigsColor(hint, moduleRef, moduleName, optionKey)
	local plugin = getBigWigsColorsPlugin()
	if not plugin then
		return nil
	end

	local ok, r, g, b, a
	if moduleRef ~= nil and optionKey ~= nil then
		ok, r, g, b, a = pcall(plugin.GetColor, plugin, hint, moduleRef, optionKey)
		if ok then
			local color = normalizeColor(r, g, b, a)
			if color then
				return color
			end
		end
	end

	if moduleName ~= nil and optionKey ~= nil then
		ok, r, g, b, a = pcall(plugin.GetColor, plugin, hint, moduleName, optionKey)
		if ok then
			local color = normalizeColor(r, g, b, a)
			if color then
				return color
			end
		end
	end

	ok, r, g, b, a = pcall(plugin.GetColor, plugin, hint, nil, nil)
	if ok then
		return normalizeColor(r, g, b, a)
	end
	return nil
end

local function getConfiguredBigWigsBarColor(rec)
	if type(rec) ~= "table" then
		return nil
	end
	local mode = getBigWigsColorMode()
	local hint = (mode == "emphasized") and "barEmphasized" or "barColor"
	return queryBigWigsColor(hint, rec.moduleRef, rec.moduleColorName or rec.moduleKey, rec.optionKey)
end

local function normalizeTimelineEventID(value)
	if value == nil then
		return nil
	end
	if isSecretValue(value) then
		return nil
	end
	local valueType = type(value)
	if valueType == "number" or valueType == "string" then
		return value
	end
	return nil
end

local function applyTimelineEventInfo(rec, timelineEventID)
	if type(rec) ~= "table" then
		return
	end

	local eventID = normalizeTimelineEventID(timelineEventID)
	if not eventID then
		return
	end

	rec.timelineEventID = eventID
	rec.eventID = eventID
end

local function buildRecordID(module, text, eventID, key)
	if normalizeTimelineEventID(eventID) ~= nil then
		return "bw:event:" .. tostring(eventID)
	end
	local moduleKey = normalizeModuleKey(module)
	local barText = normalizeText(text)
	if barText ~= "" then
		return "bw:bar:" .. moduleKey .. ":t:" .. barText
	end
	local optionKey = normalizeOptionKey(key)
	if optionKey then
		return "bw:bar:" .. moduleKey .. ":k:" .. (optionKeyToID(optionKey) or "nil")
	end
	return "bw:bar:" .. moduleKey .. ":anon"
end

local function findRecordID(module, text, eventID, key)
	local id = buildRecordID(module, text, eventID, key)
	if records[id] then
		return id
	end

	local moduleKey = normalizeModuleKey(module)
	local barText = normalizeText(text)
	local optionKey = normalizeOptionKey(key)
	local optionKeyID = optionKeyToID(optionKey)
	local matchEventID = normalizeTimelineEventID(eventID)

	for recID, rec in pairs(records) do
			if rec then
				if matchEventID ~= nil and rec.eventID == matchEventID then
					return recID
				end
			if rec.moduleKey == moduleKey then
				if barText ~= "" and rec.label ~= nil and not isSecretValue(rec.label) and rec.label == barText then
					return recID
				end
				if barText == "" and optionKeyID and optionKeyToID(rec.optionKey) == optionKeyID then
					return recID
				end
			end
		end
	end

	return id
end

local function isBossModule(module)
	-- BigWigs is the source of truth for this connector: ingest all bars it emits.
	return true
end

local function getRecord(id)
	local rec = records[id]
	if not rec then
		rec = { id = id }
		records[id] = rec
	end
	return rec
end

local function removeRecord(id)
	records[id] = nil
end

local function updateFromStartData(rec, module, key, text, remaining, icon, isApproximate, maxTime, eventID)
	if not rec then return end

	rec.moduleKey = normalizeModuleKey(module)
	if module ~= nil and not isSecretValue(module) then
		rec.moduleRef = module
		if type(module) == "table" then
			local moduleName = module.name or module.moduleName
			if type(moduleName) == "string" and moduleName ~= "" then
				rec.moduleColorName = moduleName
			end
		elseif type(module) == "string" and module ~= "" then
			rec.moduleColorName = module
		end
	end
	rec.optionKey = normalizeOptionKey(key)
	if text ~= nil then
		setRecordLabel(rec, text)
	elseif rec.label == nil then
		rec.label = ""
	end
	if icon ~= nil then
		setRecordIcon(rec, icon)
	end
	rec.isApproximate = (type(isApproximate) == "boolean") and isApproximate or false
	rec.keep = false
	if eventID ~= nil then
		applyTimelineEventInfo(rec, eventID)
	end

	local duration = safeNumber(maxTime)
	local rem = safeNumber(remaining)
	if not duration or duration <= 0 then
		duration = rem
	end
	if not rem or rem < 0 then
		rem = duration
	end
	if duration and rem and rem > duration then
		duration = rem
	end

	if type(duration) == "number" then
		rec.duration = duration
	end
	if type(rem) == "number" then
		rec.remaining = rem
	end

	if rec.duration and rec.remaining then
		rec.startTime = nowTime() - math.max(rec.duration - rec.remaining, 0)
	end
	rec.paused = false

	rec.spellID = parseSpellID(key) or parseSpellID(rec.optionKey) or rec.spellID
	if type(rec.spellID) == "number" then
		rec.spellName = getSpellNameByID(rec.spellID) or rec.spellName
		if rec.icon == nil then
			setRecordIcon(rec, getSpellIconByID(rec.spellID))
		end
	end

	local optionID, optionName, optionIcon = getBigWigsOptionDetails(rec.moduleRef, rec.optionKey or key)
	rec.spellID = parseSpellID(optionID) or rec.spellID
	if type(rec.spellID) == "number" and rec.spellName == nil then
		rec.spellName = getSpellNameByID(rec.spellID) or rec.spellName
	end
	if rec.icon == nil and optionIcon ~= nil then
		setRecordIcon(rec, optionIcon)
	end
	if rec.label == nil or (not isSecretValue(rec.label) and rec.label == "") then
		if optionName ~= nil then
			setRecordLabel(rec, optionName)
		end
	end

	rec.configuredColor = getConfiguredBigWigsBarColor(rec) or rec.configuredColor
	if not isSecretValue(rec.label) and rec.label == "" then
		local spellName = rec.spellName or getSpellNameByID(rec.spellID)
		if spellName then
			setRecordLabel(rec, spellName)
		elseif optionKeyToID(rec.optionKey) then
			setRecordLabel(rec, optionKeyToID(rec.optionKey))
		elseif optionKeyToID(key) then
			setRecordLabel(rec, optionKeyToID(key))
		end
	end
end

local function copyBarData(rec, bar)
	if not rec or type(bar) ~= "table" then return end

	if bar.GetLabel then
		local label = bar:GetLabel()
		if label ~= nil then
			setRecordLabel(rec, label)
		end
	end

	if bar.GetIcon then
		local icon = bar:GetIcon()
		if icon ~= nil then
			setRecordIcon(rec, icon)
		end
	end

	if type(bar.remaining) == "number" and not isSecretValue(bar.remaining) then
		rec.remaining = bar.remaining
		if rec.duration then
			rec.startTime = nowTime() - math.max(rec.duration - rec.remaining, 0)
		end
	end

	if bar.Get then
		local module = bar:Get("bigwigs:module")
		if module ~= nil and not isSecretValue(module) then
			rec.moduleKey = normalizeModuleKey(module)
			rec.moduleRef = module
			if type(module) == "table" then
				local moduleName = module.name or module.moduleName
				if type(moduleName) == "string" and moduleName ~= "" then
					rec.moduleColorName = moduleName
				end
			elseif type(module) == "string" and module ~= "" then
				rec.moduleColorName = module
			end
		end
		local optionKey = bar:Get("bigwigs:option")
		if optionKey ~= nil then
			rec.optionKey = normalizeOptionKey(optionKey) or optionKey
			rec.spellID = parseSpellID(optionKey) or parseSpellID(rec.optionKey) or rec.spellID
			if type(rec.spellID) == "number" then
				rec.spellName = getSpellNameByID(rec.spellID) or rec.spellName
				if rec.icon == nil then
					setRecordIcon(rec, getSpellIconByID(rec.spellID))
				end
			end
		end
			local eventID = bar:Get("bigwigs:eventId")
			if eventID ~= nil then
				applyTimelineEventInfo(rec, eventID)
			end
		end

	local optionID, optionName, optionIcon = getBigWigsOptionDetails(rec.moduleRef, rec.optionKey)
	rec.spellID = parseSpellID(optionID) or rec.spellID
	if type(rec.spellID) == "number" and rec.spellName == nil then
		rec.spellName = getSpellNameByID(rec.spellID) or rec.spellName
	end
	if rec.icon == nil and optionIcon ~= nil then
		setRecordIcon(rec, optionIcon)
	end
	if rec.label == nil or (not isSecretValue(rec.label) and rec.label == "") then
		if optionName ~= nil then
			setRecordLabel(rec, optionName)
		end
	end

	local sb = bar.candyBarBar
	if sb and sb.GetStatusBarColor then
		local r, g, b, a = sb:GetStatusBarColor()
		if type(r) == "number" and type(g) == "number" and type(b) == "number" then
			rec.barColor = {
				r = r,
				g = g,
				b = b,
				a = tonumber(a) or 1,
			}
		end
	end
	if sb and sb.GetMinMaxValues then
		local _, maxValue = sb:GetMinMaxValues()
		maxValue = safeNumber(maxValue)
		if maxValue and maxValue > 0 then
			rec.duration = maxValue
		end
	end

	rec.configuredColor = getConfiguredBigWigsBarColor(rec) or rec.configuredColor
end

local connector = {
	id = "bigwigs",
	label = "BigWigs",
}

function connector:IsAvailable()
	if not BigWigsLoader then
		return false, "BigWigs is not loaded"
	end
	if type(BigWigsLoader.RegisterMessage) ~= "function" then
		return false, "BigWigs API unavailable"
	end
	return true
end

function connector:Activate()
	local available = select(1, self:IsAvailable())
	if not available then
		return false, "BigWigs is not loaded"
	end

	if not self._registered then
		BigWigsLoader.RegisterMessage(self, "BigWigs_StartBar", "OnBWStartBar")
		BigWigsLoader.RegisterMessage(self, "BigWigs_StopBar", "OnBWStopBar")
		BigWigsLoader.RegisterMessage(self, "BigWigs_PauseBar", "OnBWPauseBar")
		BigWigsLoader.RegisterMessage(self, "BigWigs_ResumeBar", "OnBWResumeBar")
		BigWigsLoader.RegisterMessage(self, "BigWigs_StopBars", "OnBWStopBars")
		BigWigsLoader.RegisterMessage(self, "BigWigs_BarCreated", "OnBWBarCreated")
		BigWigsLoader.RegisterMessage(self, "BigWigs_BarEmphasized", "OnBWBarEmphasized")
		self._registered = true
	end

	local candy = LibStub and LibStub("LibCandyBar-3.0", true)
	if candy and type(candy.RegisterCallback) == "function" and not self._candyRegistered then
		candy.RegisterCallback(self, "LibCandyBar_Stop", "OnCandyBarStop")
		self._candyRegistered = true
	end

	return true
end

function connector:Deactivate()
	if BigWigsLoader and type(BigWigsLoader.UnregisterMessage) == "function" and self._registered then
		pcall(BigWigsLoader.UnregisterMessage, self, "BigWigs_StartBar")
		pcall(BigWigsLoader.UnregisterMessage, self, "BigWigs_StopBar")
		pcall(BigWigsLoader.UnregisterMessage, self, "BigWigs_PauseBar")
		pcall(BigWigsLoader.UnregisterMessage, self, "BigWigs_ResumeBar")
		pcall(BigWigsLoader.UnregisterMessage, self, "BigWigs_StopBars")
		pcall(BigWigsLoader.UnregisterMessage, self, "BigWigs_BarCreated")
		pcall(BigWigsLoader.UnregisterMessage, self, "BigWigs_BarEmphasized")
	end

	local candy = LibStub and LibStub("LibCandyBar-3.0", true)
	if candy and type(candy.UnregisterCallback) == "function" and self._candyRegistered then
		pcall(candy.UnregisterCallback, candy, self, "LibCandyBar_Stop")
	end

	self._registered = nil
	self._candyRegistered = nil
	hideNativeBars = false
	applyNativeBarsHiddenState()
	wipe(records)
	wipe(barToRecord)
	wipe(trackedBars)
	wipe(barOriginalAlpha)
end

function connector:OnBWStartBar(_, module, key, text, time, icon, isApproximate, maxTime, eventID)
	if not isBossModule(module) then
		return
	end
	local id = findRecordID(module, text, eventID, key)
	local rec = getRecord(id)
	updateFromStartData(rec, module, key, text, time, icon, isApproximate, maxTime, eventID)
end

function connector:OnBWStopBar(_, module, text, eventID)
	if not isBossModule(module) then
		return
	end
	local id = findRecordID(module, text, eventID, nil)
	removeRecord(id)
end

function connector:OnBWPauseBar(_, module, text, eventID)
	if not isBossModule(module) then
		return
	end
	local id = findRecordID(module, text, eventID, nil)
	local rec = records[id]
	if not rec then return end
	if not rec.paused and rec.duration and rec.startTime then
		rec.remaining = math.max(rec.duration - (nowTime() - rec.startTime), 0)
	end
	rec.paused = true
end

function connector:OnBWResumeBar(_, module, text, eventID)
	if not isBossModule(module) then
		return
	end
	local id = findRecordID(module, text, eventID, nil)
	local rec = records[id]
	if not rec then return end
	rec.paused = false
	if rec.duration and rec.remaining then
		rec.startTime = nowTime() - (rec.duration - rec.remaining)
	end
end

function connector:OnBWStopBars(_, module)
	if not isBossModule(module) then
		return
	end
	local moduleKey = normalizeModuleKey(module)
	local remove = {}
	for id, rec in pairs(records) do
		if rec.moduleKey == moduleKey then
			remove[#remove + 1] = id
		end
	end
	for i = 1, #remove do
		removeRecord(remove[i])
	end
end

function connector:OnBWBarCreated(_, _, bar, module, key, text, time, icon, isApproximate)
	if type(bar) ~= "table" then return end
	trackBarFrame(bar)
	if not isBossModule(module) then
		return
	end
	local eventID = bar.Get and bar:Get("bigwigs:eventId") or nil
	local id = findRecordID(module, text, eventID, key)
	local rec = getRecord(id)
	updateFromStartData(rec, module, key, text, time, icon, isApproximate, nil, eventID)
	copyBarData(rec, bar)
	rec.barRef = bar
	barToRecord[bar] = id
end

function connector:OnBWBarEmphasized(_, _, bar)
	if type(bar) ~= "table" then return end
	trackBarFrame(bar)
	local id = barToRecord[bar]
	if not id then
		local module = bar.Get and bar:Get("bigwigs:module") or nil
		if not isBossModule(module) then
			return
		end
		local key = bar.Get and bar:Get("bigwigs:option") or nil
		local text = bar.GetLabel and bar:GetLabel() or nil
		local eventID = bar.Get and bar:Get("bigwigs:eventId") or nil
		id = findRecordID(module, text, eventID, key)
		barToRecord[bar] = id
	end
	local rec = getRecord(id)
	copyBarData(rec, bar)
	rec.barRef = bar
end

function connector:SetNativeBarsHidden(hidden)
	hideNativeBars = hidden and true or false
	applyNativeBarsHiddenState()
end

function M:SetBigWigsNativeBarsHidden(hidden)
	connector:SetNativeBarsHidden(hidden)
end

function connector:OnCandyBarStop(_, bar)
	if type(bar) ~= "table" then return end
	local id = barToRecord[bar]
	if not id then return end
	local rec = records[id]
	if rec then
		rec.barRef = nil
	end
	removeRecord(id)
	barToRecord[bar] = nil
	trackedBars[bar] = nil
	barOriginalAlpha[bar] = nil
end

function connector:CollectEvents(_, now)
	now = now or nowTime()
	local events = {}
	local remove = nil
	local doneThreshold = 0.05

	for id, rec in pairs(records) do
		rec.configuredColor = getConfiguredBigWigsBarColor(rec) or rec.configuredColor

		local remaining = safeNumber(rec.remaining)
		local bar = rec.barRef
		if type(bar) == "table" then
			local barRemaining = safeNumber(bar.remaining)
			if barRemaining ~= nil then
				remaining = barRemaining
				rec.remaining = remaining
			end
			rec.paused = (type(bar.paused) == "number")
		elseif not rec.paused and rec.duration and rec.startTime then
			remaining = math.max(rec.duration - (now - rec.startTime), 0)
			rec.remaining = remaining
		end

		if type(remaining) == "number" and remaining <= doneThreshold and not rec.keep then
			remove = remove or {}
			remove[#remove + 1] = id
		else
			local label = rec.spellName or rec.label
			if (not isSecretValue(label)) and label == "" then
				label = getSpellNameByID(rec.spellID) or label
			end
			if (not isSecretValue(label)) and label == "" and rec.optionKey ~= nil and not isSecretValue(rec.optionKey) then
				label = tostring(rec.optionKey)
			end
			if (not isSecretValue(label)) and label == "" then
				local fallbackID = rec.eventID or rec.id
				if fallbackID ~= nil and not isSecretValue(fallbackID) then
					label = tostring(fallbackID)
				end
			end
			local pickedColor = rec.configuredColor or rec.barColor
			local displayName = nil
			if isSecretValue(label) then
				displayName = label
			elseif type(label) == "string" and label ~= "" then
				displayName = label
			else
				displayName = "BigWigs Timer"
			end
			events[#events + 1] = {
				id = id,
				eventInfo = {
					name = displayName,
					icon = rec.icon,
					spellID = rec.spellID,
					icons = rec.icons,
					timelineEventID = rec.timelineEventID,
					isApproximate = rec.isApproximate and true or false,
					color = pickedColor,
					colorFrom = pickedColor,
					colorTo = pickedColor,
				},
				remaining = remaining,
				isPaused = rec.paused and true or false,
				isBlocked = false,
				isQueued = false,
			}
		end
	end

	if remove then
		for _, id in ipairs(remove) do
			removeRecord(id)
		end
	end

	return events
end

M:RegisterConnector(connector)
