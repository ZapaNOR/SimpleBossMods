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
local Enum_EncounterTimelineEventState = Enum and Enum.EncounterTimelineEventState
local EDIT_MODE_SOURCE_ID = (Enum_EncounterTimelineEventSource and Enum_EncounterTimelineEventSource.EditMode) or 2
local EVENT_STATE_FINISHED = Enum_EncounterTimelineEventState and Enum_EncounterTimelineEventState.Finished
local EVENT_STATE_CANCELED = Enum_EncounterTimelineEventState and Enum_EncounterTimelineEventState.Canceled

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

local BAR_OUTRO_KIND_FINISH = "finish"
local BAR_OUTRO_KIND_CANCEL = "cancel"

local BAR_CANCEL_ANIMATION_DURATION = 0.35
local BAR_CANCEL_ANIMATION_FADE_DURATION = 0.30
local BAR_FINISH_ANIMATION_DURATION = 0.35
local BAR_FINISH_ANIMATION_FADE_DURATION = 0.30
local BAR_FINISH_ANIMATION_MOVE_DURATION = 0.40
local BAR_FINISH_ANIMATION_MOVE_DISTANCE = -80

local function saturate(value)
	return U.clamp(tonumber(value) or 0, 0, 1)
end

local function evaluateInCubic(progress)
	if EasingUtil and EasingUtil.InCubic then
		return EasingUtil.InCubic(progress)
	end
	progress = saturate(progress)
	return progress * progress * progress
end

local function evaluateInBack(progress)
	if EasingUtil and EasingUtil.InBack then
		return EasingUtil.InBack(progress)
	end
	progress = saturate(progress)
	local c1 = 1.70158
	local c3 = c1 + 1
	return c3 * progress * progress * progress - c1 * progress * progress
end

local function lerp(a, b, progress)
	return a + ((b - a) * progress)
end

local function barsAnimationEnabled()
	return L.ANIMATE_BARS ~= false
end

local function iconsAnimationEnabled()
	return L.ANIMATE_ICONS ~= false
end

local function finishBarOutro(bar)
	if M and M.releaseBar then
		M.releaseBar(bar)
	else
		bar:SetScript("OnUpdate", nil)
		bar:Hide()
	end
end

local function barOutroOnUpdate(bar, elapsed)
	local data = bar and bar.__sbmBarOutro
	if not data then
		if bar then
			bar:SetScript("OnUpdate", nil)
		end
		return
	end
	if not barsAnimationEnabled() then
		local owner = data.owner
		if owner and owner.ClearBarAnimation then
			owner:ClearBarAnimation(bar, false)
		end
		finishBarOutro(bar)
		return
	end

	data.elapsed = data.elapsed + (elapsed or 0)
	local elapsedTime = data.elapsed

	local alphaProgress = saturate(elapsedTime / data.fadeDuration)
	local alphaValue = 1 - evaluateInCubic(alphaProgress)
	bar:SetAlpha((data.startAlpha or 1) * alphaValue)

	if data.moveDuration and data.moveDuration > 0 and data.moveDistance and data.moveDistance ~= 0 then
		local moveProgress = saturate(elapsedTime / data.moveDuration)
		local moveOffset = lerp(0, data.moveDistance, evaluateInBack(moveProgress))
		bar:ClearAllPoints()
		bar:SetPoint(data.point, data.relativeTo, data.relativePoint, data.x + moveOffset, data.y)
	end

	if elapsedTime >= data.duration then
		local owner = data.owner
		if owner and owner.ClearBarAnimation then
			-- Natural outro completion should not reset alpha/position before release.
			owner:ClearBarAnimation(bar, false)
		end
		finishBarOutro(bar)
	end
end

function M:HasDetachedBarOutros()
	return (self._barOutroCount or 0) > 0
end

function M:HasDetachedIconOutros()
	return (self._iconOutroCount or 0) > 0
end

local function requestDeferredLayout(owner)
	if not owner or owner._layoutFlushPending then
		return
	end
	owner._layoutFlushPending = true
	C_Timer.After(0, function()
		owner._layoutFlushPending = nil
		if owner._layoutDirty
			and not owner:HasDetachedBarOutros()
			and not owner:HasDetachedIconOutros() then
			owner:LayoutAll()
		end
	end)
end

function M:ClearBarAnimation(bar, resetVisual)
	if not bar then return end

	local data = bar.__sbmBarOutro
	if not data then
		return
	end

	bar.__sbmBarOutro = nil
	bar:SetScript("OnUpdate", nil)
	if resetVisual ~= false then
		bar:SetAlpha(data.startAlpha or 1)
		bar:ClearAllPoints()
		bar:SetPoint(data.point, data.relativeTo, data.relativePoint, data.x, data.y)
	end

	local outroFrames = self._barOutroFrames
	if outroFrames and outroFrames[bar] then
		outroFrames[bar] = nil
		self._barOutroCount = math.max((self._barOutroCount or 1) - 1, 0)
		if self._barOutroCount == 0 and self._layoutDirty then
			requestDeferredLayout(self)
		end
	end
end

local function getRecordRemainingForOutro(rec)
	if type(rec) ~= "table" then
		return nil
	end

	local rem = rec.remaining
	if isSecretValue(rem) then
		rem = nil
	end
	rem = tonumber(rem)

	if rec.isQueued or rec.isPaused or rec.isBlocked then
		return rem
	end

	local duration = rec.duration
	local startTime = rec.startTime
	if not isSecretValue(duration) and not isSecretValue(startTime) then
		duration = tonumber(duration)
		startTime = tonumber(startTime)
		if type(duration) == "number" and duration > 0 and type(startTime) == "number" then
			local now = (GetTime and GetTime()) or 0
			return duration - (now - startTime)
		end
	end

	return rem
end

function M:GetTimelineBarOutroKind(rec, _reason)
	return BAR_OUTRO_KIND_FINISH
end

function M:PlayTimelineBarOutro(rec, outroKind)
	local bar = rec and rec.barFrame
	if not bar or not bar:IsShown() then
		return false
	end
	if not barsAnimationEnabled() then
		return false
	end

	local point, relativeTo, relativePoint, x, y = bar:GetPoint(1)
	if not point or not relativePoint then
		return false
	end

	self:StopBarLayoutMotion(bar, false)
	self:StopBarFadeIn(bar, false)
	self:ClearBarAnimation(bar)

	local duration = BAR_CANCEL_ANIMATION_DURATION
	local fadeDuration = BAR_CANCEL_ANIMATION_FADE_DURATION
	local moveDuration = nil
	local moveDistance = nil

	if outroKind == BAR_OUTRO_KIND_FINISH then
		duration = BAR_FINISH_ANIMATION_DURATION
		fadeDuration = BAR_FINISH_ANIMATION_FADE_DURATION
		moveDuration = BAR_FINISH_ANIMATION_MOVE_DURATION
		moveDistance = BAR_FINISH_ANIMATION_MOVE_DISTANCE
		if L.BAR_FILL_REVERSE then
			moveDistance = moveDistance * -1
		end
	end

	bar.__sbmBarOutro = {
		owner = self,
		duration = duration,
		elapsed = 0,
		fadeDuration = fadeDuration,
		moveDuration = moveDuration,
		moveDistance = moveDistance,
		point = point,
		relativeTo = relativeTo,
		relativePoint = relativePoint,
		x = x,
		y = y,
		startAlpha = bar:GetAlpha(),
	}

	local outroFrames = self._barOutroFrames
	if not outroFrames then
		outroFrames = {}
		self._barOutroFrames = outroFrames
	end
	if not outroFrames[bar] then
		outroFrames[bar] = true
		self._barOutroCount = (self._barOutroCount or 0) + 1
	end

	bar:SetScript("OnUpdate", barOutroOnUpdate)
	return true
end

-- =========================
-- Layout
-- =========================
local function sortByRemaining(a, b)
	return (a.remaining or 999999) < (b.remaining or 999999)
end

local BAR_LAYOUT_MOVE_RATE = 14
local BAR_LAYOUT_SNAP_DISTANCE = 0.75
local BAR_LAYOUT_ENTRY_OFFSET_FACTOR = 0.35
local BAR_LAYOUT_FADE_IN_DURATION = 0.18

local function setBarLayoutPoint(bar, point, offsetY)
	bar:ClearAllPoints()
	bar:SetPoint(point, frames.barsParent, point, 0, offsetY)
	bar.__sbmLayoutPoint = point
	bar.__sbmLayoutY = offsetY
	bar.__sbmLayoutTargetY = offsetY
end

local function stopBarFadeIn(owner, bar, setOpaque)
	if not bar then
		return
	end

	local fadeBars = owner and owner._barLayoutFadeInBars
	if fadeBars then
		fadeBars[bar] = nil
	end
	bar.__sbmFadeInElapsed = nil
	if setOpaque then
		bar:SetAlpha(1)
	end
end

local function startBarFadeIn(owner, bar)
	if not owner or not bar then
		return
	end
	if not barsAnimationEnabled() then
		bar:SetAlpha(1)
		return
	end

	stopBarFadeIn(owner, bar, false)

	local fadeBars = owner._barLayoutFadeInBars
	if not fadeBars then
		fadeBars = {}
		owner._barLayoutFadeInBars = fadeBars
	end

	bar.__sbmFadeInElapsed = 0
	bar:SetAlpha(0)
	fadeBars[bar] = true
end

local function ensureBarLayoutMotionDriver(owner)
	local driver = owner._barLayoutMotionDriver
	if driver then
		return driver
	end

	driver = CreateFrame("Frame")
	driver:Hide()
	driver:SetScript("OnUpdate", function(_, elapsed)
		local movingBars = owner._barLayoutMovingBars
		local fadeBars = owner._barLayoutFadeInBars
		local hasMovingBars = movingBars and next(movingBars) ~= nil
		local hasFadingBars = fadeBars and next(fadeBars) ~= nil
		if not hasMovingBars and not hasFadingBars then
			driver:Hide()
			return
		end
		if not barsAnimationEnabled() then
			if hasMovingBars then
				for bar in pairs(movingBars) do
					local point = bar and bar.__sbmLayoutPoint
					local targetY = bar and tonumber(bar.__sbmLayoutTargetY)
					if bar and bar:IsShown() and point and type(targetY) == "number" then
						setBarLayoutPoint(bar, point, targetY)
					end
					movingBars[bar] = nil
				end
			end
			if hasFadingBars then
				for bar in pairs(fadeBars) do
					if bar and bar:IsShown() then
						bar:SetAlpha(1)
					end
					fadeBars[bar] = nil
				end
			end
			driver:Hide()
			return
		end

		local layoutLocked = owner.HasDetachedBarOutros and owner:HasDetachedBarOutros()

		if hasMovingBars and not layoutLocked then
			local progress = saturate((elapsed or 0) * BAR_LAYOUT_MOVE_RATE)
			if progress > 0 then
				for bar in pairs(movingBars) do
					if not bar or not bar:IsShown() then
						movingBars[bar] = nil
					else
						local point = bar.__sbmLayoutPoint
						local targetY = tonumber(bar.__sbmLayoutTargetY)
						local currentY = tonumber(bar.__sbmLayoutY)
						if not point or type(targetY) ~= "number" then
							movingBars[bar] = nil
						else
							if type(currentY) ~= "number" then
								currentY = targetY
							end
							local nextY = lerp(currentY, targetY, progress)
							if math.abs(nextY - targetY) <= BAR_LAYOUT_SNAP_DISTANCE then
								nextY = targetY
								movingBars[bar] = nil
							end

							bar.__sbmLayoutY = nextY
							bar:ClearAllPoints()
							bar:SetPoint(point, frames.barsParent, point, 0, nextY)
						end
					end
				end
			end
		end

		if hasFadingBars then
			local fadeProgress = saturate((elapsed or 0) / BAR_LAYOUT_FADE_IN_DURATION)
			if fadeProgress > 0 then
				for bar in pairs(fadeBars) do
					if not bar or not bar:IsShown() then
						fadeBars[bar] = nil
					else
						local alpha = bar:GetAlpha()
						local nextAlpha = lerp(alpha, 1, fadeProgress)
						if nextAlpha >= 0.995 then
							nextAlpha = 1
							fadeBars[bar] = nil
							bar.__sbmFadeInElapsed = nil
						else
							bar.__sbmFadeInElapsed = (bar.__sbmFadeInElapsed or 0) + (elapsed or 0)
						end
						bar:SetAlpha(nextAlpha)
					end
				end
			end
		end

		local stillMoving = movingBars and next(movingBars) ~= nil
		local stillFading = fadeBars and next(fadeBars) ~= nil
		if not stillMoving and not stillFading then
			driver:Hide()
		end
	end)

	owner._barLayoutMotionDriver = driver
	return driver
end

function M:StopBarFadeIn(bar, setOpaque)
	stopBarFadeIn(self, bar, setOpaque)
	local movingBars = self._barLayoutMovingBars
	local fadeBars = self._barLayoutFadeInBars
	if (not movingBars or not next(movingBars)) and (not fadeBars or not next(fadeBars)) and self._barLayoutMotionDriver then
		self._barLayoutMotionDriver:Hide()
	end
end

function M:StopBarLayoutMotion(bar, snapToTarget)
	if not bar then
		return
	end

	local movingBars = self._barLayoutMovingBars
	if movingBars then
		movingBars[bar] = nil
		local fadeBars = self._barLayoutFadeInBars
		if not next(movingBars) and (not fadeBars or not next(fadeBars)) and self._barLayoutMotionDriver then
			self._barLayoutMotionDriver:Hide()
		end
	end

	if snapToTarget then
		local point = bar.__sbmLayoutPoint
		local targetY = tonumber(bar.__sbmLayoutTargetY)
		if point and type(targetY) == "number" then
			setBarLayoutPoint(bar, point, targetY)
		end
	end
end

function M:SetBarLayoutTarget(bar, point, offsetY, animate)
	if not bar or not point then
		return
	end

	local doAnimate = animate and barsAnimationEnabled()
	local targetY = tonumber(offsetY) or 0
	bar.__sbmLayoutPoint = point
	bar.__sbmLayoutTargetY = targetY

	local currentY = tonumber(bar.__sbmLayoutY)
	local isNewBarPosition = type(currentY) ~= "number"
	if isNewBarPosition and bar:IsShown() and doAnimate then
		startBarFadeIn(self, bar)
		local driver = ensureBarLayoutMotionDriver(self)
		driver:Show()
	elseif isNewBarPosition and bar:IsShown() then
		self:StopBarFadeIn(bar, true)
	end

	local hasMovingBars = self._barLayoutMovingBars and next(self._barLayoutMovingBars) ~= nil
	local hasDetachedBarOutros = self.HasDetachedBarOutros and self:HasDetachedBarOutros()
	if isNewBarPosition and doAnimate and bar:IsShown() and hasMovingBars and not hasDetachedBarOutros then
		local spawnOffset = ((tonumber(L.BAR_HEIGHT) or 0) + (tonumber(L.GAP) or 0)) * BAR_LAYOUT_ENTRY_OFFSET_FACTOR
		if spawnOffset <= 0 then
			spawnOffset = 1
		end
		local spawnY = targetY + spawnOffset
		setBarLayoutPoint(bar, point, spawnY)
		currentY = spawnY
	end

	if not doAnimate or not bar:IsShown() or type(currentY) ~= "number" then
		self:StopBarLayoutMotion(bar, false)
		setBarLayoutPoint(bar, point, targetY)
		return
	end

	if math.abs(currentY - targetY) <= BAR_LAYOUT_SNAP_DISTANCE then
		self:StopBarLayoutMotion(bar, false)
		setBarLayoutPoint(bar, point, targetY)
		return
	end

	local movingBars = self._barLayoutMovingBars
	if not movingBars then
		movingBars = {}
		self._barLayoutMovingBars = movingBars
	end
	movingBars[bar] = true

	local driver = ensureBarLayoutMotionDriver(self)
	driver:Show()
end

local ICON_LAYOUT_MOVE_RATE = 14
local ICON_LAYOUT_SNAP_DISTANCE = 0.75
local ICON_FADE_IN_DURATION = 0.14
local ICON_OUTRO_FADE_DURATION = 0.20

local function setIconLayoutPoint(icon, point, offsetX, offsetY)
	icon:ClearAllPoints()
	icon:SetPoint(point, frames.iconsParent, point, offsetX, offsetY)
	icon.__sbmIconLayoutPoint = point
	icon.__sbmIconLayoutX = offsetX
	icon.__sbmIconLayoutY = offsetY
	icon.__sbmIconLayoutTargetX = offsetX
	icon.__sbmIconLayoutTargetY = offsetY
end

local function stopIconFadeIn(owner, icon, setOpaque)
	if not icon then
		return
	end

	local fadeIcons = owner and owner._iconLayoutFadeInIcons
	if fadeIcons then
		fadeIcons[icon] = nil
	end
	if setOpaque then
		icon:SetAlpha(1)
	end
end

local function stopIconOutro(owner, icon, setOpaque)
	if not icon then
		return
	end

	local outroIcons = owner and owner._iconOutroIcons
	if outroIcons and outroIcons[icon] then
		outroIcons[icon] = nil
		owner._iconOutroCount = math.max((owner._iconOutroCount or 1) - 1, 0)
		if owner._iconOutroCount == 0 and owner._layoutDirty then
			requestDeferredLayout(owner)
		end
	end
	icon.__sbmIconOutro = nil
	if setOpaque then
		icon:SetAlpha(1)
	end
end

local function startIconFadeIn(owner, icon)
	if not owner or not icon then
		return
	end
	if not iconsAnimationEnabled() then
		icon:SetAlpha(1)
		return
	end

	stopIconFadeIn(owner, icon, false)
	local fadeIcons = owner._iconLayoutFadeInIcons
	if not fadeIcons then
		fadeIcons = {}
		owner._iconLayoutFadeInIcons = fadeIcons
	end

	icon:SetAlpha(0)
	fadeIcons[icon] = true
end

local function finishIconOutro(icon)
	if M and M.releaseIcon then
		M.releaseIcon(icon)
	else
		icon:Hide()
	end
end

local function ensureIconLayoutMotionDriver(owner)
	local driver = owner._iconLayoutMotionDriver
	if driver then
		return driver
	end

	driver = CreateFrame("Frame")
	driver:Hide()
	driver:SetScript("OnUpdate", function(_, elapsed)
		local moveIcons = owner._iconLayoutMovingIcons
		local fadeInIcons = owner._iconLayoutFadeInIcons
		local outroIcons = owner._iconOutroIcons
		local hasMove = moveIcons and next(moveIcons) ~= nil
		local hasFadeIn = fadeInIcons and next(fadeInIcons) ~= nil
		local hasOutro = outroIcons and next(outroIcons) ~= nil
		if not hasMove and not hasFadeIn and not hasOutro then
			driver:Hide()
			return
		end
		if not iconsAnimationEnabled() then
			if hasMove then
				for icon in pairs(moveIcons) do
					local point = icon and icon.__sbmIconLayoutPoint
					local targetX = icon and tonumber(icon.__sbmIconLayoutTargetX)
					local targetY = icon and tonumber(icon.__sbmIconLayoutTargetY)
					if icon and icon:IsShown() and point and type(targetX) == "number" and type(targetY) == "number" then
						setIconLayoutPoint(icon, point, targetX, targetY)
					end
					moveIcons[icon] = nil
				end
			end
			if hasFadeIn then
				for icon in pairs(fadeInIcons) do
					if icon and icon:IsShown() then
						icon:SetAlpha(1)
					end
					fadeInIcons[icon] = nil
				end
			end
			if hasOutro then
				for icon in pairs(outroIcons) do
					stopIconOutro(owner, icon, false)
					if icon then
						finishIconOutro(icon)
					end
				end
			end
			driver:Hide()
			return
		end

		local layoutLocked = owner.HasDetachedIconOutros and owner:HasDetachedIconOutros()
		if hasMove and not layoutLocked then
			local progress = saturate((elapsed or 0) * ICON_LAYOUT_MOVE_RATE)
			if progress > 0 then
				for icon in pairs(moveIcons) do
					if not icon or not icon:IsShown() then
						moveIcons[icon] = nil
					else
						local point = icon.__sbmIconLayoutPoint
						local targetX = tonumber(icon.__sbmIconLayoutTargetX)
						local targetY = tonumber(icon.__sbmIconLayoutTargetY)
						local currentX = tonumber(icon.__sbmIconLayoutX)
						local currentY = tonumber(icon.__sbmIconLayoutY)
						if not point or type(targetX) ~= "number" or type(targetY) ~= "number" then
							moveIcons[icon] = nil
						else
							if type(currentX) ~= "number" then currentX = targetX end
							if type(currentY) ~= "number" then currentY = targetY end

							local nextX = lerp(currentX, targetX, progress)
							local nextY = lerp(currentY, targetY, progress)
							if math.abs(nextX - targetX) <= ICON_LAYOUT_SNAP_DISTANCE
								and math.abs(nextY - targetY) <= ICON_LAYOUT_SNAP_DISTANCE then
								nextX = targetX
								nextY = targetY
								moveIcons[icon] = nil
							end

							icon.__sbmIconLayoutX = nextX
							icon.__sbmIconLayoutY = nextY
							icon:ClearAllPoints()
							icon:SetPoint(point, frames.iconsParent, point, nextX, nextY)
						end
					end
				end
			end
		end

		if hasFadeIn then
			local fadeProgress = saturate((elapsed or 0) / ICON_FADE_IN_DURATION)
			if fadeProgress > 0 then
				for icon in pairs(fadeInIcons) do
					if not icon or not icon:IsShown() then
						fadeInIcons[icon] = nil
					else
						local nextAlpha = lerp(icon:GetAlpha(), 1, fadeProgress)
						if nextAlpha >= 0.995 then
							nextAlpha = 1
							fadeInIcons[icon] = nil
						end
						icon:SetAlpha(nextAlpha)
					end
				end
			end
		end

		if hasOutro then
			local fadeProgress = saturate((elapsed or 0) / ICON_OUTRO_FADE_DURATION)
			if fadeProgress > 0 then
				for icon in pairs(outroIcons) do
					local data = icon and icon.__sbmIconOutro
					if not icon or not data then
						stopIconOutro(owner, icon, false)
					else
						local nextAlpha = lerp(icon:GetAlpha(), 0, fadeProgress)
						if nextAlpha <= 0.005 then
							nextAlpha = 0
							stopIconOutro(owner, icon, false)
							finishIconOutro(icon)
						else
							icon:SetAlpha(nextAlpha)
						end
					end
				end
			end
		end

		local stillMove = moveIcons and next(moveIcons) ~= nil
		local stillFadeIn = fadeInIcons and next(fadeInIcons) ~= nil
		local stillOutro = outroIcons and next(outroIcons) ~= nil
		if not stillMove and not stillFadeIn and not stillOutro then
			driver:Hide()
		end
	end)

	owner._iconLayoutMotionDriver = driver
	return driver
end

function M:StopIconFadeIn(icon, setOpaque)
	stopIconFadeIn(self, icon, setOpaque)
	local moveIcons = self._iconLayoutMovingIcons
	local fadeInIcons = self._iconLayoutFadeInIcons
	local outroIcons = self._iconOutroIcons
	if (not moveIcons or not next(moveIcons))
		and (not fadeInIcons or not next(fadeInIcons))
		and (not outroIcons or not next(outroIcons))
		and self._iconLayoutMotionDriver then
		self._iconLayoutMotionDriver:Hide()
	end
end

function M:StopIconLayoutMotion(icon, snapToTarget)
	if not icon then
		return
	end

	local moveIcons = self._iconLayoutMovingIcons
	if moveIcons then
		moveIcons[icon] = nil
	end

	if snapToTarget then
		local point = icon.__sbmIconLayoutPoint
		local targetX = tonumber(icon.__sbmIconLayoutTargetX)
		local targetY = tonumber(icon.__sbmIconLayoutTargetY)
		if point and type(targetX) == "number" and type(targetY) == "number" then
			setIconLayoutPoint(icon, point, targetX, targetY)
		end
	end

	local fadeInIcons = self._iconLayoutFadeInIcons
	local outroIcons = self._iconOutroIcons
	if (not moveIcons or not next(moveIcons))
		and (not fadeInIcons or not next(fadeInIcons))
		and (not outroIcons or not next(outroIcons))
		and self._iconLayoutMotionDriver then
		self._iconLayoutMotionDriver:Hide()
	end
end

function M:SetIconLayoutTarget(icon, point, offsetX, offsetY, animate)
	if not icon or not point then
		return
	end

	local doAnimate = animate and iconsAnimationEnabled()
	local targetX = tonumber(offsetX) or 0
	local targetY = tonumber(offsetY) or 0
	icon.__sbmIconLayoutPoint = point
	icon.__sbmIconLayoutTargetX = targetX
	icon.__sbmIconLayoutTargetY = targetY

	local currentX = tonumber(icon.__sbmIconLayoutX)
	local currentY = tonumber(icon.__sbmIconLayoutY)
	local isNew = type(currentX) ~= "number" or type(currentY) ~= "number"
	if isNew and icon:IsShown() and doAnimate then
		startIconFadeIn(self, icon)
	elseif isNew and icon:IsShown() then
		self:StopIconFadeIn(icon, true)
	end

	if not doAnimate or not icon:IsShown() or isNew then
		self:StopIconLayoutMotion(icon, false)
		setIconLayoutPoint(icon, point, targetX, targetY)
		if isNew and doAnimate then
			local driver = ensureIconLayoutMotionDriver(self)
			driver:Show()
		end
		return
	end

	if math.abs(currentX - targetX) <= ICON_LAYOUT_SNAP_DISTANCE
		and math.abs(currentY - targetY) <= ICON_LAYOUT_SNAP_DISTANCE then
		self:StopIconLayoutMotion(icon, false)
		setIconLayoutPoint(icon, point, targetX, targetY)
		return
	end

	local moveIcons = self._iconLayoutMovingIcons
	if not moveIcons then
		moveIcons = {}
		self._iconLayoutMovingIcons = moveIcons
	end
	moveIcons[icon] = true

	local driver = ensureIconLayoutMotionDriver(self)
	driver:Show()
end

function M:ClearIconAnimation(icon, resetVisual)
	if not icon then
		return
	end

	stopIconOutro(self, icon, resetVisual ~= false)
end

function M:PlayTimelineIconOutro(rec)
	local icon = rec and rec.iconFrame
	if not icon or not icon:IsShown() then
		return false
	end
	if not iconsAnimationEnabled() then
		return false
	end

	self:StopIconLayoutMotion(icon, false)
	self:StopIconFadeIn(icon, false)
	self:ClearIconAnimation(icon)

	local outroIcons = self._iconOutroIcons
	if not outroIcons then
		outroIcons = {}
		self._iconOutroIcons = outroIcons
	end
	if not outroIcons[icon] then
		outroIcons[icon] = true
		self._iconOutroCount = (self._iconOutroCount or 0) + 1
	end
	icon.__sbmIconOutro = { owner = self }

	local driver = ensureIconLayoutMotionDriver(self)
	driver:Show()
	return true
end

function M:ClearTimelineAnimationState()
	local barOutros = self._barOutroFrames
	if barOutros and next(barOutros) then
		local pendingBars = {}
		for bar in pairs(barOutros) do
			pendingBars[#pendingBars + 1] = bar
		end
		for _, bar in ipairs(pendingBars) do
			M.releaseBar(bar)
		end
	end

	local iconOutros = self._iconOutroIcons
	if iconOutros and next(iconOutros) then
		local pendingIcons = {}
		for icon in pairs(iconOutros) do
			pendingIcons[#pendingIcons + 1] = icon
		end
		for _, icon in ipairs(pendingIcons) do
			M.releaseIcon(icon)
		end
	end

	for _, rec in pairs(self.events or {}) do
		local bar = rec and rec.barFrame
		if bar then
			self:ClearBarAnimation(bar, true)
			self:StopBarFadeIn(bar, true)
			self:StopBarLayoutMotion(bar, true)
		end
		local icon = rec and rec.iconFrame
		if icon then
			self:ClearIconAnimation(icon, true)
			self:StopIconFadeIn(icon, true)
			self:StopIconLayoutMotion(icon, true)
		end
	end

	if self._barLayoutMovingBars then
		wipe(self._barLayoutMovingBars)
	end
	if self._barLayoutFadeInBars then
		wipe(self._barLayoutFadeInBars)
	end
	if self._iconLayoutMovingIcons then
		wipe(self._iconLayoutMovingIcons)
	end
	if self._iconLayoutFadeInIcons then
		wipe(self._iconLayoutFadeInIcons)
	end

	if self._barLayoutMotionDriver then
		self._barLayoutMotionDriver:Hide()
	end
	if self._iconLayoutMotionDriver then
		self._iconLayoutMotionDriver:Hide()
	end
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
				self:StopIconLayoutMotion(rec.iconFrame, false)
				self:StopIconFadeIn(rec.iconFrame, true)
				self:ClearIconAnimation(rec.iconFrame)
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

			self:SetIconLayoutTarget(f, point, x, y, true)
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

			local point
			local targetY
			if L.BAR_GROW_DIR == "DOWN" then
				point = "TOPLEFT"
				targetY = -y
			else
				point = "BOTTOMLEFT"
				targetY = y
			end
			self:SetBarLayoutTarget(f, point, targetY, true)
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
function M:removeEvent(eventID, reason, immediate)
	local rec = self.events[eventID]
	if not rec then return end
	if rec.countdownTimer and rec.countdownTimer.Cancel then
		rec.countdownTimer:Cancel()
	end
	rec.countdownTimer = nil
	if rec.isManual and rec.kind and self.ClearManualTimerState then
		self:ClearManualTimerState(rec.kind)
	end

	local doImmediate = immediate == true
	local didPlayBarOutro = false
	if not doImmediate and not rec.isManual and rec.barFrame then
		local outroKind = self:GetTimelineBarOutroKind(rec, reason)
		didPlayBarOutro = self:PlayTimelineBarOutro(rec, outroKind)
	end
	local didPlayIconOutro = false
	if not doImmediate and not rec.isManual and rec.iconFrame then
		didPlayIconOutro = self:PlayTimelineIconOutro(rec)
	end

	if not didPlayIconOutro then
		M.releaseIcon(rec.iconFrame)
	end
	if not didPlayBarOutro then
		M.releaseBar(rec.barFrame)
	end

	local terminalStates = self._timelineTerminalStateByID
	if terminalStates then
		terminalStates[eventID] = nil
	end

	self.events[eventID] = nil
	self._layoutDirty = true
end

function M:clearAll(immediate)
	local doImmediate = immediate ~= false
	for id in pairs(self.events) do
		self:removeEvent(id, "clear-all", doImmediate)
	end

	local terminalStates = self._timelineTerminalStateByID
	if terminalStates then
		wipe(terminalStates)
	end

		if doImmediate then
			local barOutros = self._barOutroFrames
			if barOutros and next(barOutros) then
				local pending = {}
				for bar in pairs(barOutros) do
					pending[#pending + 1] = bar
				end
				for _, bar in ipairs(pending) do
					M.releaseBar(bar)
				end
			end
			local iconOutros = self._iconOutroIcons
			if iconOutros and next(iconOutros) then
				local pendingIcons = {}
				for icon in pairs(iconOutros) do
					pendingIcons[#pendingIcons + 1] = icon
				end
				for _, icon in ipairs(pendingIcons) do
					M.releaseIcon(icon)
				end
			end
			self:LayoutAll()
		end
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
				self:removeEvent(id, "manual-expired", true)
			else
				rec.remaining = rem
				self:updateRecord(id, rec.eventInfo, rem)
			end
		elseif not seen[id] then
			self:removeEvent(id, "timeline-missing", false)
		end
	end

	if self._layoutDirty then
		if not self:HasDetachedBarOutros() and not self:HasDetachedIconOutros() then
			self:LayoutAll()
		end
	end
end

C_Timer.NewTicker(C.TICK_INTERVAL, function() M:Tick() end)
