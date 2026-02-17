-- SimpleBossMods test mode helpers.

local ADDON_NAME = ...
local M = _G[ADDON_NAME]
if not M then return end

local C = M.Const
local L = M.Live

local function canUseTimelineEditModeEvents()
	return C_EncounterTimeline
		and type(C_EncounterTimeline.AddEditModeEvents) == "function"
		and type(C_EncounterTimeline.CancelEditModeEvents) == "function"
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

function M:StopTest()
	self._testActive = nil
	self._testSourceConnectorID = nil
	
	if self._testCombatTimer then
		self._testCombatTimer = nil
		if self.UpdateCombatTimerState then
			self:UpdateCombatTimerState()
		elseif self.StopCombatTimer then
			self:StopCombatTimer()
		end
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
	self._testActive = true
	
	if self.ShowTestPrivateAura then
		self:ShowTestPrivateAura(true)
	end
	
	if L.COMBAT_TIMER_ENABLED and self.StartCombatTimer then
		self._testCombatTimer = true
		self:StartCombatTimer(true)
	end

	if self.StartEditModeTimelineTest then
		if self:StartEditModeTimelineTest() then
			self._testSourceConnectorID = "timeline"
			return
		end
	end
	
	-- Fallback if not supported? The requirements say "Strictly use the native API".
	-- So if it fails, we just stop.
	self:StopTest()
end
