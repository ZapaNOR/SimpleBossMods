-- SimpleBossMods events and slash commands.

local ADDON_NAME = ...
local M = _G[ADDON_NAME]
if not M then return end
local C = M.Const
local L = M.Live

local MANUAL_TIMER_IDS = {
	pull = 9101001,
	["break"] = 9101002,
}

local function trim(s)
	s = tostring(s or "")
	s = s:gsub("^%s+", "")
	s = s:gsub("%s+$", "")
	return s
end

local function getServerTimeSafe()
	if GetServerTime then return GetServerTime() end
	if time then return time() end
	return nil
end

local function parseTimerValue(value)
	if type(value) == "number" then return value end
	if type(value) ~= "string" then return nil end
	local v = value:match("^%s*(.-)%s*$")
	if v == "" then return nil end
	local n = tonumber(v)
	if n then return n end
	local m, s = v:match("^(%d+):(%d+)$")
	if not m then return nil end
	return (tonumber(m) or 0) * 60 + (tonumber(s) or 0)
end

local function shouldAutoSlotKeystone()
	if not L.AUTO_INSERT_KEYSTONE then return false end
	if not (C_ChallengeMode and C_ChallengeMode.SlotKeystone) then return false end
	return true
end

local function getContainerAPIs()
	if C_Container and C_Container.GetContainerNumSlots then
		return C_Container.GetContainerNumSlots, C_Container.GetContainerItemLink, C_Container.PickupContainerItem
	end
	if GetContainerNumSlots and GetContainerItemLink and PickupContainerItem then
		return GetContainerNumSlots, GetContainerItemLink, PickupContainerItem
	end
	return nil, nil, nil
end

local function autoSlotKeystone()
	if not shouldAutoSlotKeystone() then return end
	if GetTime then
		local now = GetTime()
		if M._keystoneAutoSlotAt and (now - M._keystoneAutoSlotAt) < 0.5 then
			return
		end
		M._keystoneAutoSlotAt = now
	end

	local GetContainerNumSlots, GetContainerItemLink, PickupContainerItem = getContainerAPIs()
	if not GetContainerNumSlots then return end

	for bag = 0, 4 do
		local slots = GetContainerNumSlots(bag) or 0
		for slot = 1, slots do
			local itemLink = GetContainerItemLink(bag, slot)
			if itemLink and itemLink:find("Hkeystone", nil, true) then
				if not (C_ChallengeMode.HasSlottedKeystone and C_ChallengeMode.HasSlottedKeystone()) then
					PickupContainerItem(bag, slot)
					pcall(C_ChallengeMode.SlotKeystone)
				end
				return
			end
		end
	end
end

local function setupKeystoneAutoInsert()
	if M._keystoneHooked then return end
	if not (C_ChallengeMode and C_ChallengeMode.SlotKeystone) then return end
	local frame = _G.ChallengesKeystoneFrame
	if not frame then
		if C_Timer and C_Timer.After then
			M._keystoneHookRetry = (M._keystoneHookRetry or 0) + 1
			if M._keystoneHookRetry <= 10 then
				C_Timer.After(0.5, setupKeystoneAutoInsert)
			end
		end
		return
	end

	if not M._keystoneEventFrame then
		local kef = CreateFrame("Frame")
		kef:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
		kef:SetScript("OnEvent", function()
			autoSlotKeystone()
		end)
		M._keystoneEventFrame = kef
	end

	frame:HookScript("OnShow", function()
		autoSlotKeystone()
	end)

	M._keystoneHooked = true
	M._keystoneHookRetry = nil
	if frame:IsShown() then
		autoSlotKeystone()
	end
end

M.SetupKeystoneAutoInsert = setupKeystoneAutoInsert

local function isSenderMe(sender)
	if not sender then return false end
	local name, realm = UnitFullName and UnitFullName("player") or UnitName("player")
	if not name then return false end
	if type(realm) == "string" and realm ~= "" then
		if sender == (name .. "-" .. realm) then return true end
	end
	if sender == name then return true end
	if Ambiguate and Ambiguate(sender, "none") == name then return true end
	return false
end

local function canSendAddonMessage()
	if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
	if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return false end
	return true
end

local function getAddonMessageChannel()
	if IsInGroup and IsInGroup(2) and IsInInstance and IsInInstance() then
		return "INSTANCE_CHAT"
	end
	if IsInRaid and IsInRaid() then
		return "RAID"
	end
	if IsInGroup and IsInGroup(1) then
		return "PARTY"
	end
	return nil
end

local function sendDbmBreakSync(seconds)
	if not canSendAddonMessage() then return end
	local channel = getAddonMessageChannel()
	if not channel then return end
	local secs = math.floor((tonumber(seconds) or 0) + 0.5)
	if secs < 0 or secs > 3600 then return end
	C_ChatInfo.SendAddonMessage("D5", "SBM\t1\tBT\t" .. tostring(secs), channel)
end

local function sendBigWigsBreakSync(seconds)
	if not canSendAddonMessage() then return end
	local channel = getAddonMessageChannel()
	if not channel then return end
	local secs = math.floor((tonumber(seconds) or 0) + 0.5)
	if secs < 0 then return end
	C_ChatInfo.SendAddonMessage("BigWigs", "B^" .. tostring(secs), channel)
end

local function getManualTimersStore()
	if not SimpleBossModsDB then return nil end
	if type(SimpleBossModsDB.manualTimers) ~= "table" then
		SimpleBossModsDB.manualTimers = {}
	end
	return SimpleBossModsDB.manualTimers
end

local function buildManualTimerEventInfo(kind)
	local icon = (M.GetManualTimerIcon and M:GetManualTimerIcon(kind))
		or ((kind == "pull") and C.PULL_ICON or C.BREAK_ICON)
	return {
		name = (kind == "pull") and (C.PULL_LABEL or "Pull") or (C.BREAK_LABEL or "Break"),
		icon = icon,
	}
end

local function setCVarBool(name, enabled)
	if not name then return end
	local value = enabled and "1" or "0"
	if C_CVar and C_CVar.GetCVar and C_CVar.SetCVar then
		local ok, current = pcall(C_CVar.GetCVar, name)
		if ok and tostring(current) == value then return end
		pcall(C_CVar.SetCVar, name, value)
	elseif SetCVar then
		pcall(SetCVar, name, value)
	end
end

local function trySetEncounterTimelineViewBars()
	if not (EditModeManagerFrame and EditModeManagerFrame.IsInitialized and EditModeManagerFrame:IsInitialized()) then
		return false
	end
	if not (Enum and Enum.EditModeSystem and Enum.EditModeEncounterEventsSystemIndices and Enum.EditModeEncounterEventsSetting and Enum.EncounterEventsViewType) then
		return false
	end
	local systemFrame = EditModeManagerFrame:GetRegisteredSystemFrame(
		Enum.EditModeSystem.EncounterEvents,
		Enum.EditModeEncounterEventsSystemIndices.Timeline
	)
	if not systemFrame then return false end
	EditModeManagerFrame:OnSystemSettingChange(systemFrame, Enum.EditModeEncounterEventsSetting.ViewType, Enum.EncounterEventsViewType.Bars)
	return true
end

local function ensureBlizzardTimelineSettings()
	-- Ensure timeline feature is enabled via CVars.
	setCVarBool("combatWarningsEnabled", true)
	setCVarBool("encounterTimelineEnabled", true)

	-- Ensure the Encounter Timeline view type is set to Bars in Edit Mode settings.
	if trySetEncounterTimelineViewBars() then
		M._timelineSettingsRetries = nil
		return
	end

	M._timelineSettingsRetries = (M._timelineSettingsRetries or 0) + 1
	if M._timelineSettingsRetries <= 10 and C_Timer and C_Timer.After then
		C_Timer.After(0.5, ensureBlizzardTimelineSettings)
	end
end

local function isTimelineConnectorActive()
	return M.GetActiveConnectorID and M:GetActiveConnectorID() == "timeline"
end

local function getUseRecommendedTimelineSettings()
	local cfg = SimpleBossModsDB and SimpleBossModsDB.cfg
	local connectors = cfg and cfg.connectors
	if type(connectors) ~= "table" then
		return true
	end
	return connectors.useRecommendedSettings ~= false
end

local function getDisableBlizzardTimelineSetting()
	local cfg = SimpleBossModsDB and SimpleBossModsDB.cfg
	local connectors = cfg and cfg.connectors
	if type(connectors) ~= "table" then
		return false
	end
	return connectors.disableBlizzardTimeline == true
end

local function getCVarBool(name)
	if not name then return nil end
	if C_CVar and C_CVar.GetCVar then
		local ok, value = pcall(C_CVar.GetCVar, name)
		if ok and value ~= nil then
			value = tostring(value)
			return value == "1" or value == "true"
		end
	end
	if GetCVar then
		local ok, value = pcall(GetCVar, name)
		if ok and value ~= nil then
			value = tostring(value)
			return value == "1" or value == "true"
		end
	end
	return nil
end

local function hideBlizzardEncounterTimeline()
	local frame = _G.EncounterTimeline
	if not frame then return end
	if not frame._sbmHideHooked then
		frame._sbmHideHooked = true
		frame:HookScript("OnShow", function(self)
			if isTimelineConnectorActive() and getUseRecommendedTimelineSettings() then
				self:Hide()
			end
		end)
	end
	if frame:IsShown() and isTimelineConnectorActive() and getUseRecommendedTimelineSettings() then
		frame:Hide()
	end
end

local function applyTimelineConnectorMode()
	if not isTimelineConnectorActive() then
		return
	end
	if not getUseRecommendedTimelineSettings() then
		return
	end
	ensureBlizzardTimelineSettings()
	hideBlizzardEncounterTimeline()
end

local function applyConnectorTimelineState(connectorID)
	connectorID = connectorID or (M.GetActiveConnectorID and M:GetActiveConnectorID()) or "timeline"
	local isExternalConnector = connectorID == "bigwigs" or connectorID == "dbm"
	local shouldDisable = isExternalConnector and getDisableBlizzardTimelineSetting()

	if shouldDisable then
		if not M._sbmTimelineCVarControlled then
			M._sbmTimelineCVarOriginal = {
				encounterTimelineEnabled = getCVarBool("encounterTimelineEnabled"),
			}
		end
		M._sbmTimelineCVarControlled = true
		setCVarBool("encounterTimelineEnabled", false)
	elseif M._sbmTimelineCVarControlled then
		local original = M._sbmTimelineCVarOriginal
		if type(original) == "table" then
			if original.encounterTimelineEnabled ~= nil then
				setCVarBool("encounterTimelineEnabled", original.encounterTimelineEnabled and true or false)
			end
		end
		M._sbmTimelineCVarControlled = nil
		M._sbmTimelineCVarOriginal = nil
	end
end

local function getHideBigWigsBarsSetting()
	local cfg = SimpleBossModsDB and SimpleBossModsDB.cfg
	local connectors = cfg and cfg.connectors
	if type(connectors) ~= "table" then
		return true
	end
	return connectors.hideBigWigsBars ~= false
end

local function getHideDBMBarsSetting()
	local cfg = SimpleBossModsDB and SimpleBossModsDB.cfg
	local connectors = cfg and cfg.connectors
	if type(connectors) ~= "table" then
		return true
	end
	return connectors.hideDBMBars ~= false
end

local function applyBigWigsConnectorBarVisibility(connectorID)
	connectorID = connectorID or (M.GetActiveConnectorID and M:GetActiveConnectorID()) or "timeline"
	if type(M.SetBigWigsNativeBarsHidden) ~= "function" then
		return
	end

	if connectorID == "bigwigs" then
		M._sbmBigWigsBarsControlled = true
		M:SetBigWigsNativeBarsHidden(getHideBigWigsBarsSetting())
	elseif M._sbmBigWigsBarsControlled then
		M:SetBigWigsNativeBarsHidden(false)
		M._sbmBigWigsBarsControlled = nil
	end
end

local function applyDBMConnectorBarVisibility(connectorID)
	if type(DBM) ~= "table" or type(DBM.Options) ~= "table" then
		return
	end

	local function pickVisibleAlpha(optionName, stored, hardDefault)
		local n = tonumber(stored)
		if n and n > 0 then
			return n
		end
		if type(DBT) == "table" and type(DBT.DefaultOptions) == "table" then
			n = tonumber(DBT.DefaultOptions[optionName])
			if n and n > 0 then
				return n
			end
		end
		return hardDefault
	end

	connectorID = connectorID or (M.GetActiveConnectorID and M:GetActiveConnectorID()) or "timeline"
	if connectorID == "dbm" then
		if M._sbmDBMHideBarsOriginal == nil then
			M._sbmDBMHideBarsOriginal = DBM.Options.HideDBMBars and true or false
		end
		M._sbmDBMHideBarsControlled = true
		-- DBM stops creating timer bars/events when HideDBMBars is true, which breaks SBM ingestion.
		-- Keep DBM timer creation enabled and hide DBM bars visually via DBT alpha instead.
		if DBM.Options.HideDBMBars then
			DBM.Options.HideDBMBars = false
		end
		if type(DBT) == "table" and type(DBT.Options) == "table" then
			local opts = DBT.Options
			if M._sbmDBTAlphaOriginal == nil then
				local originalAlpha = tonumber(opts.Alpha)
				if not originalAlpha or originalAlpha <= 0 then
					originalAlpha = pickVisibleAlpha("Alpha", nil, 0.8)
				end
				M._sbmDBTAlphaOriginal = originalAlpha
			end
			if M._sbmDBTHugeAlphaOriginal == nil then
				local originalHugeAlpha = tonumber(opts.HugeAlpha)
				if not originalHugeAlpha or originalHugeAlpha <= 0 then
					originalHugeAlpha = pickVisibleAlpha("HugeAlpha", nil, 1)
				end
				M._sbmDBTHugeAlphaOriginal = originalHugeAlpha
			end

			local shouldHide = getHideDBMBarsSetting() and true or false
			if shouldHide then
				opts.Alpha = 0
				opts.HugeAlpha = 0
			else
				opts.Alpha = pickVisibleAlpha("Alpha", M._sbmDBTAlphaOriginal, 0.8)
				opts.HugeAlpha = pickVisibleAlpha("HugeAlpha", M._sbmDBTHugeAlphaOriginal, 1)
			end

			if type(DBT.UpdateBars) == "function" then
				pcall(DBT.UpdateBars, DBT, true)
			end
			if type(DBT.ApplyStyle) == "function" then
				pcall(DBT.ApplyStyle, DBT)
			end
		end
	elseif M._sbmDBMHideBarsControlled then
		if M._sbmDBMHideBarsOriginal ~= nil then
			DBM.Options.HideDBMBars = M._sbmDBMHideBarsOriginal and true or false
		end
		if type(DBT) == "table" and type(DBT.Options) == "table" then
			DBT.Options.Alpha = pickVisibleAlpha("Alpha", M._sbmDBTAlphaOriginal, 0.8)
			DBT.Options.HugeAlpha = pickVisibleAlpha("HugeAlpha", M._sbmDBTHugeAlphaOriginal, 1)
			if type(DBT.UpdateBars) == "function" then
				pcall(DBT.UpdateBars, DBT, true)
			end
			if type(DBT.ApplyStyle) == "function" then
				pcall(DBT.ApplyStyle, DBT)
			end
		end
		M._sbmDBMHideBarsControlled = nil
		M._sbmDBMHideBarsOriginal = nil
		M._sbmDBTAlphaOriginal = nil
		M._sbmDBTHugeAlphaOriginal = nil
	end
end

function M:ApplyBigWigsConnectorBarVisibility(connectorID)
	applyBigWigsConnectorBarVisibility(connectorID)
end

function M:ApplyDBMConnectorBarVisibility(connectorID)
	applyDBMConnectorBarVisibility(connectorID)
end

function M:ApplyTimelineConnectorMode()
	applyTimelineConnectorMode()
end

function M:ApplyConnectorTimelineState(connectorID)
	applyConnectorTimelineState(connectorID)
end

function M:OnActiveConnectorChanged(connectorID)
	applyConnectorTimelineState(connectorID)
	applyBigWigsConnectorBarVisibility(connectorID)
	applyDBMConnectorBarVisibility(connectorID)
	if connectorID == "timeline" then
		applyTimelineConnectorMode()
		if not (InCombatLockdown and InCombatLockdown()) then
			local now = (GetTime and GetTime()) or 0
			self._suppressTimelineUntil = now + 0.25
		end
	else
		self._suppressTimelineUntil = nil
	end
end

local function ensureManualTimerRecord(kind)
	local id = MANUAL_TIMER_IDS[kind]
	if not id then return nil end

	M.events = M.events or {}
	local rec = M.events[id]
	if not rec then
		rec = { id = id }
		M.events[id] = rec
	end

	rec.isManual = true
	rec.forceBar = true
	rec.kind = kind

	return rec, id
end

local function initManualTimer(kind, seconds, opts)
	local rec, id = ensureManualTimerRecord(kind)
	if not rec then return nil end

	local now = (opts and opts.now) or GetTime()
	rec.suppressCountdown = not not (opts and opts.suppressCountdown)
	rec.source = opts and opts.source or nil
	rec.eventInfo = buildManualTimerEventInfo(kind)

	rec.duration = seconds
	rec.startTime = (opts and opts.startTime) or now
	rec.endTime = (opts and opts.endTime) or (rec.startTime + seconds)
	rec.remaining = (opts and opts.remaining) or seconds

	return rec, id, now
end

local function persistManualTimer(kind, seconds, source, suppressCountdown)
	local nowServer = getServerTimeSafe()
	if not nowServer then return nil end
	M:SaveManualTimerState(kind, nowServer + seconds, seconds, {
		suppressCountdown = suppressCountdown,
		source = source,
	})
	return nowServer
end

function M:SaveManualTimerState(kind, endServerTime, duration, opts)
	local store = getManualTimersStore()
	if not store or not kind then return end
	if type(endServerTime) ~= "number" or endServerTime <= 0 then return end
	opts = opts or {}
	store[kind] = {
		endTime = endServerTime,
		duration = tonumber(duration) or 0,
		suppressCountdown = opts.suppressCountdown or false,
		source = opts.source,
	}
end

function M:ClearManualTimerState(kind)
	local store = getManualTimersStore()
	if not store or not kind then return end
	store[kind] = nil
end

local function cancelManualCountdown(rec)
	if not rec then return end
	if rec.countdownTimer and rec.countdownTimer.Cancel then
		rec.countdownTimer:Cancel()
	end
	rec.countdownTimer = nil
end

local function canStartCountdown()
	if not (C_PartyInfo and C_PartyInfo.DoCountdown) then return false end
	if C_PartyInfo.CanStartCountdown then
		return C_PartyInfo.CanStartCountdown()
	end
	return true
end

local function startCountdown(len)
	local secs = math.floor((tonumber(len) or 0) + 0.5)
	if secs <= 0 then return end
	if not canStartCountdown() then return end
	C_PartyInfo.DoCountdown(secs)
end

local function schedulePullCountdown(rec, seconds, endServerTime)
	cancelManualCountdown(rec)
	local secs = tonumber(seconds) or 0
	if secs <= 0 then return end
	if not canStartCountdown() then return end

	if endServerTime then
		local nowServer = getServerTimeSafe()
		if nowServer and nowServer >= endServerTime then
			return
		end
	end

	startCountdown(secs)
end

local function handleManualTimer(kind, msg)
	local raw = trim(msg):lower()
	if raw == "" then
		if kind == "pull" then
			M:StartManualTimer("pull", 10)
		else
			M:StartManualTimer("break", 5 * 60)
		end
		return
	end

	if raw == "stop" or raw == "cancel" or raw == "end" or raw == "0" then
		M:StopManualTimer(kind)
		return
	end

	local n = tonumber(raw)
	if not n then
		print(ADDON_NAME .. " usage: /" .. kind .. " <" .. (kind == "pull" and "sec" or "min") .. "> (or 0/stop)")
		return
	end
	if n <= 0 then
		M:StopManualTimer(kind)
		return
	end

	if kind == "pull" then
		M:StartManualTimer("pull", n)
	else
		M:StartManualTimer("break", n * 60)
	end
end

function M:StartManualTimer(kind, seconds)
	if type(seconds) ~= "number" or seconds <= 0 then return end
	if kind == "pull" then
		self:StopManualTimer("break")
	end

	local rec, id, now = initManualTimer(kind, seconds, { now = GetTime(), suppressCountdown = false })
	if not rec then return end

	local nowServer = persistManualTimer(kind, seconds, rec.source, rec.suppressCountdown)

	if kind == "pull" then
		rec.ignoreCountdownUntil = now + 1
		local endServer = nowServer and (nowServer + seconds) or nil
		schedulePullCountdown(rec, seconds, endServer)
	else
		cancelManualCountdown(rec)
		sendDbmBreakSync(seconds)
		sendBigWigsBreakSync(seconds)
	end

	self:updateRecord(id, rec.eventInfo, seconds)
	self:LayoutAll()
end

function M:StopManualTimer(kind, suppressBroadcast)
	local id = MANUAL_TIMER_IDS[kind]
	if not id then return end
	if self.events[id] then
		cancelManualCountdown(self.events[id])
		self:ClearManualTimerState(kind)
		self:removeEvent(id)
		self:LayoutAll()
	end
	if not suppressBroadcast and kind == "break" then
		sendDbmBreakSync(0)
		sendBigWigsBreakSync(0)
	end
end

function M:StartExternalManualTimer(kind, seconds, source, suppressCountdown)
	if type(seconds) ~= "number" or seconds <= 0 then return end
	if kind == "pull" then
		self:StopManualTimer("break")
	end

	local rec, id, now = initManualTimer(kind, seconds, {
		now = GetTime(),
		suppressCountdown = suppressCountdown,
		source = source,
	})
	if not rec then return end

	local nowServer = persistManualTimer(kind, seconds, rec.source, rec.suppressCountdown)

	if kind == "pull" then
		rec.ignoreCountdownUntil = now + 1
		if rec.suppressCountdown then
			cancelManualCountdown(rec)
		else
			local endServer = nowServer and (nowServer + seconds) or nil
			schedulePullCountdown(rec, seconds, endServer)
		end
	else
		cancelManualCountdown(rec)
	end

	self:updateRecord(id, rec.eventInfo, seconds)
	self:LayoutAll()
end

local function restoreManualTimer(kind, info)
	if type(info) ~= "table" then return end
	local nowServer = getServerTimeSafe()
	if not nowServer then return end
	local endServer = tonumber(info.endTime)
	local duration = tonumber(info.duration)
	local suppressCountdown = not not info.suppressCountdown
	if type(endServer) ~= "number" or type(duration) ~= "number" or duration <= 0 then return end
	local remaining = endServer - nowServer
	if remaining <= 0 then
		M:ClearManualTimerState(kind)
		return
	end
	if remaining > duration then
		remaining = duration
	end

	local now = GetTime()
	local rec, id = initManualTimer(kind, duration, {
		now = now,
		startTime = now - (duration - remaining),
		endTime = now + remaining,
		remaining = remaining,
		suppressCountdown = suppressCountdown,
		source = info.source,
	})
	if not rec then return end

	if kind == "pull" then
		rec.ignoreCountdownUntil = now + 1
		if rec.suppressCountdown then
			cancelManualCountdown(rec)
		else
			schedulePullCountdown(rec, remaining, endServer)
		end
	else
		cancelManualCountdown(rec)
	end

	M:updateRecord(id, rec.eventInfo, remaining)
	M:LayoutAll()
end

-- =========================
-- Events
-- =========================
local ef = CreateFrame("Frame")
ef:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		M:EnsureDefaults()
		M.SyncLiveConfig()
		if M.RefreshConnectorState then
			M:RefreshConnectorState({ skipClear = true })
		end
		applyConnectorTimelineState()
		applyTimelineConnectorMode()
		applyBigWigsConnectorBarVisibility()
		applyDBMConnectorBarVisibility()

		M:ApplyGeneralConfig(
			SimpleBossModsDB.cfg.general.gap or 6,
			SimpleBossModsDB.cfg.general.autoInsertKeystone
		)
		M:ApplyIconConfig(SimpleBossModsDB.cfg.icons.size, SimpleBossModsDB.cfg.icons.fontSize, SimpleBossModsDB.cfg.icons.borderThickness)
		M:ApplyBarConfig(SimpleBossModsDB.cfg.bars.width, SimpleBossModsDB.cfg.bars.height, SimpleBossModsDB.cfg.bars.fontSize, SimpleBossModsDB.cfg.bars.borderThickness)
		M:ApplyIndicatorConfig(SimpleBossModsDB.cfg.indicators.iconSize or 0, SimpleBossModsDB.cfg.indicators.barSize or 0)
		if M.UpdateIconsAnchorPosition then
			M:UpdateIconsAnchorPosition()
		end
		if M.UpdateBarsAnchorPosition then
			M:UpdateBarsAnchorPosition()
		end
		if M.ApplyPrivateAuraConfig then
			local pc = SimpleBossModsDB.cfg.privateAuras
			M:ApplyPrivateAuraConfig(pc.size, pc.gap, pc.growDirection, pc.x, pc.y)
		end
		if M.UpdateCombatTimerAppearance then
			M:UpdateCombatTimerAppearance()
		end
		if M.UpdateCombatTimerState then
			M:UpdateCombatTimerState()
		end

		M:CreateSettingsPanel()
		if isTimelineConnectorActive() and not (InCombatLockdown and InCombatLockdown()) then
			local now = (GetTime and GetTime()) or 0
			M._suppressTimelineUntil = now + 0.5
		end
		M:Tick()
		M:LayoutAll()
		if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
			C_ChatInfo.RegisterAddonMessagePrefix("D5")
			C_ChatInfo.RegisterAddonMessagePrefix("BigWigs")
		end
		if type(SimpleBossModsDB.manualTimers) == "table" then
			for kind, info in pairs(SimpleBossModsDB.manualTimers) do
				restoreManualTimer(kind, info)
			end
		end

		if type(hash_SlashCmdList) == "table" then
			if not hash_SlashCmdList["/pull"] then
				SLASH_SIMPLEBOSSMODSPULL1 = "/pull"
			end
			if not hash_SlashCmdList["/break"] then
				SLASH_SIMPLEBOSSMODSBREAK1 = "/break"
			end
		else
			SLASH_SIMPLEBOSSMODSPULL1 = "/pull"
			SLASH_SIMPLEBOSSMODSBREAK1 = "/break"
		end
	elseif event == "ADDON_LOADED" then
		local name = ...
		if M.RefreshConnectorState then
			M:RefreshConnectorState()
		end
		if name == "Blizzard_ChallengesUI" then
			if M.SetupKeystoneAutoInsert then
				M:SetupKeystoneAutoInsert()
			end
		elseif name == "Blizzard_EditMode" then
			applyTimelineConnectorMode()
		elseif name == "Blizzard_EncounterTimeline" then
			applyTimelineConnectorMode()
		elseif name == "Blizzard_EncounterEvents" then
			applyConnectorTimelineState()
		elseif name == "BigWigs" or name == "BigWigs_Core" or name == "BigWigs_Plugins" then
			applyConnectorTimelineState()
			applyBigWigsConnectorBarVisibility()
		elseif name == "DBM-Core" or name == "DBM-StatusBarTimers" then
			applyConnectorTimelineState()
			applyDBMConnectorBarVisibility()
		end
	elseif event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then
		if isTimelineConnectorActive() then
			C_Timer.After(0, function() M:Tick() end)
		end
	elseif event == "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED"
		or event == "ENCOUNTER_TIMELINE_EVENT_TRACK_CHANGED"
		or event == "ENCOUNTER_TIMELINE_EVENT_BLOCK_STATE_CHANGED" then
		if isTimelineConnectorActive() then
			C_Timer.After(0, function() M:Tick() end)
		end
	elseif event == "ENCOUNTER_TIMELINE_EVENT_REMOVED" then
		local eventID = ...
		if isTimelineConnectorActive() and type(eventID) == "number" then
			M:removeEvent(eventID)
		end
		if isTimelineConnectorActive() then
			C_Timer.After(0, function() M:Tick() end)
		end
	elseif event == "ENCOUNTER_TIMELINE_LAYOUT_UPDATED"
		or event == "ENCOUNTER_TIMELINE_STATE_UPDATED"
		or event == "ENCOUNTER_TIMELINE_VIEW_ACTIVATED" then
		if isTimelineConnectorActive() then
			C_Timer.After(0, function() M:Tick() end)
		end
	elseif event == "ENCOUNTER_TIMELINE_VIEW_DEACTIVATED" then
		if isTimelineConnectorActive() then
			if M.clearAll then
				M:clearAll()
			end
			if M.LayoutAll then
				M:LayoutAll()
			end
		end
	elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
		applyTimelineConnectorMode()
	elseif event == "PLAYER_REGEN_DISABLED" then
		if M.StartCombatTimer then
			M:StartCombatTimer(true)
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if M.StopCombatTimer then
			M:StopCombatTimer()
		end
	elseif event == "START_PLAYER_COUNTDOWN" then
		local _, timeSeconds = ...
		local secs = parseTimerValue(timeSeconds)
		if secs and secs > 0 then
			local rec = M.events and M.events[MANUAL_TIMER_IDS.pull] or nil
			if rec then
				if rec.ignoreCountdownUntil and GetTime() <= rec.ignoreCountdownUntil then
					return
				end
				local remaining = rec.endTime and (rec.endTime - GetTime()) or rec.remaining
				if type(remaining) == "number" and remaining >= (secs - 0.5) then
					return
				end
			end
			M:StartExternalManualTimer("pull", secs, "blizzard", true)
		end
	elseif event == "CANCEL_PLAYER_COUNTDOWN" then
		local rec = M.events and M.events[MANUAL_TIMER_IDS.pull] or nil
		if rec and rec.source == "blizzard" then
			M:StopManualTimer("pull", true)
		end
	elseif event == "CHAT_MSG_ADDON" then
		local prefix, msg, _, sender = ...
		if isSenderMe(sender) then
			return
		end
		if prefix == "D5" then
			local _, proto, syncPrefix, payload = strsplit("\t", msg or "")
			if tonumber(proto) then
				if syncPrefix == "PT" then
					local secs = parseTimerValue(payload)
					if secs ~= nil then
						if secs > 0 then
							if secs >= 3 then
								M:StartExternalManualTimer("pull", secs, "dbm", true)
							end
						else
							M:StopManualTimer("pull", true)
						end
					end
				elseif syncPrefix == "BT" then
					local secs = parseTimerValue(payload)
					if secs ~= nil then
						if secs > 0 then
							if secs <= 3600 then
								M:StartExternalManualTimer("break", secs, "dbm", true)
							end
						else
							M:StopManualTimer("break", true)
						end
					end
				end
			end
		elseif prefix == "BigWigs" then
			local bwPrefix, bwMsg, bwExtra = strsplit("^", msg or "")
			if bwPrefix then
				bwPrefix = bwPrefix:upper()
				if bwPrefix == "P" or bwPrefix == "PULL" or bwPrefix == "PT" then
					local secs = parseTimerValue(bwMsg)
					if secs ~= nil then
						if secs > 0 then
							M:StartExternalManualTimer("pull", secs, "bigwigs", true)
						else
							M:StopManualTimer("pull", true)
						end
					end
				elseif bwPrefix == "BT" or bwPrefix == "BR" or bwPrefix == "BREAK" then
					local secs = parseTimerValue(bwMsg)
					if secs ~= nil then
						if secs > 0 then
							M:StartExternalManualTimer("break", secs, "bigwigs", true)
						else
							M:StopManualTimer("break", true)
						end
					end
				elseif bwPrefix == "B" and bwMsg then
					local inner = bwMsg:upper()
					if inner == "P" or inner == "PULL" or inner == "PT" then
						local secs = parseTimerValue(bwExtra)
						if secs ~= nil then
							if secs > 0 then
								M:StartExternalManualTimer("pull", secs, "bigwigs", true)
							else
								M:StopManualTimer("pull", true)
							end
						end
					elseif inner == "B" or inner == "BR" or inner == "BREAK" or inner == "BT" then
						local secs = parseTimerValue(bwExtra)
						if secs ~= nil then
							if secs > 0 then
								M:StartExternalManualTimer("break", secs, "bigwigs", true)
							else
								M:StopManualTimer("break", true)
							end
						end
					end
				end
			end
		end
	elseif event == "UNIT_AURA" then
		local unit = ...
		if unit == "player" and M.UpdatePrivateAuraFrames then
			M:UpdatePrivateAuraFrames()
		end
	end
end)
ef:RegisterEvent("PLAYER_LOGIN")
ef:RegisterEvent("ADDON_LOADED")
ef:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
ef:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_REMOVED")
ef:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")
ef:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_TRACK_CHANGED")
ef:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_BLOCK_STATE_CHANGED")
ef:RegisterEvent("ENCOUNTER_TIMELINE_LAYOUT_UPDATED")
ef:RegisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED")
ef:RegisterEvent("ENCOUNTER_TIMELINE_VIEW_ACTIVATED")
ef:RegisterEvent("ENCOUNTER_TIMELINE_VIEW_DEACTIVATED")
ef:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
ef:RegisterEvent("PLAYER_REGEN_DISABLED")
ef:RegisterEvent("PLAYER_REGEN_ENABLED")
ef:RegisterEvent("START_PLAYER_COUNTDOWN")
ef:RegisterEvent("CANCEL_PLAYER_COUNTDOWN")
ef:RegisterEvent("CHAT_MSG_ADDON")
ef:RegisterEvent("UNIT_AURA")

-- =========================
-- Slash
-- =========================
SLASH_SIMPLEBOSSMODS1 = "/sbm"
SLASH_SIMPLEBOSSMODS2 = "/simplebossmods"
SlashCmdList["SIMPLEBOSSMODS"] = function(msg)
	msg = (msg or ""):lower()

	if msg == "" or msg == "settings" or msg == "config" or msg == "options" then
		M:OpenSettings()
		return
	end

	if msg == "test" or msg == "test start" or msg == "starttest" then
		M:StartTest()
		return
	end
	if msg == "test stop" or msg == "test end" or msg == "test off" or msg == "stoptest" then
		M:StopTest()
		return
	end
	if msg:sub(1, 4) == "pull" then
		handleManualTimer("pull", msg:sub(5))
		return
	end
	if msg:sub(1, 5) == "break" then
		handleManualTimer("break", msg:sub(6))
		return
	end
end

SlashCmdList["SIMPLEBOSSMODSPULL"] = function(msg)
	handleManualTimer("pull", msg)
end

SlashCmdList["SIMPLEBOSSMODSBREAK"] = function(msg)
	handleManualTimer("break", msg)
end

print("|cFF9CDF95Simple|rBossMods: '|cFF9CDF95/sbm|r' for in-game configuration.")
