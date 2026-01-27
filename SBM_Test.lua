-- SimpleBossMods test mode helpers.

local ADDON_NAME = ...
local M = _G[ADDON_NAME]
if not M then return end

local C = M.Const
local L = M.Live

-- =========================
-- Test mode (single run)
-- =========================
local TEST_ICONS = {
	-- spellId, duration (shortest first so A fires first)
	{ spellId = 116,  dur = 4.0,  label = "Test A" }, -- Frostbolt
	{ spellId = 133,  dur = 6.0,  label = "Test B" }, -- Fireball
	{ spellId = 172,  dur = 8.0,  label = "Test C" }, -- Corruption
	{ spellId = 589,  dur = 10.0, label = "Test D" }, -- Shadow Word: Pain
	{ spellId = 774,  dur = 12.0, label = "Test E" }, -- Rejuvenation
	{ spellId = 17,   dur = 14.0, label = "Test F" }, -- Power Word: Shield
	{ spellId = 2061, dur = 16.0, label = "Test G" }, -- Flash Heal
	{ spellId = 403,  dur = 18.0, label = "Test H" }, -- Lightning Bolt
}

-- Fake indicator icons for test (not secure/API-driven)
local TEST_INDICATOR_COUNT = 3
local TEST_INDICATOR_ICONS = {
	135860, -- bleed
	136116, -- poison
	136007, -- magic
}

local function canUseTimelineScriptEvents()
	return M.CanUseTimelineScriptEvents and M:CanUseTimelineScriptEvents()
end

local function canUseTimelineEditModeEvents()
	return C_EncounterTimeline
		and type(C_EncounterTimeline.AddEditModeEvents) == "function"
		and type(C_EncounterTimeline.CancelEditModeEvents) == "function"
end

local function getSpellIcon(spellId)
	if not spellId then return nil end
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(spellId)
		if info then return info.iconID end
	elseif GetSpellInfo then
		local _, _, iconTex = GetSpellInfo(spellId)
		return iconTex
	end
	return nil
end

function M:ClearTestTimelineEvents()
	if not (C_EncounterTimeline and type(C_EncounterTimeline.RemoveScriptEvent) == "function") then
		self._testTimelineEventIDs = nil
		self._testTimelineEventIDSet = nil
		return
	end
	if not self._testTimelineEventIDs then return end
	for _, id in pairs(self._testTimelineEventIDs) do
		if id then
			pcall(C_EncounterTimeline.RemoveScriptEvent, id)
		end
	end
	self._testTimelineEventIDs = nil
	self._testTimelineEventIDSet = nil
end

function M:ClearEditModeTimelineEvents()
	if self._testEditModeEventTimer then
		self._testEditModeEventTimer:Cancel()
		self._testEditModeEventTimer = nil
	end
	if C_EncounterTimeline and C_EncounterTimeline.CancelEditModeEvents then
		pcall(C_EncounterTimeline.CancelEditModeEvents)
	end
end

function M:StartEditModeTimelineTest()
	if not canUseTimelineEditModeEvents() then return false end

	if self._testEditModeEventTimer then
		self._testEditModeEventTimer:Cancel()
		self._testEditModeEventTimer = nil
	end

	local function queueEditModeEvents()
		local ok, loopTimerDuration = pcall(C_EncounterTimeline.AddEditModeEvents)
		if not ok then
			return
		end
		loopTimerDuration = tonumber(loopTimerDuration) or 0
		if loopTimerDuration <= 0 then
			loopTimerDuration = 2.0
		end
		self._testEditModeEventTimer = C_Timer.NewTimer(loopTimerDuration, queueEditModeEvents)
	end

	queueEditModeEvents()
	C_Timer.After(0, function() M:Tick() end)
	return true
end

function M:PushTestTimelineEvents()
	if not (C_EncounterTimeline and type(C_EncounterTimeline.AddScriptEvent) == "function") then
		return false
	end

	self._testTimelineEventIDs = {}
	self._testTimelineEventIDSet = {}
	for i, t in ipairs(TEST_ICONS) do
		local iconFileID = t.icon or getSpellIcon(t.spellId) or 134400
		local payload = {
			duration = t.dur,
			spellID = t.spellId or 116,
			overrideName = t.label,
			iconFileID = iconFileID,
			maxQueueDuration = 0,
		}
		local id = M.SafeAddScriptEvent and M:SafeAddScriptEvent(payload) or nil
		self._testTimelineEventIDs[i] = id
		if id then self._testTimelineEventIDSet[id] = true end
	end

	return next(self._testTimelineEventIDSet) ~= nil
end

local function applyTestIndicators(frame, isIcon)
	local target = isIcon and frame.indicatorsFrame or frame.endIndicatorsFrame
	if not target then return end
	local textures = M.ensureIndicatorTextures(target, C.INDICATOR_MAX)

	for i = 1, C.INDICATOR_MAX do
		local tex = textures[i]
		if i <= TEST_INDICATOR_COUNT then
			tex:Show()
			tex:SetTexture(TEST_INDICATOR_ICONS[i] or nil)
			tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		else
			tex:Hide()
		end
	end

	if isIcon then
		M.layoutIconIndicators(frame, textures)
	else
		M.layoutBarIndicators(frame, textures)
		if frame.endIndicatorsFrame then
			local size = M.Util.barIndicatorSize()
			local gap = 3
			local totalW = TEST_INDICATOR_COUNT * size + (TEST_INDICATOR_COUNT - 1) * gap
			frame.endIndicatorsFrame:SetWidth(totalW)
		end
	end
end

function M:ApplyTestIndicators(frame, isIcon)
	applyTestIndicators(frame, isIcon)
end

function M:StopTest()
	if self._testTicker then
		self._testTicker:Cancel()
		self._testTicker = nil
	end
	if self._testCombatTimer then
		self._testCombatTimer = nil
		if self.UpdateCombatTimerState then
			self:UpdateCombatTimerState()
		elseif self.StopCombatTimer then
			self:StopCombatTimer()
		end
	end
	if self.ClearTestTimelineEvents then
		self:ClearTestTimelineEvents()
	end
	if self.ClearEditModeTimelineEvents then
		self:ClearEditModeTimelineEvents()
	end
	if self.ShowTestPrivateAura then
		self:ShowTestPrivateAura(false)
	end
	self:clearAll()
end

function M:StartTest()
	self:StopTest()
	if self.ShowTestPrivateAura then
		self:ShowTestPrivateAura(true)
	end
	if L.COMBAT_TIMER_ENABLED and self.StartCombatTimer then
		self._testCombatTimer = true
		self:StartCombatTimer(true)
	end

	if self.StartEditModeTimelineTest then
		if self:StartEditModeTimelineTest() then
			return
		end
	end

	if canUseTimelineScriptEvents() and self.PushTestTimelineEvents then
		if self:PushTestTimelineEvents() then
			C_Timer.After(0, function() M:Tick() end)
			return
		end
	end

	local base = (math.floor(GetTime() * 1000) % 1000000) + 9100000
	local pool = {}

	for i, t in ipairs(TEST_ICONS) do
		pool[i] = {
			id = base + i,
			spellId = t.spellId,
			dur = t.dur,
			label = t.label,
			remaining = t.dur,
		}
	end

	local start = GetTime()

	-- Seed events
	for _, t in ipairs(pool) do
		local info = { name = t.label, spellID = t.spellId }
		self:updateRecord(t.id, info, t.remaining)
		local rec = self.events[t.id]
		if rec then rec.isTest = true end
	end
	self:LayoutAll()

	self._testTicker = C_Timer.NewTicker(0.05, function()
		local now = GetTime()
		local elapsed = now - start
		local anyActive = false

		for _, t in ipairs(pool) do
			local rem = t.dur - elapsed
			if rem < 0 then rem = 0 end
			t.remaining = rem

			local rec = M.events[t.id]
			if not rec then
				M.events[t.id] = { id = t.id }
				rec = M.events[t.id]
			end
			rec.isTest = true
			rec.eventInfo = { name = t.label, spellID = t.spellId }
			rec.remaining = rem

			if rem > 0 then
				M._updateRecTiming(rec, rem)
				anyActive = true

				if rem <= L.THRESHOLD_TO_BAR then
					M:ensureBar(rec)
				else
					M:ensureIcon(rec)
				end

				-- Test indicators (fixed 3 icons)
				if rec.iconFrame then
					M:ApplyTestIndicators(rec.iconFrame, true)
				end
				if rec.barFrame then
					M:ApplyTestIndicators(rec.barFrame, false)
				end
			else
				M:removeEvent(t.id)
			end
		end

		M:LayoutAll()

		if not anyActive then
			self._testTicker:Cancel()
			self._testTicker = nil
			if M.ShowTestPrivateAura then
				M:ShowTestPrivateAura(false)
			end
			if M._testCombatTimer then
				M._testCombatTimer = nil
				if M.UpdateCombatTimerState then
					M:UpdateCombatTimerState()
				elseif M.StopCombatTimer then
					M:StopCombatTimer()
				end
			end
		end
	end)
end
