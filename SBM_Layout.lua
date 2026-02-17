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
local Enum_EncounterTimelineEventSource = Enum and Enum.EncounterTimelineEventSource
local EDIT_MODE_SOURCE_ID = (Enum_EncounterTimelineEventSource and Enum_EncounterTimelineEventSource.EditMode) or 2

local function isSecretValue(value)
	return type(issecretvalue) == "function" and issecretvalue(value)
end

local function unpackColor(color)
	if type(color) ~= "table" then
		return nil
	end
	local rawR = color.r or color[1]
	local rawG = color.g or color[2]
	local rawB = color.b or color[3]
	local rawA = color.a or color[4] or 1
	local hasSecret = isSecretValue(rawR) or isSecretValue(rawG) or isSecretValue(rawB) or isSecretValue(rawA)
	if hasSecret then
		if rawR ~= nil and rawG ~= nil and rawB ~= nil then
			return rawR, rawG, rawB, rawA, true
		end
		return nil
	end
	local r = tonumber(rawR)
	local g = tonumber(rawG)
	local b = tonumber(rawB)
	local a = tonumber(rawA)
	if isSecretValue(r) or isSecretValue(g) or isSecretValue(b) or isSecretValue(a) then
		return nil
	end
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		return nil
	end
	return U.clamp(r, 0, 1), U.clamp(g, 0, 1), U.clamp(b, 0, 1), U.clamp(a, 0, 1), false
end

local function getIndicatorBarColor(rec)
	if type(rec) ~= "table" then return nil end
	local eventInfo = rec.eventInfo
	if type(eventInfo) ~= "table" then return nil end

	local rawMask = eventInfo.icons
	if rawMask == nil then
		rawMask = rec._indicatorMask
	end
	if isSecretValue(rawMask) then
		rawMask = nil
	end

	local mask = tonumber(rawMask)
	if type(mask) ~= "number" or mask <= 0 then
		mask = nil
	end

	local rawSeverity = eventInfo.severity
	if isSecretValue(rawSeverity) then
		rawSeverity = nil
	end

	if type(M.ResolveIndicatorColorForEvent) == "function" then
		return M.ResolveIndicatorColorForEvent(mask, rawSeverity)
	end
	if type(M.ResolveIndicatorColorForMask) == "function" and mask then
		return M.ResolveIndicatorColorForMask(mask)
	end
	return nil
end

local function isEditModeTimelineRec(rec)
	if type(rec) ~= "table" then return false end
	local eventInfo = rec.eventInfo
	if type(eventInfo) ~= "table" then return false end
	local source = eventInfo.source
	if isSecretValue(source) then return false end
	if source == EDIT_MODE_SOURCE_ID then
		return true
	end
	return tonumber(source) == EDIT_MODE_SOURCE_ID
end

local function getTimelineBarColor(rec)
	if type(rec) ~= "table" then return nil end
	local eventInfo = rec.eventInfo
	if type(eventInfo) ~= "table" then return nil end

	local indicatorR, indicatorG, indicatorB, indicatorA = getIndicatorBarColor(rec)
	if indicatorR then
		return indicatorR, indicatorG, indicatorB, indicatorA
	end

	-- Native Edit Mode test events are not encounter events, so SetEventColor
	-- does not reliably drive their colors. Resolve them locally.
	if isEditModeTimelineRec(rec) then
		return L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A
	end

	local colorR, colorG, colorB, colorA, colorSecret = unpackColor(eventInfo.color or eventInfo.barColor)
	local fromR, fromG, fromB, fromA, fromSecret = unpackColor(eventInfo.colorFrom)
	local toR, toG, toB, toA, toSecret = unpackColor(eventInfo.colorTo)

	if fromR and toR then
		if fromSecret or toSecret then
			return fromR, fromG, fromB, fromA
		end
		local rawRem = rec.remaining
		if isSecretValue(rawRem) then
			rawRem = nil
		end
		local rem = tonumber(rawRem)
		if isSecretValue(rem) then
			rem = nil
		end
		local window = tonumber(rec._timelineColorStartRemaining)
		if isSecretValue(window) then
			window = nil
		end
		if not window or window <= 0 then
			window = tonumber(L.THRESHOLD_TO_BAR) or 0
		end
		if window > 0 and rem then
			local shown = rem
			if shown < 0 then shown = 0 end
			if shown > window then shown = window end
			local progress = (window - shown) / window
			if progress < 0 then progress = 0 end
			if progress > 1 then progress = 1 end
			local r = (
				fromR + (toR - fromR) * progress
			)
			local g = (
				fromG + (toG - fromG) * progress
			)
			local b = (
				fromB + (toB - fromB) * progress
			)
			local a = (
				fromA + (toA - fromA) * progress
			)
			return r, g, b, a
		end
	end

	if colorR then
		if colorSecret then
			return colorR, colorG, colorB, colorA
		end
		return colorR, colorG, colorB, colorA
	end
	if fromR then
		return fromR, fromG, fromB, fromA
	end
	if toR then
		return toR, toG, toB, toA
	end
	return nil
end

local function colorNear(a, b, tolerance)
	if type(a) ~= "number" or type(b) ~= "number" then
		return false
	end
	return math.abs(a - b) <= (tolerance or 0.01)
end

local function isDefaultBarColor(r, g, b, a)
	local defaultA = L.BAR_FG_A or 1
	return colorNear(r, L.BAR_FG_R, 0.01)
		and colorNear(g, L.BAR_FG_G, 0.01)
		and colorNear(b, L.BAR_FG_B, 0.01)
		and colorNear(a or 1, defaultA, 0.01)
end

local function getIconBorderColor(rec)
	if not L.USE_ICON_BORDER_COLORS then
		return nil
	end
	if rec and rec.isManual then
		return nil
	end
	local r, g, b, a = getTimelineBarColor(rec)
	if not r then
		return nil
	end
	if isDefaultBarColor(r, g, b, a or 1) then
		return nil
	end
	return r, g, b, a or 1
end

local QUEUED_LABEL = "Queued"
local PAUSED_LABEL = "Paused"
local BLOCKED_LABEL = "Blocked"
local BLOCKED_ICON_VERTEX = 0.55
local BLOCKED_BORDER_COLOR = 0.50

function M:ClearBarAnimation(_bar)
	-- No-op: bar values are now driven directly from time-based remaining values.
end

-- =========================
-- Layout
-- =========================
local function sortByRemaining(a, b)
	return (a.remaining or 999999) < (b.remaining or 999999)
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
		if f.indicatorsFrame and f.indicatorsFrame.__indicatorTextures then
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
		else
			local indicatorEventID = rec._indicatorEventID
			if type(indicatorEventID) ~= "number" and type(indicatorEventID) ~= "string" then
				local recIDType = type(rec.id)
				if recIDType == "number" or recIDType == "string" then
					indicatorEventID = rec.id
				end
			end
			M.applyIndicatorsToBarEnd(f, indicatorEventID)
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
	if isSecretValue(remaining) then return end
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

local function getLiveRemaining(rec, now)
	if type(rec) ~= "table" then return nil end
	if type(now) ~= "number" then
		now = (GetTime and GetTime()) or 0
	end

	if rec.isManual and type(rec.endTime) == "number" then
		if isSecretValue(rec.endTime) then
			return nil
		end
		return rec.endTime - now
	end

	local rem = rec.remaining
	if isSecretValue(rem) then
		return nil
	end
	if type(rem) ~= "number" then
		return nil
	end

	if rec.isQueued or rec.isPaused or rec.isBlocked then
		return rem
	end

	local duration = rec.duration
	local startTime = rec.startTime
	if isSecretValue(duration) or isSecretValue(startTime) then
		return nil
	end
	if type(duration) == "number" and duration > 0 and type(startTime) == "number" then
		return duration - (now - startTime)
	end

	return rem
end

local function updateBarCountdownVisual(rec, now)
	local bar = rec and rec.barFrame
	if not bar then
		return false
	end

	local rem = getLiveRemaining(rec, now)
	local isQueued = rec.isQueued and not rec.isManual
	local isPaused = rec.isPaused and not rec.isManual
	local isBlocked = rec.isBlocked and not rec.isManual

	if isQueued then
		bar.sb:SetMinMaxValues(0, L.THRESHOLD_TO_BAR)
		bar.sb:SetValue(0)
		if bar.rt._sbmStatus ~= QUEUED_LABEL then
			bar.rt:SetText(QUEUED_LABEL)
			bar.rt._sbmStatus = QUEUED_LABEL
		end
		return false
	end

	if rec.isManual then
		local dur = rec.duration
		if type(dur) == "number" and dur > 0 then
			bar.sb:SetMinMaxValues(0, dur)
			bar.sb:SetValue(U.clamp(rem or dur, 0, dur))
		else
			bar.sb:SetMinMaxValues(0, L.THRESHOLD_TO_BAR)
			bar.sb:SetValue(U.clamp(rem or 0, 0, L.THRESHOLD_TO_BAR))
		end
		if rem ~= nil then
			bar.rt:SetText(U.formatTimeBar(rem))
		else
			bar.rt:SetText("")
		end
	else
		local shown = U.clamp(rem or L.THRESHOLD_TO_BAR, 0, L.THRESHOLD_TO_BAR)
		bar.sb:SetMinMaxValues(0, L.THRESHOLD_TO_BAR)
		bar.sb:SetValue(shown)
		local prefix = rec.isApproximate and "~" or ""
		bar.rt:SetText(prefix .. U.formatTimeBar(shown))
	end

	if isPaused or isBlocked then
		local status = isPaused and PAUSED_LABEL or BLOCKED_LABEL
		if bar.rt._sbmStatus ~= status then
			bar.rt:SetText(status)
			bar.rt._sbmStatus = status
		end
		return false
	end

	if bar.rt._sbmStatus then
		bar.rt._sbmStatus = nil
	end

	return rem ~= nil
end

local function barCountdownOnUpdate(bar)
	if not bar then return end
	local id = bar.__id
	if not id or not M.events then
		bar:SetScript("OnUpdate", nil)
		return
	end

	local rec = M.events[id]
	if not rec or rec.barFrame ~= bar then
		bar:SetScript("OnUpdate", nil)
		return
	end

	local now = (GetTime and GetTime()) or 0
	local keepUpdating = updateBarCountdownVisual(rec, now)
	if not keepUpdating then
		bar:SetScript("OnUpdate", nil)
	end
end

local function updateIconCountdownVisual(rec, now)
	local f = rec and rec.iconFrame
	if not f then
		return false
	end

	local rem = getLiveRemaining(rec, now)
	local isQueued = rec.isQueued and not rec.isManual
	local isPaused = rec.isPaused and not rec.isManual
	local isBlocked = rec.isBlocked and not rec.isManual

	if isQueued then
		if f.timeText._sbmStatus ~= QUEUED_LABEL then
			f.timeText:SetText(QUEUED_LABEL)
			f.timeText._sbmStatus = QUEUED_LABEL
		end
		f.cd:Clear()
		return false
	end

	if f.timeText._sbmStatus then
		f.timeText._sbmStatus = nil
	end

	if type(rem) == "number" and rem > 0 then
		f.timeText:SetText(U.formatTimeIcon(rem))
		if rec.startTime and rec.duration and rec.duration > 0 and not isPaused and not isBlocked then
			f.cd:SetCooldown(rec.startTime, rec.duration)
		else
			f.cd:Clear()
		end
	else
		f.timeText:SetText("")
		f.cd:Clear()
	end

	return rem ~= nil and not isPaused and not isBlocked
end

local function iconCountdownOnUpdate(icon)
	if not icon then return end
	local id = icon.__id
	if not id or not M.events then
		icon:SetScript("OnUpdate", nil)
		return
	end

	local rec = M.events[id]
	if not rec or rec.iconFrame ~= icon then
		icon:SetScript("OnUpdate", nil)
		return
	end

	local now = (GetTime and GetTime()) or 0
	local keepUpdating = updateIconCountdownVisual(rec, now)
	if not keepUpdating then
		icon:SetScript("OnUpdate", nil)
	end
end

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
end

function M:updateRecord(eventID, eventInfo, remaining)
	if not self.enabled then return end
	local idType = type(eventID)
	if idType ~= "number" and idType ~= "string" then return end

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
	if eventInfo and not isSecretValue(eventInfo.isApproximate) then
		rec.isApproximate = eventInfo.isApproximate == true
	else
		rec.isApproximate = false
	end

	if rec.isManual then
		rec.isQueued = false
		rec.isPaused = false
		rec.isBlocked = false
	end

	local indicatorEventID = nil
	if not rec.isManual and type(rec.eventInfo) == "table" then
		local rawIndicatorEventID = rec.eventInfo.encounterEventID or rec.eventInfo.timelineEventID or rec.eventInfo.eventID or rec.eventInfo.id
		local rawType = type(rawIndicatorEventID)
		if isSecretValue(rawIndicatorEventID) or rawType == "number" or rawType == "string" then
			indicatorEventID = rawIndicatorEventID
		end
	end
	if isSecretValue(rec._indicatorEventID) or isSecretValue(indicatorEventID) then
		rec._indicatorEventID = indicatorEventID
		rec._indicatorDirty = true
	elseif rec._indicatorEventID ~= indicatorEventID then
		rec._indicatorEventID = indicatorEventID
		rec._indicatorDirty = true
	end

	if not rec.isManual and rec.eventInfo and type(rec.eventInfo.icons) == "number" then
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
	else
		if rec._indicatorMask or rec._indicatorMaskSecret then
			rec._indicatorMask = nil
			rec._indicatorMaskSecret = nil
			rec._indicatorDirty = true
		end
	end

	if type(rec.remaining) == "number" then
		updateRecTiming(rec, rec.remaining)
	end

	local wantBar = rec.forceBar
	if not wantBar and type(rec.remaining) == "number" and rec.remaining <= L.THRESHOLD_TO_BAR then
		wantBar = true
	end
	local hadBar = rec.barFrame ~= nil
	local hadIcon = rec.iconFrame ~= nil
	if wantBar then
		self:ensureBar(rec)
	else
		self:ensureIcon(rec)
	end
	if rec.barFrame and not rec.isManual then
		local threshold = tonumber(L.THRESHOLD_TO_BAR) or 0
		if isSecretValue(threshold) then
			threshold = 0
		end

		local rawRemaining = rec.remaining
		if isSecretValue(rawRemaining) then
			rawRemaining = nil
		end
		local remainingNum = tonumber(rawRemaining)
		if isSecretValue(remainingNum) then
			remainingNum = nil
		end

		local startRemaining = rec._timelineColorStartRemaining
		if isSecretValue(startRemaining) then
			startRemaining = nil
		end
		startRemaining = tonumber(startRemaining)

		if not hadBar then
			startRemaining = remainingNum
			if startRemaining and threshold > 0 and startRemaining > threshold then
				startRemaining = threshold
			end
			if not startRemaining or startRemaining <= 0 then
				startRemaining = (threshold > 0) and threshold or nil
			end
		elseif remainingNum and startRemaining and remainingNum > startRemaining then
			startRemaining = remainingNum
			if threshold > 0 and startRemaining > threshold then
				startRemaining = threshold
			end
		elseif (not startRemaining or startRemaining <= 0) and threshold > 0 then
			startRemaining = threshold
		end

		rec._timelineColorStartRemaining = startRemaining
	else
		rec._timelineColorStartRemaining = nil
	end
	if isNew or hadBar ~= (rec.barFrame ~= nil) or hadIcon ~= (rec.iconFrame ~= nil) then
		self._layoutDirty = true
	end

	local nowForVisual = (GetTime and GetTime()) or 0

		if rec.iconFrame then
			local f = rec.iconFrame
			refreshIconTexture(rec)
			local isQueued = rec.isQueued and not rec.isManual
			local isPaused = rec.isPaused and not rec.isManual
			local isBlocked = rec.isBlocked and not rec.isManual
			if f.pauseIcon then
				local size = math.max(10, math.floor((L.ICON_SIZE or 48) * 0.28 + 0.5))
				if f.pauseIcon._sbmSize ~= size then
					f.pauseIcon:SetSize(size, size)
					f.pauseIcon._sbmSize = size
				end
				f.pauseIcon:SetShown(isPaused and not isBlocked)
			end
			if f.blockedIcon then
				local size = math.max(10, math.floor((L.ICON_SIZE or 48) * 0.28 + 0.5))
				if f.blockedIcon._sbmSize ~= size then
					f.blockedIcon:SetSize(size, size)
					f.blockedIcon._sbmSize = size
				end
				f.blockedIcon:SetShown(isBlocked)
			end

			if isBlocked then
				if f.tex.SetDesaturated then
					f.tex:SetDesaturated(true)
				end
				f.tex:SetVertexColor(BLOCKED_ICON_VERTEX, BLOCKED_ICON_VERTEX, BLOCKED_ICON_VERTEX, 1)
				M.ensureFullBorder(f.main, L.ICON_BORDER_THICKNESS, BLOCKED_BORDER_COLOR, BLOCKED_BORDER_COLOR, BLOCKED_BORDER_COLOR, 1)
			else
				if f.tex.SetDesaturated then
					f.tex:SetDesaturated(false)
				end
				f.tex:SetVertexColor(1, 1, 1, 1)
				local borderR, borderG, borderB, borderA = getIconBorderColor(rec)
				if borderR then
					M.ensureFullBorder(f.main, L.ICON_BORDER_THICKNESS, borderR, borderG, borderB, borderA)
				else
					M.ensureFullBorder(f.main, L.ICON_BORDER_THICKNESS, 0, 0, 0, 1)
				end
			end

			local keepUpdating = updateIconCountdownVisual(rec, nowForVisual)
			if keepUpdating then
				if f:GetScript("OnUpdate") ~= iconCountdownOnUpdate then
					f:SetScript("OnUpdate", iconCountdownOnUpdate)
				end
			elseif f:GetScript("OnUpdate") then
				f:SetScript("OnUpdate", nil)
			end

		if rec.isManual then
			-- no secure timeline indicators for manual timers
		else
			if rec._indicatorDirty or not rec._indicatorAppliedIcon then
				local eventIDForIndicators = rec._indicatorEventID
				if type(eventIDForIndicators) ~= "number" and type(eventIDForIndicators) ~= "string" then
					local recIDType = type(rec.id)
					if recIDType == "number" or recIDType == "string" then
						eventIDForIndicators = rec.id
					end
				end
				M.applyIndicatorsToIconFrame(f, eventIDForIndicators)
				rec._indicatorAppliedIcon = true
				rec._indicatorDirty = false
			end
		end
	end

		if rec.barFrame then
			refreshBarLabelAndIcon(rec)
			local r, g, b, a = nil, nil, nil, nil
			if not rec.isManual then
				r, g, b, a = getTimelineBarColor(rec)
			end
			local appliedR, appliedG, appliedB, appliedA
			if r then
				appliedR, appliedG, appliedB, appliedA = r, g, b, a or 1
			else
				appliedR, appliedG, appliedB, appliedA = L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A
			end
			M.setBarFillFlat(rec.barFrame, appliedR, appliedG, appliedB, appliedA)
			local bar = rec.barFrame
			local keepUpdating = updateBarCountdownVisual(rec, nowForVisual)
			if keepUpdating then
				if bar:GetScript("OnUpdate") ~= barCountdownOnUpdate then
					bar:SetScript("OnUpdate", barCountdownOnUpdate)
				end
			elseif bar:GetScript("OnUpdate") then
				bar:SetScript("OnUpdate", nil)
			end

		if rec.isManual then
			-- no secure timeline indicators for manual timers
		else
			if rec._indicatorDirty or not rec._indicatorAppliedBar then
				local eventIDForIndicators = rec._indicatorEventID
				if type(eventIDForIndicators) ~= "number" and type(eventIDForIndicators) ~= "string" then
					local recIDType = type(rec.id)
					if recIDType == "number" or recIDType == "string" then
						eventIDForIndicators = rec.id
					end
				end
				M.applyIndicatorsToBarEnd(rec.barFrame, eventIDForIndicators)
				rec._indicatorAppliedBar = true
				rec._indicatorDirty = false
			end
		end
	end
end

function M:Tick()
	if not self.enabled then return end
	if self._testTicker then return end
	if self.UpdatePrivateAuraFrames then
		self:UpdatePrivateAuraFrames()
	end

	local now = (GetTime and GetTime()) or 0
	local suppressUntil = self._suppressTimelineUntil
	if suppressUntil then
		if now < suppressUntil then
			return
		end
		self._suppressTimelineUntil = nil
	end
	local sourceEvents = self.CollectTimelineEvents and self:CollectTimelineEvents(now) or nil

	local seen = self._seenEvents
	if not seen then
		seen = {}
		self._seenEvents = seen
	else
		wipe(seen)
	end
	if type(sourceEvents) == "table" then
		for _, entry in ipairs(sourceEvents) do
			local eventID = entry and entry.id
			local idType = type(eventID)
			if idType == "number" or idType == "string" then
				seen[eventID] = true

				local rec = self.events[eventID]
				if not rec then
					rec = { id = eventID }
					self.events[eventID] = rec
					self._layoutDirty = true
				end

				rec.forceBar = entry.forceBar and true or false
				rec.isQueued = entry.isQueued and true or false
				rec.isPaused = entry.isPaused and true or false
				rec.isBlocked = entry.isBlocked and true or false
				self:updateRecord(eventID, entry.eventInfo, entry.remaining)
			end
		end
	end

	for id in pairs(self.events) do
		local rec = self.events[id]
		if rec and rec.isManual then
			local rem
			if rec.endTime then
				rem = rec.endTime - now
			else
				rem = rec.remaining
			end
			if type(rem) == "number" and rem <= 0 then
				self:removeEvent(id)
			else
				rec.remaining = rem
				self:updateRecord(id, rec.eventInfo, rem)
			end
		elseif not seen[id] then
			self:removeEvent(id)
		end
	end

	if self._layoutDirty then
		self:LayoutAll()
	end
end

C_Timer.NewTicker(C.TICK_INTERVAL, function() M:Tick() end)
