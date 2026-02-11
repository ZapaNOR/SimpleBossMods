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

local function readEventColor(eventInfo)
	if type(eventInfo) ~= "table" then return nil end
	local color = eventInfo.color
	if isSecretValue(color) then return nil end
	if type(color) ~= "table" then return nil end
	if type(color.GetRGBA) == "function" then
		local ok, r, g, b, a = pcall(color.GetRGBA, color)
		if ok and type(r) == "number" then
			return r, g, b, a
		end
	end
	if type(color.GetRGB) == "function" then
		local ok, r, g, b = pcall(color.GetRGB, color)
		if ok and type(r) == "number" then
			return r, g, b, 1
		end
	end
	if type(color.r) == "number" and type(color.g) == "number" and type(color.b) == "number" then
		return color.r, color.g, color.b, type(color.a) == "number" and color.a or 1
	end
	return nil
end

local function getSeverityColor(eventInfo)
	if type(eventInfo) ~= "table" then return nil end
	local severity = eventInfo.severity
	if isSecretValue(severity) then return nil end
	if type(severity) ~= "number" then return nil end
	if Enum and Enum.EncounterEventSeverity then
		if severity == Enum.EncounterEventSeverity.High then
			return L.SEVERITY_HIGH_R, L.SEVERITY_HIGH_G, L.SEVERITY_HIGH_B, L.SEVERITY_HIGH_A
		elseif severity == Enum.EncounterEventSeverity.Medium then
			return L.SEVERITY_MED_R, L.SEVERITY_MED_G, L.SEVERITY_MED_B, L.SEVERITY_MED_A
		elseif severity == Enum.EncounterEventSeverity.Low then
			return L.SEVERITY_LOW_R, L.SEVERITY_LOW_G, L.SEVERITY_LOW_B, L.SEVERITY_LOW_A
		end
	end
	if severity >= 2 then
		return L.SEVERITY_HIGH_R, L.SEVERITY_HIGH_G, L.SEVERITY_HIGH_B, L.SEVERITY_HIGH_A
	elseif severity >= 1 then
		return L.SEVERITY_MED_R, L.SEVERITY_MED_G, L.SEVERITY_MED_B, L.SEVERITY_MED_A
	end
	return L.SEVERITY_LOW_R, L.SEVERITY_LOW_G, L.SEVERITY_LOW_B, L.SEVERITY_LOW_A
end

local function getRecordBarColor(rec)
	if not L.SEVERITY_COLOR_ENABLED then
		return L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A
	end
	local eventInfo = rec and rec.eventInfo
	if L.SEVERITY_COLOR_USE_BLIZZARD then
		local r, g, b, a = readEventColor(eventInfo)
		if r then
			return r, g, b, a
		end
	end
	local r, g, b, a = getSeverityColor(eventInfo)
	if r then
		return r, g, b, a
	end
	return L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A
end

local function getIconBorderColor(rec)
	if not L.SEVERITY_COLOR_ENABLED then
		return 0, 0, 0, 1
	end
	local eventInfo = rec and rec.eventInfo
	local r, g, b, a
	if L.SEVERITY_COLOR_USE_BLIZZARD then
		r, g, b, a = readEventColor(eventInfo)
	end
	if not r then
		r, g, b, a = getSeverityColor(eventInfo)
	end
	if not r then
		return 0, 0, 0, 1
	end
	return r, g, b, a
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
	local ar = a and a.remaining
	local br = b and b.remaining
	if type(ar) ~= "number" or isSecretValue(ar) then
		ar = nil
	end
	if type(br) ~= "number" or isSecretValue(br) then
		br = nil
	end
	return (ar or 999999) < (br or 999999)
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
	if type(remaining) ~= "number" or isSecretValue(remaining) then return end

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

local function barOnUpdate(self)
	local rec = self.__sbmRec
	if not rec or rec.barFrame ~= self then return end
	if rec.isQueued and not rec.isManual then return end

	local dur = rec.duration
	local start = rec.startTime
	if type(dur) ~= "number" or type(start) ~= "number" then return end
	if isSecretValue(dur) or isSecretValue(start) then return end

	local now = (GetTime and GetTime()) or 0
	local rem = (start + dur) - now
	if rem < 0 then rem = 0 end
	if isSecretValue(rem) then return end

	if rec.isManual then
		local shown = U.clamp(rem, 0, dur)
		self.sb:SetMinMaxValues(0, dur)
		self.sb:SetValue(shown)
		self.rt:SetText(U.formatTimeBar(shown))
	else
		local shown = U.clamp(rem, 0, L.THRESHOLD_TO_BAR)
		self.sb:SetMinMaxValues(0, L.THRESHOLD_TO_BAR)
		self.sb:SetValue(shown)
		self.rt:SetText(U.formatTimeBar(shown))
	end
end

function M:ensureBar(rec)
	if rec.barFrame then return end
	if rec.iconFrame then
		M.releaseIcon(rec.iconFrame)
		rec.iconFrame = nil
	end

	local bar = M.acquireBar()
	bar.__id = rec.id
	bar.__sbmRec = rec
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
	bar:SetScript("OnUpdate", barOnUpdate)
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
	if remaining ~= nil then
		rec.remaining = remaining
	end
	local remainingValue = rec.remaining
	local remainingIsNumber = type(remainingValue) == "number" and not isSecretValue(remainingValue)

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

	if remainingIsNumber then
		updateRecTiming(rec, remainingValue)
	end

	if rec.isHidden and not rec.isManual and not isTest then
		local hadBar = rec.barFrame ~= nil
		local hadIcon = rec.iconFrame ~= nil
		if rec.iconFrame then
			M.releaseIcon(rec.iconFrame)
			rec.iconFrame = nil
		end
		if rec.barFrame then
			M.releaseBar(rec.barFrame)
			rec.barFrame = nil
		end
		if hadBar or hadIcon then
			self._layoutDirty = true
		end
		return
	end

	local iconsEnabled = L.ICONS_ENABLED ~= false
	local wantBar = rec.forceBar
	if not wantBar then
		if remainingIsNumber and remainingValue <= L.THRESHOLD_TO_BAR then
			wantBar = true
		elseif not remainingIsNumber then
			wantBar = rec.barFrame ~= nil
		end
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
		local remIsNumber = type(rem) == "number" and not isSecretValue(rem)
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
			if remIsNumber and rem > 0 then
				f.timeText:SetText(U.formatTimeIcon(rem))
				if rec.startTime and rec.duration and rec.duration > 0 then
					f.cd:SetCooldown(rec.startTime, rec.duration)
				end
			else
				f.timeText:SetText(U.formatTimeIcon(rem))
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

		if f.main and M.ensureFullBorder then
			local br, bg, bb, ba = 0, 0, 0, 1
			if L.ICON_SEVERITY_BORDER and L.SEVERITY_COLOR_ENABLED then
				br, bg, bb, ba = getIconBorderColor(rec)
			end
			M.ensureFullBorder(f.main, L.ICON_BORDER_THICKNESS, br, bg, bb, ba)
		end
	end

	if rec.barFrame then
		refreshBarLabelAndIcon(rec)
		local rem = rec.remaining
		local remIsNumber = type(rem) == "number" and not isSecretValue(rem)
		if rec.isQueued and not rec.isManual then
			if rec.barFrame.rt._sbmQueued ~= true then
				rec.barFrame.rt:SetText(QUEUED_LABEL)
				rec.barFrame.rt._sbmQueued = true
			end
			rec.barFrame.sb:SetMinMaxValues(0, L.THRESHOLD_TO_BAR)
			rec.barFrame.sb:SetValue(0)
		else
			if rec.barFrame.rt._sbmQueued then
				rec.barFrame.rt._sbmQueued = nil
			end
			if rec.isManual then
				if remIsNumber and rem <= 0 then
					self:removeEvent(rec.id)
					return
				end
				local dur = rec.duration
				if type(dur) == "number" and dur > 0 then
					rec.barFrame.sb:SetMinMaxValues(0, dur)
					rec.barFrame.sb:SetValue(remIsNumber and U.clamp(rem, 0, dur) or 0)
				else
					rec.barFrame.sb:SetMinMaxValues(0, L.THRESHOLD_TO_BAR)
					rec.barFrame.sb:SetValue(remIsNumber and U.clamp(rem, 0, L.THRESHOLD_TO_BAR) or 0)
				end
				rec.barFrame.rt:SetText(U.formatTimeBar(rem))
			else
				if remIsNumber then
					local shown = U.clamp(rem, 0, L.THRESHOLD_TO_BAR)
					rec.barFrame.sb:SetMinMaxValues(0, L.THRESHOLD_TO_BAR)
					rec.barFrame.sb:SetValue(shown)
					rec.barFrame.rt:SetText(U.formatTimeBar(shown))
				else
					rec.barFrame.rt:SetText(U.formatTimeBar(rem))
				end
			end
		end

		if isTest and M.ApplyTestIndicators then
			M:ApplyTestIndicators(rec.barFrame, false)
		else
			if rec._indicatorDirty or not rec._indicatorAppliedBar then
				M.applyIndicatorsToBarEnd(rec.barFrame, rec.id)
				rec._indicatorAppliedBar = true
				rec._indicatorDirty = false
			end
		end
		local r, g, b, a = getRecordBarColor(rec)
		M.setBarFillFlat(rec.barFrame, r, g, b, a)
	end
end

-- =========================
-- Timeline refresh (event-driven)
-- =========================
local function canUseTimelineAPI()
	return C_EncounterTimeline and C_EncounterTimeline.GetEventList
end

local function isEditModeActive()
	return EditModeManagerFrame
		and type(EditModeManagerFrame.IsEditModeActive) == "function"
		and EditModeManagerFrame:IsEditModeActive()
end

local function isEditModeEvent(eventInfo)
	if type(eventInfo) ~= "table" then return false end
	local source = eventInfo.source
	if isSecretValue(source) then return false end
	if Enum and Enum.EncounterTimelineEventSource then
		return source == Enum.EncounterTimelineEventSource.EditMode
	end
	return false
end

local function isTimelineFeatureEnabled()
	if not canUseTimelineAPI() then return false end
	if C_EncounterTimeline.IsFeatureAvailable and not C_EncounterTimeline.IsFeatureAvailable() then
		return false
	end
	return true
end

local function safeGetEventInfo(eventID)
	if not (C_EncounterTimeline and C_EncounterTimeline.GetEventInfo) then return nil end
	local ok, info = pcall(C_EncounterTimeline.GetEventInfo, eventID)
	if ok then return info end
	return nil
end

local function safeGetEventTimer(eventID)
	if not (C_EncounterTimeline and C_EncounterTimeline.GetEventTimer) then return nil end
	local ok, timer = pcall(C_EncounterTimeline.GetEventTimer, eventID)
	if ok then return timer end
	return nil
end

local function safeGetEventElapsed(eventID)
	if not (C_EncounterTimeline and C_EncounterTimeline.GetEventTimeElapsed) then return nil end
	local ok, elapsed = pcall(C_EncounterTimeline.GetEventTimeElapsed, eventID)
	if ok then return elapsed end
	return nil
end

local function safeGetEventRemaining(eventID, timer)
	if timer and type(timer.GetRemainingDuration) == "function" then
		local ok, rem = pcall(timer.GetRemainingDuration, timer)
		if ok then return rem end
	end
	if C_EncounterTimeline and C_EncounterTimeline.GetEventTimeRemaining then
		local ok, rem = pcall(C_EncounterTimeline.GetEventTimeRemaining, eventID)
		if ok then return rem end
	end
	return nil
end

local function safeGetEventTrack(eventID)
	if not (C_EncounterTimeline and C_EncounterTimeline.GetEventTrack) then return nil end
	local ok, track, sortIndex = pcall(C_EncounterTimeline.GetEventTrack, eventID)
	if ok then return track, sortIndex end
	return nil
end

local function safeGetEventState(eventID)
	if not (C_EncounterTimeline and C_EncounterTimeline.GetEventState) then return nil end
	local ok, state = pcall(C_EncounterTimeline.GetEventState, eventID)
	if ok then return state end
	return nil
end

local function safeIsEventBlocked(eventID)
	if not (C_EncounterTimeline and C_EncounterTimeline.IsEventBlocked) then return nil end
	local ok, blocked = pcall(C_EncounterTimeline.IsEventBlocked, eventID)
	if ok then return blocked end
	return nil
end

local function safeGetTrackType(track)
	if not track then return nil end
	if not (C_EncounterTimeline and C_EncounterTimeline.GetTrackType) then return nil end
	local ok, trackType = pcall(C_EncounterTimeline.GetTrackType, track)
	if ok then return trackType end
	return nil
end

local function buildVisibleEventSet()
	if not (C_EncounterTimeline and C_EncounterTimeline.GetSortedEventList) then return nil end
	local ok, list = pcall(C_EncounterTimeline.GetSortedEventList, nil, nil, false, true)
	if not (ok and type(list) == "table") then return nil end
	if #list == 0 then
		return nil
	end
	local set = {}
	for _, id in ipairs(list) do
		set[id] = true
	end
	return set
end

local function isEventHidden(eventID, track, trackType, visibleSet)
	if visibleSet then
		return not visibleSet[eventID]
	end
	if isSecretValue(track) or isSecretValue(trackType) then
		return false
	end
	if Enum and Enum.EncounterTimelineTrackType and trackType == Enum.EncounterTimelineTrackType.Hidden then
		return true
	end
	if Enum and Enum.EncounterTimelineTrack and track == Enum.EncounterTimelineTrack.Indeterminate then
		return true
	end
	return false
end

function M:ClearTimelineEvents()
	for id, rec in pairs(self.events) do
		if not (rec and rec.isManual) then
			self:removeEvent(id)
		end
	end
	if self._layoutDirty then
		self:LayoutAll()
	end
end

function M:UpdateTimelineEvent(eventID, eventInfo, visibleSet)
	if not self.enabled then return end
	if type(eventID) ~= "number" or eventID == 0 then return end

	local rec = self.events[eventID]
	local isNew = false
	if not rec then
		rec = { id = eventID }
		self.events[eventID] = rec
		isNew = true
	end

	if eventInfo == nil and rec.eventInfo == nil then
		eventInfo = safeGetEventInfo(eventID)
	end
	if eventInfo ~= nil then
		rec.eventInfo = eventInfo
	end

	if rec.eventInfo and isEditModeEvent(rec.eventInfo) and not self._allowEditModeEvents then
		self:removeEvent(eventID)
		return
	end
	if rec.eventInfo and not self._allowEditModeEvents then
		local label = U.safeGetLabel(rec.eventInfo)
		if type(label) == "string" and not isSecretValue(label) then
			if label:find("Boss Timeline Preview", 1, true) then
				self:removeEvent(eventID)
				return
			end
		end
	end

	if rec.eventInfo and type(rec.eventInfo.duration) == "number" and not isSecretValue(rec.eventInfo.duration) then
		rec.duration = rec.eventInfo.duration
	end

	rec.isTest = self._testTimelineEventIDSet and self._testTimelineEventIDSet[eventID] or false

	rec._eventTimer = rec._eventTimer or safeGetEventTimer(eventID)

	local track, sortIndex = safeGetEventTrack(eventID)
	local state = safeGetEventState(eventID)
	local blocked = safeIsEventBlocked(eventID)
	local trackType = (not isSecretValue(track)) and safeGetTrackType(track) or nil

	rec._timelineTrack = track
	rec._timelineTrackSortIndex = sortIndex
	rec._timelineState = state
	rec._timelineBlocked = blocked
	rec._timelineTrackType = trackType

	if not (isSecretValue(track) or isSecretValue(state)) then
		rec.isQueued = isQueuedTrack(track) and not isTerminalEventState(state)
	end

	rec.isHidden = isEventHidden(eventID, track, trackType, visibleSet)

	local rem = safeGetEventRemaining(eventID, rec._eventTimer)
	if (rem == nil or isSecretValue(rem)) and rec.duration then
		local elapsed = safeGetEventElapsed(eventID)
		if type(elapsed) == "number" and not isSecretValue(elapsed) then
			rem = rec.duration - elapsed
		end
	end
	if type(rem) == "number" and not isSecretValue(rem) and rem < 0 then
		rem = 0
	end
	if rem ~= nil then
		rec.remaining = rem
	end

	self:updateRecord(eventID, rec.eventInfo, rec.remaining)
	if isNew then
		self._layoutDirty = true
	end
end

function M:RefreshTimelineEvents()
	if not canUseTimelineAPI() then return end

	self._timelineFeatureEnabled = isTimelineFeatureEnabled()
	self._allowEditModeEvents = isEditModeActive()
	if not self._timelineFeatureEnabled then
		self:ClearTimelineEvents()
		return
	end

	local list
	do
		local ok, result = pcall(C_EncounterTimeline.GetEventList)
		if ok then
			list = result
		end
	end

	if type(list) ~= "table" or #list == 0 then
		self:ClearTimelineEvents()
		return
	end

	local seen = self._seenEvents
	if not seen then
		seen = {}
		self._seenEvents = seen
	else
		wipe(seen)
	end

	local visibleSet = buildVisibleEventSet()

	for _, eventID in ipairs(list) do
		seen[eventID] = true
		local info = safeGetEventInfo(eventID)
		self:UpdateTimelineEvent(eventID, info, visibleSet)
	end

	for id, rec in pairs(self.events) do
		if not seen[id] and not (rec and rec.isManual) then
			self:removeEvent(id)
		end
	end

	if self._layoutDirty then
		self:LayoutAll()
	end
end

function M:HandleTimelineEvent(event, ...)
	if event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then
		local info = ...
		if type(info) == "table" then
			self:UpdateTimelineEvent(info.id, info)
		end
	elseif event == "ENCOUNTER_TIMELINE_EVENT_REMOVED" then
		local eventID = ...
		local rec = self.events[eventID]
		if rec and not rec.isManual then
			self:removeEvent(eventID)
		end
	elseif event == "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED" then
		local eventID = ...
		self:UpdateTimelineEvent(eventID, nil)
	elseif event == "ENCOUNTER_TIMELINE_EVENT_TRACK_CHANGED" then
		local eventID = ...
		self:UpdateTimelineEvent(eventID, nil)
	elseif event == "ENCOUNTER_TIMELINE_EVENT_BLOCK_STATE_CHANGED" then
		local eventID = ...
		self:UpdateTimelineEvent(eventID, nil)
	elseif event == "ENCOUNTER_TIMELINE_EVENT_HIGHLIGHT" then
		local eventID = ...
		local rec = self.events[eventID]
		if rec then
			rec._highlightedAt = GetTime()
		end
	elseif event == "ENCOUNTER_TIMELINE_LAYOUT_UPDATED"
		or event == "ENCOUNTER_TIMELINE_STATE_UPDATED" then
		self:RefreshTimelineEvents()
	elseif event == "ENCOUNTER_TIMELINE_VIEW_ACTIVATED" then
		self._timelineViewActive = true
		self:RefreshTimelineEvents()
	elseif event == "ENCOUNTER_TIMELINE_VIEW_DEACTIVATED" then
		self._timelineViewActive = false
	end

	if self._layoutDirty then
		self:LayoutAll()
	end
end

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

	local hasTimeline = canUseTimelineAPI() and (self._timelineFeatureEnabled ~= false)
	local now = (GetTime and GetTime()) or 0

	for id, rec in pairs(self.events) do
		if rec.isManual and rec.endTime then
			local rem = rec.endTime - now
			if rem < 0 then rem = 0 end
			rec.remaining = rem
			if not isSecretValue(rem) and rem <= 0 then
				self:removeEvent(id)
			else
				self:updateRecord(id, rec.eventInfo, rec.remaining)
			end
	elseif hasTimeline then
		local rem = safeGetEventRemaining(id, rec._eventTimer)
		if (rem == nil or isSecretValue(rem)) and rec.duration then
			local elapsed = safeGetEventElapsed(id)
			if type(elapsed) == "number" and not isSecretValue(elapsed) then
				rem = rec.duration - elapsed
			end
		end
		if type(rem) == "number" and not isSecretValue(rem) and rem < 0 then
			rem = 0
		end
		if rem ~= nil then
			rec.remaining = rem
		end
		self:updateRecord(id, rec.eventInfo, rec.remaining)
		if rec._timelineState and not isSecretValue(rec._timelineState) and isTerminalEventState(rec._timelineState) then
			self:removeEvent(id)
		end
	end
end

	if self._layoutDirty then
		self:LayoutAll()
	end
end

C_Timer.NewTicker(C.TICK_INTERVAL, function() M:Tick() end)
