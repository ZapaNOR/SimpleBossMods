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

local function getInstanceMapID()
	if not GetInstanceInfo then return nil end
	local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
	return instanceID
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
	local id = MANUAL_TIMER_IDS[kind]
	if not id then return end

	if kind == "pull" then
		self:StopManualTimer("break")
	end

	local now = GetTime()
	local rec = self.events[id]
	if not rec then
		rec = { id = id }
		self.events[id] = rec
	end

	rec.isManual = true
	rec.forceBar = true
	rec.kind = kind
	rec.suppressCountdown = false
	rec.source = nil
	local icon = (self.GetManualTimerIcon and self:GetManualTimerIcon(kind))
		or ((kind == "pull") and C.PULL_ICON or C.BREAK_ICON)
	rec.eventInfo = {
		name = (kind == "pull") and (C.PULL_LABEL or "Pull") or (C.BREAK_LABEL or "Break"),
		icon = icon,
	}
	rec.duration = seconds
	rec.startTime = now
	rec.endTime = now + seconds
	rec.remaining = seconds

	local nowServer = getServerTimeSafe()
	if nowServer then
		self:SaveManualTimerState(kind, nowServer + seconds, seconds, {
			suppressCountdown = rec.suppressCountdown,
			source = rec.source,
		})
	end

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
	local id = MANUAL_TIMER_IDS[kind]
	if not id then return end

	if kind == "pull" then
		self:StopManualTimer("break")
	end

	local now = GetTime()
	local rec = self.events[id]
	if not rec then
		rec = { id = id }
		self.events[id] = rec
	end

	rec.isManual = true
	rec.forceBar = true
	rec.kind = kind
	rec.suppressCountdown = not not suppressCountdown
	rec.source = source
	local icon = (self.GetManualTimerIcon and self:GetManualTimerIcon(kind))
		or ((kind == "pull") and C.PULL_ICON or C.BREAK_ICON)
	rec.eventInfo = {
		name = (kind == "pull") and (C.PULL_LABEL or "Pull") or (C.BREAK_LABEL or "Break"),
		icon = icon,
	}
	rec.duration = seconds
	rec.startTime = now
	rec.endTime = now + seconds
	rec.remaining = seconds

	local nowServer = getServerTimeSafe()
	if nowServer then
		self:SaveManualTimerState(kind, nowServer + seconds, seconds, {
			suppressCountdown = rec.suppressCountdown,
			source = source,
		})
	end

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

	local id = MANUAL_TIMER_IDS[kind]
	if not id then return end

	M.events = M.events or {}
	local rec = M.events[id]
	if not rec then
		rec = { id = id }
		M.events[id] = rec
	end

	rec.isManual = true
	rec.forceBar = true
	rec.kind = kind
	rec.suppressCountdown = suppressCountdown
	rec.source = info.source
	local icon = (M.GetManualTimerIcon and M:GetManualTimerIcon(kind))
		or ((kind == "pull") and C.PULL_ICON or C.BREAK_ICON)
	rec.eventInfo = {
		name = (kind == "pull") and (C.PULL_LABEL or "Pull") or (C.BREAK_LABEL or "Break"),
		icon = icon,
	}

	rec.duration = duration
	rec.startTime = GetTime() - (duration - remaining)
	rec.endTime = GetTime() + remaining
	rec.remaining = remaining

	if kind == "pull" then
		rec.ignoreCountdownUntil = GetTime() + 1
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

		M:SetPosition(SimpleBossModsDB.pos.x or 0, SimpleBossModsDB.pos.y or 0)
		M:ApplyGeneralConfig(
			SimpleBossModsDB.pos.x or 0,
			SimpleBossModsDB.pos.y or 0,
			SimpleBossModsDB.cfg.general.gap or 6,
			SimpleBossModsDB.cfg.general.mirror,
			SimpleBossModsDB.cfg.general.barsBelow,
			SimpleBossModsDB.cfg.general.autoInsertKeystone
		)
		M:ApplyIconConfig(SimpleBossModsDB.cfg.icons.size, SimpleBossModsDB.cfg.icons.fontSize, SimpleBossModsDB.cfg.icons.borderThickness)
		M:ApplyBarConfig(SimpleBossModsDB.cfg.bars.width, SimpleBossModsDB.cfg.bars.height, SimpleBossModsDB.cfg.bars.fontSize, SimpleBossModsDB.cfg.bars.borderThickness)
		M:ApplyIndicatorConfig(SimpleBossModsDB.cfg.indicators.iconSize or 0, SimpleBossModsDB.cfg.indicators.barSize or 0)

		M:CreateSettingsPanel()
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
		if name == "Blizzard_ChallengesUI" then
			if M.SetupKeystoneAutoInsert then
				M:SetupKeystoneAutoInsert()
			end
		end
	elseif event == "ENCOUNTER_TIMELINE_EVENT_ADDED"
		or event == "ENCOUNTER_TIMELINE_EVENT_REMOVED"
		or event == "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED" then
		C_Timer.After(0, function() M:Tick() end)
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
	end
end)

ef:RegisterEvent("PLAYER_LOGIN")
ef:RegisterEvent("ADDON_LOADED")
ef:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
ef:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_REMOVED")
ef:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")
ef:RegisterEvent("START_PLAYER_COUNTDOWN")
ef:RegisterEvent("CANCEL_PLAYER_COUNTDOWN")
ef:RegisterEvent("CHAT_MSG_ADDON")

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

	if msg == "test" then
		M:StartTest()
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

	print(ADDON_NAME .. " commands: /sbm | /sbm settings|config|options | /sbm test | /sbm pull <sec> | /sbm break <min>")
end

SlashCmdList["SIMPLEBOSSMODSPULL"] = function(msg)
	handleManualTimer("pull", msg)
end

SlashCmdList["SIMPLEBOSSMODSBREAK"] = function(msg)
	handleManualTimer("break", msg)
end
