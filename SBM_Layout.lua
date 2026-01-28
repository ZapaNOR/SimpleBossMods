-- SimpleBossMods layout and record management.

local ADDON_NAME = ...
local M = _G[ADDON_NAME]
if not M then return end

local C = M.Const
local L = M.Live
local U = M.Util
local frames = M.frames
local wipe = _G.wipe or function(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

local layoutIconList = {}
local layoutBarList = {}
local function isSecretValue(value)
	return type(issecretvalue) == "function" and issecretvalue(value)
end

local QUEUED_LABEL = "Queued"

local function isTerminalEventState(state)
	if not (Enum and Enum.EncounterTimelineEventState) then return false end
	return state == Enum.EncounterTimelineEventState.Finished
		or state == Enum.EncounterTimelineEventState.Canceled
end

local function isQueuedTrack(track)
	if not (Enum and Enum.EncounterTimelineTrack) then return false end
	return track == Enum.EncounterTimelineTrack.Queued
end

-- =========================
-- Layout
-- =========================
local function sortByRemaining(a, b)
	return (a.remaining or 999999) < (b.remaining or 999999)
end

local function isTestRec(rec)
	if not rec then return false end
	if rec.isTest then return true end
	if not (M._testTicker or M._testTimelineEventIDSet) then return false end
	if type(rec.eventInfo) ~= "table" then return false end
	local label = U.safeGetLabel(rec.eventInfo)
	if isSecretValue(label) then return false end
	return type(label) == "string" and label:find("^Test ") ~= nil
end

function M:layoutIcons()
	local list = layoutIconList
	wipe(list)
	for _, rec in pairs(self.events) do
		if rec.iconFrame then list[#list + 1] = rec end
	end
	table.sort(list, sortByRemaining)

	local total = #list
	local limit = L.ICONS_LIMIT or 0
	local count = total
	if limit > 0 and count > limit then
		count = limit
	end
	local cols = L.ICONS_PER_ROW or C.ICONS_PER_ROW
	if cols < 1 then cols = 1 end
	local rows = (count > 0) and math.ceil(count / cols) or 0

	for i, rec in ipairs(list) do
		if limit > 0 and i > limit then
			if rec.iconFrame then
				rec.iconFrame:Hide()
			end
		else
		local idx = i - 1
		local row = math.floor(idx / cols)
		local col = idx % cols

		local xDir = 1
		local yDir = -1
		if L.ICON_GROW_DIR == "LEFT_DOWN" then
			xDir = -1
			yDir = -1
		elseif L.ICON_GROW_DIR == "LEFT_UP" then
			xDir = -1
			yDir = 1
		elseif L.ICON_GROW_DIR == "RIGHT_DOWN" then
			xDir = 1
			yDir = -1
		else
			xDir = 1
			yDir = 1
		end

		local x = col * (L.ICON_SIZE + L.ICON_GAP) * xDir
		local y = row * (L.ICON_SIZE + L.ICON_GAP) * yDir
		local point
		if yDir < 0 then
			point = (xDir < 0) and "TOPRIGHT" or "TOPLEFT"
		else
			point = (xDir < 0) and "BOTTOMRIGHT" or "BOTTOMLEFT"
		end

		local f = rec.iconFrame
		f:Show()
		f:SetSize(L.ICON_SIZE, L.ICON_SIZE)
		M.ensureFullBorder(f.main, L.ICON_BORDER_THICKNESS)

		f:ClearAllPoints()
		f:SetPoint(point, frames.iconsParent, point, x, y)
		if isTestRec(rec) and M.ApplyTestIndicators then
			M:ApplyTestIndicators(f, true)
		elseif f.indicatorsFrame and f.indicatorsFrame.__indicatorTextures then
			M.layoutIconIndicators(f, f.indicatorsFrame.__indicatorTextures)
		end
		end
	end

	local w = (cols > 0) and (cols * L.ICON_SIZE + (cols - 1) * L.ICON_GAP) or 1
	local h = (rows > 0) and (rows * L.ICON_SIZE + (rows - 1) * L.ICON_GAP) or 1
	if w < 1 then w = 1 end
	if h < 1 then h = 1 end

	frames.iconsParent:SetSize(w, h)
end

function M:layoutBars()
	local list = layoutBarList
	wipe(list)
	for _, rec in pairs(self.events) do
		if rec.barFrame then list[#list + 1] = rec end
	end
	if L.BAR_SORT_ASC then
		table.sort(list, sortByRemaining)
	else
		table.sort(list, function(a, b)
			return (a.remaining or 999999) > (b.remaining or 999999)
		end)
	end

	local y = 0
	local maxEndW = 0

	for _, rec in ipairs(list) do
		local f = rec.barFrame
		f:SetSize(L.BAR_WIDTH, L.BAR_HEIGHT)
		M.ensureFullBorder(f, L.BAR_BORDER_THICKNESS)

		if M.applyBarMirror then
			M.applyBarMirror(f)
		else
			f.leftFrame:SetWidth(L.BAR_HEIGHT)
			f.iconFrame:SetSize(L.BAR_HEIGHT, L.BAR_HEIGHT)
			M.ensureRightDivider(f.leftFrame, L.BAR_BORDER_THICKNESS)
		end

		M.applyBarFont(f.txt)
		M.applyBarFont(f.rt)

		if rec.isManual then
			-- no secure timeline indicators for manual timers
		elseif isTestRec(rec) and M.ApplyTestIndicators then
			M:ApplyTestIndicators(f, false)
		else
			M.applyIndicatorsToBarEnd(f, rec.id)
		end
		if f.endIndicatorsFrame then
			local w = f.endIndicatorsFrame:GetWidth() or 0
			if w > 1 then
				maxEndW = math.max(maxEndW, w)
			end
		end

		f:ClearAllPoints()
		if L.BAR_GROW_DIR == "DOWN" then
			f:SetPoint("TOPLEFT", frames.barsParent, "TOPLEFT", 0, -y)
		else
			f:SetPoint("BOTTOMLEFT", frames.barsParent, "BOTTOMLEFT", 0, y)
		end
		y = y + L.BAR_HEIGHT + L.GAP
	end

	local h = (#list > 0) and (y - L.GAP) or 1
	local totalW = L.BAR_WIDTH + (maxEndW > 0 and (C.BAR_END_INDICATOR_GAP_X + maxEndW) or 0)
	frames.barsParent:SetSize(totalW, h)
end

function M:LayoutAll()
	self._layoutDirty = false
	self:layoutIcons()
	self:layoutBars()
end

-- =========================
-- Core
-- =========================
function M:removeEvent(eventID)
	local rec = self.events[eventID]
	if not rec then return end
	if rec.countdownTimer and rec.countdownTimer.Cancel then
		rec.countdownTimer:Cancel()
	end
	rec.countdownTimer = nil
	if rec.isManual and rec.kind and self.ClearManualTimerState then
		self:ClearManualTimerState(rec.kind)
	end
	M.releaseIcon(rec.iconFrame)
	M.releaseBar(rec.barFrame)
	self.events[eventID] = nil
	self._layoutDirty = true
end

function M:clearAll()
	for id in pairs(self.events) do
		self:removeEvent(id)
	end
	self:LayoutAll()
end

local function updateRecTiming(rec, remaining)
	local now = GetTime()
	if type(remaining) ~= "number" then return end

	if not rec.duration then
		rec.duration = remaining
		rec.startTime = now
	else
		if remaining > rec.duration then
			rec.duration = remaining
			rec.startTime = now
		else
			rec.startTime = now - (rec.duration - remaining)
		end
	end
end

M._updateRecTiming = updateRecTiming

local function refreshIconTexture(rec)
	local f = rec.iconFrame
	if not f then return end
	if isSecretValue(rec._iconFileID) then
		rec._iconFileID = nil
	end
	local iconFileID = U.safeGetIconFileID(rec.eventInfo)
	if isSecretValue(iconFileID) then
		f.tex:SetTexture(iconFileID)
		if iconFileID then
			local z = C.ICON_ZOOM
			f.tex:SetTexCoord(z, 1 - z, z, 1 - z)
		else
			f.tex:SetTexCoord(0, 1, 0, 1)
		end
		rec._iconFileID = nil
		return
	end
	if iconFileID ~= rec._iconFileID then
		rec._iconFileID = iconFileID
		if iconFileID then
			f.tex:SetTexture(iconFileID)
			local z = C.ICON_ZOOM
			f.tex:SetTexCoord(z, 1 - z, z, 1 - z)
		else
			f.tex:SetTexture(nil)
			f.tex:SetTexCoord(0, 1, 0, 1)
		end
	end
end

local function refreshBarLabelAndIcon(rec)
	local bar = rec.barFrame
	if not bar then return end

	local label = U.safeGetLabel(rec.eventInfo)
	if isSecretValue(rec._barLabel) then
		rec._barLabel = nil
	end
	if isSecretValue(label) then
		bar.txt:SetText(label)
		rec._barLabel = nil
	elseif label ~= "" and label ~= rec._barLabel then
		bar.txt:SetText(label)
		rec._barLabel = label
	end

	if isSecretValue(rec._barIconFileID) then
		rec._barIconFileID = nil
	end
	local iconFileID = U.safeGetIconFileID(rec.eventInfo)
	if isSecretValue(iconFileID) then
		bar.icon:SetTexture(iconFileID)
		if iconFileID then
			local z = C.ICON_ZOOM
			bar.icon:SetTexCoord(z, 1 - z, z, 1 - z)
		else
			bar.icon:SetTexCoord(0, 1, 0, 1)
		end
		rec._barIconFileID = nil
		return
	end
	if iconFileID ~= rec._barIconFileID then
		rec._barIconFileID = iconFileID
		if iconFileID then
			bar.icon:SetTexture(iconFileID)
			local z = C.ICON_ZOOM
			bar.icon:SetTexCoord(z, 1 - z, z, 1 - z)
		else
			bar.icon:SetTexture(nil)
			bar.icon:SetTexCoord(0, 1, 0, 1)
		end
	end
end

function M:ensureIcon(rec)
	if L.ICONS_ENABLED == false then
		if rec.iconFrame then
			M.releaseIcon(rec.iconFrame)
			rec.iconFrame = nil
		end
		if rec.barFrame then
			M.releaseBar(rec.barFrame)
			rec.barFrame = nil
		end
		return
	end
	if rec.iconFrame then return end
	if rec.barFrame then
		M.releaseBar(rec.barFrame)
		rec.barFrame = nil
	end
	local icon = M.acquireIcon()
	icon.__id = rec.id
	rec.iconFrame = icon

	icon.tex:SetTexture(nil)
	icon.tex:SetTexCoord(0, 1, 0, 1)
	rec._iconFileID = nil
	rec._indicatorAppliedIcon = false
	rec._indicatorDirty = true
	refreshIconTexture(rec)
end

function M:ensureBar(rec)
	if rec.barFrame then return end
	if rec.iconFrame then
		M.releaseIcon(rec.iconFrame)
		rec.iconFrame = nil
	end

	local bar = M.acquireBar()
	bar.__id = rec.id
	rec.barFrame = bar

	bar.txt:SetText("Ability")
	bar.icon:SetTexture(nil)
	bar.icon:SetTexCoord(0, 1, 0, 1)
	rec._barIconFileID = nil
	rec._barLabel = nil
	rec._indicatorAppliedBar = false
	rec._indicatorDirty = true
	refreshBarLabelAndIcon(rec)
	M.setBarFillFlat(bar, L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A)

	bar:SetScript("OnUpdate", function(self)
		local rrec = M.events[self.__id]
		if not rrec then return end

		local rem = rrec.remaining
		if rrec.isManual and rrec.endTime then
			rem = rrec.endTime - GetTime()
			if rem < 0 then rem = 0 end
			rrec.remaining = rem
		elseif C_EncounterTimeline and C_EncounterTimeline.GetEventTimeRemaining then
			local ok, v = pcall(C_EncounterTimeline.GetEventTimeRemaining, rrec.id)
			if ok and type(v) == "number" then
				rem = v
				rrec.remaining = v
			end
		end

		if type(rem) ~= "number" then rem = 999 end
		local isQueued = rrec.isQueued and not rrec.isManual
		if isQueued then
			self.sb:SetMinMaxValues(0, L.THRESHOLD_TO_BAR)
			self.sb:SetValue(0)
			if self.rt._sbmQueued ~= true then
				self.rt:SetText(QUEUED_LABEL)
				self.rt._sbmQueued = true
			end
			return
		end

		if rem <= 0 then
			M:removeEvent(rrec.id)
			M:LayoutAll()
			return
		end
		if self.rt._sbmQueued then
			self.rt._sbmQueued = nil
		end

		if rrec.isManual then
			local dur = rrec.duration
			if type(dur) == "number" and dur > 0 then
				self.sb:SetMinMaxValues(0, dur)
				self.sb:SetValue(U.clamp(rem, 0, dur))
			else
				self.sb:SetMinMaxValues(0, L.THRESHOLD_TO_BAR)
				self.sb:SetValue(U.clamp(rem, 0, L.THRESHOLD_TO_BAR))
			end
			self.rt:SetText(U.formatTimeBar(rem))
		else
			local shown = U.clamp(rem, 0, L.THRESHOLD_TO_BAR)
			self.sb:SetMinMaxValues(0, L.THRESHOLD_TO_BAR)
			self.sb:SetValue(shown)
			self.rt:SetText(U.formatTimeBar(shown))
		end
	end)
end

function M:updateRecord(eventID, eventInfo, remaining)
	if not self.enabled then return end
	if type(eventID) ~= "number" then return end

	local rec = self.events[eventID]
	local isNew = false
	if not rec then
		rec = { id = eventID }
		self.events[eventID] = rec
		isNew = true
	end

	rec.eventInfo = eventInfo or rec.eventInfo
	rec.remaining = remaining or rec.remaining

	local isTest = isTestRec(rec)
	if rec.isManual or isTest then
		rec.isQueued = false
	end
	if not rec.isManual and not isTest and rec.eventInfo and type(rec.eventInfo.icons) == "number" then
		if isSecretValue(rec._indicatorMask) then
			rec._indicatorMask = nil
		end
		if isSecretValue(rec.eventInfo.icons) then
			if not rec._indicatorMaskSecret then
				rec._indicatorMaskSecret = true
				rec._indicatorDirty = true
			end
		else
			if rec._indicatorMaskSecret then
				rec._indicatorMaskSecret = false
			end
			if rec._indicatorMask ~= rec.eventInfo.icons then
				rec._indicatorMask = rec.eventInfo.icons
				rec._indicatorDirty = true
			end
		end
	end

	if type(rec.remaining) == "number" then
		updateRecTiming(rec, rec.remaining)
	end

	local iconsEnabled = L.ICONS_ENABLED ~= false
	local wantBar = rec.forceBar
	if not wantBar and type(rec.remaining) == "number" and rec.remaining <= L.THRESHOLD_TO_BAR then
		wantBar = true
	end
	local hadBar = rec.barFrame ~= nil
	local hadIcon = rec.iconFrame ~= nil
	if wantBar then
		self:ensureBar(rec)
	else
		if iconsEnabled then
			self:ensureIcon(rec)
		else
			if rec.iconFrame then
				M.releaseIcon(rec.iconFrame)
				rec.iconFrame = nil
			end
			if rec.barFrame then
				M.releaseBar(rec.barFrame)
				rec.barFrame = nil
			end
		end
	end
	if isNew or hadBar ~= (rec.barFrame ~= nil) or hadIcon ~= (rec.iconFrame ~= nil) then
		self._layoutDirty = true
	end

	if rec.iconFrame then
		local f = rec.iconFrame
		refreshIconTexture(rec)
		local rem = rec.remaining
		if rec.isQueued and not rec.isManual then
			if f.timeText._sbmQueued ~= true then
				f.timeText:SetText(QUEUED_LABEL)
				f.timeText._sbmQueued = true
			end
			f.cd:Clear()
		else
			if f.timeText._sbmQueued then
				f.timeText._sbmQueued = nil
			end
			if type(rem) == "number" and rem > 0 then
				f.timeText:SetText(U.formatTimeIcon(rem))
				if rec.startTime and rec.duration and rec.duration > 0 then
					f.cd:SetCooldown(rec.startTime, rec.duration)
				end
			else
				f.timeText:SetText("")
				f.cd:Clear()
			end
		end

		if rec.isManual then
			-- no secure timeline indicators for manual timers
		elseif isTest and M.ApplyTestIndicators then
			M:ApplyTestIndicators(f, true)
		else
			if rec._indicatorDirty or not rec._indicatorAppliedIcon then
				M.applyIndicatorsToIconFrame(f, rec.id)
				rec._indicatorAppliedIcon = true
				rec._indicatorDirty = false
			end
		end
	end

	if rec.barFrame then
		refreshBarLabelAndIcon(rec)
		if rec.isManual then
			if type(rec.duration) == "number" and rec.duration > 0 then
				rec.barFrame.sb:SetMinMaxValues(0, rec.duration)
				rec.barFrame.sb:SetValue(U.clamp(rec.remaining or rec.duration, 0, rec.duration))
			end
		elseif isTest and M.ApplyTestIndicators then
			M:ApplyTestIndicators(rec.barFrame, false)
		else
			if rec._indicatorDirty or not rec._indicatorAppliedBar then
				M.applyIndicatorsToBarEnd(rec.barFrame, rec.id)
				rec._indicatorAppliedBar = true
				rec._indicatorDirty = false
			end
		end
		M.setBarFillFlat(rec.barFrame, L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A)
	end
end

-- =========================
-- Timeline refresh
-- =========================
function M:Tick()
	if not self.enabled then return end
	if self._testTicker then return end
	if self.UpdatePrivateAuraFrames then
		self:UpdatePrivateAuraFrames(true)
	end
	local suppressUntil = self._suppressTimelineUntil
	if suppressUntil then
		local now = (GetTime and GetTime()) or 0
		if now < suppressUntil then
			return
		end
		self._suppressTimelineUntil = nil
	end
	local hasTimeline = C_EncounterTimeline
		and C_EncounterTimeline.GetEventList
	if not hasTimeline then return end

	local list
	do
		local ok, result = pcall(C_EncounterTimeline.GetEventList)
		if ok then
			list = result
		end
	end
	if type(list) ~= "table" or #list == 0 then
		if next(self.events) ~= nil then
			for id, rec in pairs(self.events) do
				if not (rec and rec.isManual) then
					self:removeEvent(id)
				end
			end
		end
		if self._layoutDirty then
			self:LayoutAll()
		end
		return
	end

	local seen = self._seenEvents
	if not seen then
		seen = {}
		self._seenEvents = seen
	else
		wipe(seen)
	end
	for _, eventID in ipairs(list) do
		seen[eventID] = true
		local rec = self.events[eventID]
		if not rec then
			rec = { id = eventID }
			self.events[eventID] = rec
			self._layoutDirty = true
		end

		local info = C_EncounterTimeline.GetEventInfo and C_EncounterTimeline.GetEventInfo(eventID) or nil
		rec.isTest = self._testTimelineEventIDSet and self._testTimelineEventIDSet[eventID] or false
		do
			local track, state
			if C_EncounterTimeline.GetEventTrack then
				local ok, tr = pcall(C_EncounterTimeline.GetEventTrack, eventID)
				if ok then
					track = tr
				end
			end
			if C_EncounterTimeline.GetEventState then
				local ok, st = pcall(C_EncounterTimeline.GetEventState, eventID)
				if ok then
					state = st
				end
			end
			rec._timelineTrack = track
			rec._timelineState = state
			rec.isQueued = isQueuedTrack(track) and not isTerminalEventState(state)
		end
		local rem = C_EncounterTimeline.GetEventTimeRemaining and C_EncounterTimeline.GetEventTimeRemaining(eventID) or nil
		self:updateRecord(eventID, info, rem)
	end

	for id in pairs(self.events) do
		local rec = self.events[id]
		if not seen[id] and not (rec and rec.isManual) then
			self:removeEvent(id)
		end
	end

	if self._layoutDirty then
		self:LayoutAll()
	end
end

C_Timer.NewTicker(C.TICK_INTERVAL, function() M:Tick() end)
