-- SimpleBossMods UI helpers: frames, borders, indicators, pools.

local ADDON_NAME = ...
local M = _G[ADDON_NAME]
if not M then return end

local C = M.Const
local L = M.Live
local U = M.Util

-- =========================
-- UI Roots
-- =========================
local frames = M.frames or {}
M.frames = frames

local anchor = CreateFrame("Frame", ADDON_NAME .. "_Anchor", UIParent)
anchor:SetSize(1, 1)
anchor:SetPoint("CENTER", UIParent, "CENTER", SimpleBossModsDB.pos.x or 0, (SimpleBossModsDB.pos.y or 0) + C.GLOBAL_Y_NUDGE)
frames.anchor = anchor

local iconsParent = CreateFrame("Frame", ADDON_NAME .. "_Icons", UIParent)
if L.MIRROR then
	if L.BARS_BELOW then
		iconsParent:SetPoint("BOTTOMRIGHT", anchor, "CENTER", 0, 0)
	else
		iconsParent:SetPoint("TOPRIGHT", anchor, "CENTER", 0, 0)
	end
else
	if L.BARS_BELOW then
		iconsParent:SetPoint("BOTTOMLEFT", anchor, "CENTER", 0, 0)
	else
		iconsParent:SetPoint("TOPLEFT", anchor, "CENTER", 0, 0)
	end
end
iconsParent:SetSize(1, 1)
frames.iconsParent = iconsParent

local barsParent = CreateFrame("Frame", ADDON_NAME .. "_Bars", UIParent)
if L.MIRROR then
	if L.BARS_BELOW then
		barsParent:SetPoint("TOPRIGHT", iconsParent, "BOTTOMRIGHT", 0, -L.GAP)
	else
		barsParent:SetPoint("BOTTOMRIGHT", iconsParent, "TOPRIGHT", 0, L.GAP)
	end
else
	if L.BARS_BELOW then
		barsParent:SetPoint("TOPLEFT", iconsParent, "BOTTOMLEFT", 0, -L.GAP)
	else
		barsParent:SetPoint("BOTTOMLEFT", iconsParent, "TOPLEFT", 0, L.GAP)
	end
end
barsParent:SetSize(1, 1)
frames.barsParent = barsParent

local privateAurasAnchor = CreateFrame("Frame", ADDON_NAME .. "_PrivateAuras", UIParent)
privateAurasAnchor:SetSize(1, 1)
privateAurasAnchor:SetPoint("CENTER", UIParent, "CENTER", L.PRIVATE_AURA_X, L.PRIVATE_AURA_Y + C.GLOBAL_Y_NUDGE)
frames.privateAurasAnchor = privateAurasAnchor

local privateAuraBorderThickness
local ensurePrivateAuraOverlay

function M:SetPosition(x, y)
	x = tonumber(x) or 0
	y = tonumber(y) or 0
	SimpleBossModsDB.pos.x = x
	SimpleBossModsDB.pos.y = y

	anchor:ClearAllPoints()
	anchor:SetPoint("CENTER", UIParent, "CENTER", x, y + C.GLOBAL_Y_NUDGE)
end

local function buildPrivateAuraAnchorInfo(auraIndex, offsetX, offsetY)
	local size = L.PRIVATE_AURA_SIZE
	return {
		unitToken = "player",
		auraIndex = auraIndex,
		parent = privateAurasAnchor,
		showCountdownFrame = true,
		showCountdownNumbers = false,
		iconInfo = {
			iconAnchor = {
				point = "CENTER",
				relativeTo = privateAurasAnchor,
				relativePoint = "CENTER",
				offsetX = offsetX,
				offsetY = offsetY,
			},
			iconWidth = size,
			iconHeight = size,
		},
	}
end

function M:SetPrivateAuraPosition(x, y)
	x = tonumber(x) or 0
	y = tonumber(y) or 0
	if SimpleBossModsDB and SimpleBossModsDB.cfg and SimpleBossModsDB.cfg.privateAuras then
		SimpleBossModsDB.cfg.privateAuras.x = x
		SimpleBossModsDB.cfg.privateAuras.y = y
	end

	privateAurasAnchor:ClearAllPoints()
	privateAurasAnchor:SetPoint("CENTER", UIParent, "CENTER", x, y + C.GLOBAL_Y_NUDGE)
end

function M:UpdatePrivateAuraAnchor()
	if not (C_UnitAuras and C_UnitAuras.AddPrivateAuraAnchor) then return end

	if self._privateAuraAnchorIDs and C_UnitAuras.RemovePrivateAuraAnchor then
		for _, id in ipairs(self._privateAuraAnchorIDs) do
			if id then
				pcall(C_UnitAuras.RemovePrivateAuraAnchor, id)
			end
		end
	end
	self._privateAuraAnchorIDs = {}

	local step = L.PRIVATE_AURA_SIZE + L.PRIVATE_AURA_GAP
	local dir = L.PRIVATE_AURA_GROW
	for i = 1, (C.PRIVATE_AURA_MAX or 1) do
		local offsetX, offsetY = 0, 0
		if dir == "LEFT" then
			offsetX = -step * (i - 1)
		elseif dir == "RIGHT" then
			offsetX = step * (i - 1)
		elseif dir == "UP" then
			offsetY = step * (i - 1)
		else
			offsetY = -step * (i - 1)
		end

		local info = buildPrivateAuraAnchorInfo(i, offsetX, offsetY)
		local ok, id = pcall(C_UnitAuras.AddPrivateAuraAnchor, info)
		if ok then
			self._privateAuraAnchorIDs[i] = id
		end

		local overlay = ensurePrivateAuraOverlay and ensurePrivateAuraOverlay(self, i)
		if overlay then
			overlay:ClearAllPoints()
			overlay:SetPoint("CENTER", privateAurasAnchor, "CENTER", offsetX, offsetY)
			overlay:SetSize(L.PRIVATE_AURA_SIZE, L.PRIVATE_AURA_SIZE)
			overlay:SetFrameLevel(privateAurasAnchor:GetFrameLevel() + 50)
			M.ensureFullBorder(overlay, privateAuraBorderThickness(), 1, 0, 0, 1)
		end
	end
	if self._privateAuraOverlays then
		for i = (C.PRIVATE_AURA_MAX or 1) + 1, #self._privateAuraOverlays do
			local overlay = self._privateAuraOverlays[i]
			if overlay then
				overlay:Hide()
			end
		end
	end

	if self.UpdatePrivateAuraFrames then
		self:UpdatePrivateAuraFrames(false)
	end
	if self.UpdateTestPrivateAura then
		self:UpdateTestPrivateAura()
	end
end

local function getVisibleChildCount(parent)
	if not parent then return 0 end
	local count = 0
	for _, child in ipairs({ parent:GetChildren() }) do
		if child.__sbmPrivateAuraTest or child.__sbmPrivateAuraOverlay then
			-- skip test frame
		else
			local ok, shown = pcall(child.IsShown, child)
			if ok and shown then
				count = count + 1
			end
		end
	end
	return count
end

function M:GetPrivateAuraVisibleCount()
	return getVisibleChildCount(privateAurasAnchor)
end

privateAuraBorderThickness = function()
	if not U or not U.clamp then return 2 end
	return U.clamp(math.floor(L.PRIVATE_AURA_SIZE * 0.06 + 0.5), 1, 4)
end

local function isForbidden(obj)
	if not obj then return false end
	if not obj.IsForbidden then return false end
	local ok, forbidden = pcall(obj.IsForbidden, obj)
	return ok and forbidden
end

local function safeHideRegion(region)
	if not region then return end
	if region.IsForbidden and region:IsForbidden() then return end
	if region.Hide then
		pcall(region.Hide, region)
	end
	if region.SetAlpha then
		pcall(region.SetAlpha, region, 0)
	end
end

local function stylePrivateAuraFrame(frame)
	if not frame then return end
	if frame.__sbmPrivateAuraTest then return end
	if frame.__sbmPrivateAuraOverlay then return end
	if isForbidden(frame) then return end
	if InCombatLockdown and InCombatLockdown() then return end
	if frame.DebuffBorder then
		safeHideRegion(frame.DebuffBorder)
	end
	if frame.TempEnchantBorder then
		safeHideRegion(frame.TempEnchantBorder)
	end
	if frame.Symbol then
		safeHideRegion(frame.Symbol)
	end

	local holder = frame.__sbmPrivateAuraBorder
	if not holder then
		holder = CreateFrame("Frame", nil, frame)
		frame.__sbmPrivateAuraBorder = holder
	end
	holder:SetFrameLevel(frame:GetFrameLevel() + 6)
	local icon = frame.Icon
	if isForbidden(icon) then
		icon = nil
	end
	if icon then
		holder:SetAllPoints(icon)
	else
		holder:SetAllPoints(frame)
	end
	M.ensureFullBorder(holder, privateAuraBorderThickness(), 1, 0, 0, 1)
end

ensurePrivateAuraOverlay = function(self, index)
	self._privateAuraOverlays = self._privateAuraOverlays or {}
	local f = self._privateAuraOverlays[index]
	if not f then
		f = CreateFrame("Frame", nil, privateAurasAnchor)
		f.__sbmPrivateAuraOverlay = true
		f:EnableMouse(false)
		f:SetFrameStrata("HIGH")
		self._privateAuraOverlays[index] = f
	end
	return f
end

function M:UpdatePrivateAuraOverlays(visibleCount)
	if not self._privateAuraOverlays then return end
	local count = visibleCount
	if count == nil then
		count = self:GetPrivateAuraVisibleCount()
	end
	local maxCount = #self._privateAuraOverlays
	if count > maxCount then
		count = maxCount
	end
	for i = 1, maxCount do
		local f = self._privateAuraOverlays[i]
		if f then
			f:SetShown(i <= count)
		end
	end
end

function M:UpdatePrivateAuraFrames(playSound)
	if not privateAurasAnchor then return end
	local count = 0
	for _, child in ipairs({ privateAurasAnchor:GetChildren() }) do
		if not child.__sbmPrivateAuraTest and not child.__sbmPrivateAuraOverlay then
			local ok, shown = pcall(child.IsShown, child)
			if ok and shown then
				count = count + 1
			end
		end
		stylePrivateAuraFrame(child)
	end
	if self.UpdatePrivateAuraOverlays then
		self:UpdatePrivateAuraOverlays(count)
	end
	local prev = self._privateAuraLastCount
	self._privateAuraLastCount = count
	if playSound and L.PRIVATE_AURA_SOUND_KIT and L.PRIVATE_AURA_SOUND_KIT ~= 0 then
		if prev ~= nil and count > prev then
			self:PlayPrivateAuraSound()
		end
	end
end

local function ensureTestPrivateAuraFrame(self)
	if self._testPrivateAuraFrame then return self._testPrivateAuraFrame end
	local f = CreateFrame("Frame", nil, privateAurasAnchor)
	f:SetSize(L.PRIVATE_AURA_SIZE, L.PRIVATE_AURA_SIZE)
	f:SetPoint("CENTER", privateAurasAnchor, "CENTER", 0, 0)
	f.__sbmPrivateAuraTest = true

	local bg = f:CreateTexture(nil, "ARTWORK")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.6)
	f.bg = bg

	local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	text:SetPoint("CENTER", f, "CENTER", 0, 0)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowColor(0, 0, 0, 1)
	text:SetShadowOffset(1, -1)
	text:SetText("P")
	f.text = text

	f:Hide()
	self._testPrivateAuraFrame = f
	return f
end

function M:UpdateTestPrivateAura()
	local f = self._testPrivateAuraFrame
	if not f then return end
	f:SetSize(L.PRIVATE_AURA_SIZE, L.PRIVATE_AURA_SIZE)
	if f.bg then
		f.bg:SetAllPoints()
	end
	if f.text then
		local fontSize = math.max(12, math.floor(L.PRIVATE_AURA_SIZE * 0.6 + 0.5))
		f.text:SetFont(C.FONT_PATH, fontSize, C.FONT_FLAGS)
		f.text:SetText("P")
	end
	M.ensureFullBorder(f, privateAuraBorderThickness(), 1, 0, 0, 1)
end

function M:ShowTestPrivateAura(show)
	local f = ensureTestPrivateAuraFrame(self)
	if show then
		f:Show()
		self:UpdateTestPrivateAura()
	else
		f:Hide()
	end
end

function M:PlayPrivateAuraSound()
	local sound = L.PRIVATE_AURA_SOUND_KIT
	if not sound or sound == 0 then return end
	local now = GetTime and GetTime() or 0
	if self._privateAuraLastSoundAt and now > 0 and (now - self._privateAuraLastSoundAt) < 0.1 then
		return
	end
	self._privateAuraLastSoundAt = now
	if type(sound) == "number" then
		if PlaySound then
			pcall(PlaySound, sound, "Master")
		end
	elseif type(sound) == "string" then
		if PlaySoundFile then
			pcall(PlaySoundFile, sound, "Master")
		end
	end
end

-- =========================
-- Border system (ALWAYS on top)
-- =========================
local function ensureBorderFrame(owner)
	if owner.__borderFrame then return owner.__borderFrame end
	local bf = CreateFrame("Frame", nil, owner)
	bf:SetAllPoints(owner)
	bf:SetFrameLevel(owner:GetFrameLevel() + 200)
	owner.__borderFrame = bf
	return bf
end

local function ensureFullBorder(owner, thickness, r, g, b, a)
	local bf = ensureBorderFrame(owner)
	local function setColor(border)
		local cr = r or 0
		local cg = g or 0
		local cb = b or 0
		local ca = a or 1
		border.top:SetColorTexture(cr, cg, cb, ca)
		border.bot:SetColorTexture(cr, cg, cb, ca)
		border.left:SetColorTexture(cr, cg, cb, ca)
		border.right:SetColorTexture(cr, cg, cb, ca)
	end

	if bf.__fullBorder then
		local t = thickness or 1
		bf.__fullBorder.top:SetHeight(t)
		bf.__fullBorder.bot:SetHeight(t)
		bf.__fullBorder.left:SetWidth(t)
		bf.__fullBorder.right:SetWidth(t)
		if r ~= nil or g ~= nil or b ~= nil or a ~= nil then
			setColor(bf.__fullBorder)
		end
		return
	end

	local t = thickness or 1
	local function line()
		local tex = bf:CreateTexture(nil, "OVERLAY")
		return tex
	end

	local top = line()
	top:SetPoint("TOPLEFT", 0, 0)
	top:SetPoint("TOPRIGHT", 0, 0)
	top:SetHeight(t)

	local bot = line()
	bot:SetPoint("BOTTOMLEFT", 0, 0)
	bot:SetPoint("BOTTOMRIGHT", 0, 0)
	bot:SetHeight(t)

	local left = line()
	left:SetPoint("TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", 0, 0)
	left:SetWidth(t)

	local right = line()
	right:SetPoint("TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", 0, 0)
	right:SetWidth(t)

	bf.__fullBorder = { top = top, bot = bot, left = left, right = right }
	setColor(bf.__fullBorder)
end

local function ensureRightDivider(owner, thickness)
	local bf = ensureBorderFrame(owner)

	if bf.__rightDivider then
		bf.__rightDivider:SetWidth(thickness or 1)
		return
	end

	local t = thickness or 1
	local div = bf:CreateTexture(nil, "OVERLAY")
	div:SetColorTexture(0, 0, 0, 1)
	div:SetPoint("TOPRIGHT", owner, "TOPRIGHT", 0, 0)
	div:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 0, 0)
	div:SetWidth(t)

	bf.__rightDivider = div
end

local function ensureLeftDivider(owner, thickness)
	local bf = ensureBorderFrame(owner)

	if bf.__leftDivider then
		bf.__leftDivider:SetWidth(thickness or 1)
		return
	end

	local t = thickness or 1
	local div = bf:CreateTexture(nil, "OVERLAY")
	div:SetColorTexture(0, 0, 0, 1)
	div:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, 0)
	div:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", 0, 0)
	div:SetWidth(t)

	bf.__leftDivider = div
end

M.ensureFullBorder = ensureFullBorder
M.ensureRightDivider = ensureRightDivider
M.ensureLeftDivider = ensureLeftDivider

-- =========================
-- Indicator helpers
-- =========================
local function ensureIndicatorTextures(containerFrame, count)
	containerFrame.__indicatorTextures = containerFrame.__indicatorTextures or {}
	local t = containerFrame.__indicatorTextures
	for i = #t + 1, count do
		local tex = containerFrame:CreateTexture(nil, "OVERLAY")
		tex:Hide()
		t[i] = tex
	end
	return t
end

local function layoutIconIndicators(iconFrame, textures)
	-- bottom-right inside icon, 2x3 grid (usually you won't have all)
	local s = U.iconIndicatorSize()
	local gap = U.clamp(math.floor(s * 0.12 + 0.5) + 1, 2, 4)
	local mirror = L.MIRROR

	-- Place as:
	-- [4][5][6]
	-- [1][2][3]  (bottom row)
	-- anchored bottom-right
	for i = 1, C.INDICATOR_MAX do
		local tex = textures[i]
		tex:SetSize(s, s)

		local idx = i - 1
		local col = idx % 3
		local row = math.floor(idx / 3) -- 0 or 1

		local x = col * (s + gap)
		local y =  (row * (s + gap))

		tex:ClearAllPoints()
		if mirror then
			tex:SetPoint("BOTTOMLEFT", iconFrame.main, "BOTTOMLEFT", 3 + x, 3 + y)
		else
			tex:SetPoint("BOTTOMRIGHT", iconFrame.main, "BOTTOMRIGHT", -3 - x, 3 + y)
		end
	end
end

local function layoutBarIndicators(barFrame, textures)
	local size = U.barIndicatorSize()
	local gap = 3
	local totalW = C.INDICATOR_MAX * size + (C.INDICATOR_MAX - 1) * gap
	local mirror = L.MIRROR
	barFrame.endIndicatorsFrame:SetWidth(totalW)

	for i = 1, C.INDICATOR_MAX do
		local tex = textures[i]
		local x = (i - 1) * (size + gap)
		tex:ClearAllPoints()
		tex:SetSize(size, size)
		if mirror then
			tex:SetPoint("RIGHT", barFrame.endIndicatorsFrame, "RIGHT", -x, 0)
		else
			tex:SetPoint("LEFT", barFrame.endIndicatorsFrame, "LEFT", x, 0)
		end
	end
end

M.ensureIndicatorTextures = ensureIndicatorTextures
M.layoutIconIndicators = layoutIconIndicators
M.layoutBarIndicators = layoutBarIndicators

-- =========================
-- Secure indicator API wrapper
-- =========================
local function safeSetEventIconTextures(eventID, mask, textures)
	if not (C_EncounterTimeline and C_EncounterTimeline.SetEventIconTextures) then return false end
	local ok = pcall(C_EncounterTimeline.SetEventIconTextures, eventID, mask, textures)
	return ok
end

local function applyIndicatorsToIconFrame(iconFrame, eventID)
	if not iconFrame or not iconFrame.indicatorsFrame then return end
	if type(eventID) ~= "number" then return end

	local textures = ensureIndicatorTextures(iconFrame.indicatorsFrame, C.INDICATOR_MAX)
	for i = 1, C.INDICATOR_MAX do
		local tex = textures[i]
		tex:ClearAllPoints()
		tex:SetSize(1, 1)
		tex:Show()
	end

	if not safeSetEventIconTextures(eventID, C.INDICATOR_MASK, textures) then
		for i = 1, C.INDICATOR_MAX do textures[i]:Hide() end
		return
	end

	layoutIconIndicators(iconFrame, textures)
end

local function applyIndicatorsToBarEnd(barFrame, eventID)
	if not barFrame or not barFrame.endIndicatorsFrame then return end
	if type(eventID) ~= "number" then return end

	local textures = ensureIndicatorTextures(barFrame.endIndicatorsFrame, C.INDICATOR_MAX)

	for i = 1, C.INDICATOR_MAX do
		local tex = textures[i]
		tex:ClearAllPoints()
		tex:SetSize(1, 1)
		tex:Show()
	end

	if not safeSetEventIconTextures(eventID, C.INDICATOR_MASK, textures) then
		for i = 1, C.INDICATOR_MAX do textures[i]:Hide() end
		barFrame.endIndicatorsFrame:SetWidth(1)
		return
	end

	layoutBarIndicators(barFrame, textures)
end

M.applyIndicatorsToIconFrame = applyIndicatorsToIconFrame
M.applyIndicatorsToBarEnd = applyIndicatorsToBarEnd

local function applyBarMirror(f)
	if not f then return end

	local iconOnRight = L.MIRROR
	if L.BAR_ICON_SWAP then
		iconOnRight = not iconOnRight
	end
	local iconVisible = not L.BAR_ICON_HIDDEN

	f.leftFrame:SetWidth(iconVisible and L.BAR_HEIGHT or 0)
	f.leftFrame:SetShown(iconVisible)
	f.iconFrame:SetSize(iconVisible and L.BAR_HEIGHT or 0, iconVisible and L.BAR_HEIGHT or 0)
	f.iconFrame:SetShown(iconVisible)

	f.leftFrame:ClearAllPoints()
	if iconOnRight then
		f.leftFrame:SetPoint("RIGHT", f, "RIGHT", 0, 0)
		f.leftFrame:SetPoint("TOP", f, "TOP", 0, 0)
		f.leftFrame:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
		ensureLeftDivider(f.leftFrame, L.BAR_BORDER_THICKNESS)
	else
		f.leftFrame:SetPoint("LEFT", f, "LEFT", 0, 0)
		f.leftFrame:SetPoint("TOP", f, "TOP", 0, 0)
		f.leftFrame:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
		ensureRightDivider(f.leftFrame, L.BAR_BORDER_THICKNESS)
	end
	if f.leftFrame.__borderFrame then
		if f.leftFrame.__borderFrame.__rightDivider then
			f.leftFrame.__borderFrame.__rightDivider:SetShown(iconVisible and not iconOnRight)
		end
		if f.leftFrame.__borderFrame.__leftDivider then
			f.leftFrame.__borderFrame.__leftDivider:SetShown(iconVisible and iconOnRight)
		end
	end

	f.sb:ClearAllPoints()
	if iconVisible then
		if iconOnRight then
			f.sb:SetPoint("RIGHT", f.leftFrame, "LEFT", 0, 0)
			f.sb:SetPoint("LEFT", f, "LEFT", 0, 0)
		else
			f.sb:SetPoint("LEFT", f.leftFrame, "RIGHT", 0, 0)
			f.sb:SetPoint("RIGHT", f, "RIGHT", 0, 0)
		end
	else
		f.sb:SetPoint("LEFT", f, "LEFT", 0, 0)
		f.sb:SetPoint("RIGHT", f, "RIGHT", 0, 0)
	end
	f.sb:SetPoint("TOP", f, "TOP", 0, 0)
	f.sb:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)

	if f.sb.SetReverseFill then
		f.sb:SetReverseFill(L.MIRROR)
	elseif f.sb.SetReverse then
		f.sb:SetReverse(L.MIRROR)
	end

	if f.endIndicatorsFrame then
		f.endIndicatorsFrame:ClearAllPoints()
		if L.MIRROR then
			f.endIndicatorsFrame:SetPoint("RIGHT", f, "LEFT", -C.BAR_END_INDICATOR_GAP_X, 0)
		else
			f.endIndicatorsFrame:SetPoint("LEFT", f, "RIGHT", C.BAR_END_INDICATOR_GAP_X, 0)
		end
		f.endIndicatorsFrame:SetPoint("TOP", f, "TOP", 0, 0)
		f.endIndicatorsFrame:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
	end

	if f.txt then
		f.txt:ClearAllPoints()
		if L.MIRROR then
			f.txt:SetPoint("RIGHT", f.sb, "RIGHT", -6, 0)
			f.txt:SetJustifyH("RIGHT")
		else
			f.txt:SetPoint("LEFT", f.sb, "LEFT", 6, 0)
			f.txt:SetJustifyH("LEFT")
		end
	end
	if f.rt then
		f.rt:ClearAllPoints()
		if L.MIRROR then
			f.rt:SetPoint("LEFT", f.sb, "LEFT", 6, 0)
			f.rt:SetJustifyH("LEFT")
		else
			f.rt:SetPoint("RIGHT", f.sb, "RIGHT", -6, 0)
			f.rt:SetJustifyH("RIGHT")
		end
	end
end

M.applyBarMirror = applyBarMirror

-- =========================
-- Bar fill
-- =========================
local function setBarFillFlat(barFrame, r, g, b, a)
	if not barFrame or not barFrame.sb then return end
	local flatTex = "Interface\\Buttons\\WHITE8X8"
	barFrame.sb:SetStatusBarTexture(flatTex)
	local tex = barFrame.sb:GetStatusBarTexture()
	barFrame.sbTex = tex
	barFrame.sb:SetStatusBarColor(r, g, b, a or 1)
	if tex then
		tex:SetDrawLayer("ARTWORK")
		tex:SetVertexColor(r, g, b, a or 1)
	end
end

M.setBarFillFlat = setBarFillFlat

-- =========================
-- Pools
-- =========================
local pools = M.pools or { icon = {}, bar = {} }
M.pools = pools

local iconPool = pools.icon
local barPool = pools.bar

local function applyIconFont(fs)
	if not fs then return end
	fs:SetFont(C.FONT_PATH, L.ICON_FONT_SIZE, C.FONT_FLAGS)
	fs:SetShadowColor(0, 0, 0, 0)
	fs:SetShadowOffset(0, 0)
end

local function applyBarFont(fs)
	if not fs then return end
	fs:SetFont(C.FONT_PATH, L.BAR_FONT_SIZE, C.FONT_FLAGS)
	fs:SetShadowColor(0, 0, 0, 0)
	fs:SetShadowOffset(0, 0)
end

M.applyIconFont = applyIconFont
M.applyBarFont = applyBarFont

local function acquireIcon()
	local f = tremove(iconPool)
	if not f then
		f = CreateFrame("Frame", nil, iconsParent)

		local main = CreateFrame("Frame", nil, f)
		main:SetAllPoints(f)
		f.main = main

		local tex = main:CreateTexture(nil, "ARTWORK")
		tex:SetAllPoints()
		f.tex = tex

		local cd = CreateFrame("Cooldown", nil, main, "CooldownFrameTemplate")
		cd:SetAllPoints()
		cd:SetDrawEdge(false)
		if cd.SetReverse then cd:SetReverse(true) end
		if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
		cd:SetFrameLevel(main:GetFrameLevel() + 5)
		f.cd = cd

		local tf = CreateFrame("Frame", nil, main)
		tf:SetAllPoints()
		tf:SetFrameLevel(cd:GetFrameLevel() + 10)
		f.textOverlay = tf

		local tt = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		tt:SetPoint("CENTER", tf, "CENTER", 0, 0)
		tt:SetTextColor(1, 1, 1, 1)
		tt:SetShadowColor(0, 0, 0, 1)
		tt:SetShadowOffset(1, -1)
		f.timeText = tt

		-- indicator layer inside icon, above cooldown/text
		local ind = CreateFrame("Frame", nil, main)
		ind:SetAllPoints(main)
		ind:SetFrameLevel(tf:GetFrameLevel() + 10)
		f.indicatorsFrame = ind
	end

	f:SetSize(L.ICON_SIZE, L.ICON_SIZE)
	ensureFullBorder(f.main, L.ICON_BORDER_THICKNESS)

	f.cd:SetFrameLevel(f.main:GetFrameLevel() + 5)
	if f.textOverlay then
		f.textOverlay:SetFrameLevel(f.cd:GetFrameLevel() + 10)
	end
	if f.indicatorsFrame and f.textOverlay then
		f.indicatorsFrame:SetFrameLevel(f.textOverlay:GetFrameLevel() + 10)
	end

	applyIconFont(f.timeText)
	f:Show()
	return f
end

local function releaseIcon(f)
	if not f then return end
	f:Hide()
	f:ClearAllPoints()
	f.__id = nil
	f.tex:SetTexture(nil)
	if f.cd then f.cd:Clear() end
	if f.timeText then f.timeText:SetText("") end

	if f.indicatorsFrame and f.indicatorsFrame.__indicatorTextures then
		for _, tex in ipairs(f.indicatorsFrame.__indicatorTextures) do
			tex:Hide()
		end
	end

	tinsert(iconPool, f)
end

local function acquireBar()
	local f = tremove(barPool)
	if not f then
		f = CreateFrame("Frame", nil, barsParent)

		local bg = f:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(L.BAR_BG_R, L.BAR_BG_G, L.BAR_BG_B, 1)
		bg:SetAlpha(L.BAR_BG_A)
		f.bg = bg

		local leftFrame = CreateFrame("Frame", nil, f)
		leftFrame:SetPoint("LEFT", f, "LEFT", 0, 0)
		leftFrame:SetPoint("TOP", f, "TOP", 0, 0)
		leftFrame:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
		leftFrame:SetWidth(L.BAR_HEIGHT)
		f.leftFrame = leftFrame

		local iconFrame = CreateFrame("Frame", nil, leftFrame)
		iconFrame:SetAllPoints()
		f.iconFrame = iconFrame

		local icon = iconFrame:CreateTexture(nil, "ARTWORK")
		icon:SetAllPoints()
		f.icon = icon

		local sb = CreateFrame("StatusBar", nil, f)
		sb:SetPoint("LEFT", leftFrame, "RIGHT", 0, 0)
		sb:SetPoint("TOP", f, "TOP", 0, 0)
		sb:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
		sb:SetPoint("RIGHT", f, "RIGHT", 0, 0)
		sb:SetStatusBarTexture(C.BAR_TEX_DEFAULT)
		sb:SetMinMaxValues(0, L.THRESHOLD_TO_BAR)
		sb:SetValue(L.THRESHOLD_TO_BAR)
		f.sb = sb

		f.sbTex = sb:GetStatusBarTexture()
		if f.sbTex then
			f.sbTex:SetDrawLayer("BACKGROUND")
		end

		-- End indicators (outside bar)
		local endInd = CreateFrame("Frame", nil, f)
		endInd:SetPoint("LEFT", f, "RIGHT", C.BAR_END_INDICATOR_GAP_X, 0)
		endInd:SetPoint("TOP", f, "TOP", 0, 0)
		endInd:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
		endInd:SetWidth(1)
		f.endIndicatorsFrame = endInd

		local textFrame = CreateFrame("Frame", nil, f)
		textFrame:SetAllPoints()
		textFrame:SetFrameLevel(f:GetFrameLevel() + 50)
		f.textFrame = textFrame

		local txt = textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		txt:SetPoint("LEFT", sb, "LEFT", 6, 0)
		txt:SetJustifyH("LEFT")
		txt:SetTextColor(1, 1, 1, 1)
		txt:SetShadowColor(0, 0, 0, 1)
		txt:SetShadowOffset(1, -1)
		f.txt = txt

		local rt = textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		rt:SetPoint("RIGHT", sb, "RIGHT", -6, 0)
		rt:SetJustifyH("RIGHT")
		rt:SetTextColor(1, 1, 1, 1)
		rt:SetShadowColor(0, 0, 0, 1)
		rt:SetShadowOffset(1, -1)
		f.rt = rt
	end

	f:SetSize(L.BAR_WIDTH, L.BAR_HEIGHT)
	ensureFullBorder(f, L.BAR_BORDER_THICKNESS)
	if f.bg then
		f.bg:SetColorTexture(L.BAR_BG_R, L.BAR_BG_G, L.BAR_BG_B, 1)
		f.bg:SetAlpha(L.BAR_BG_A)
	end

	applyBarMirror(f)

	if f.endIndicatorsFrame then
		f.endIndicatorsFrame:SetWidth(1)
	end

	applyBarFont(f.txt)
	applyBarFont(f.rt)

	setBarFillFlat(f, L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A)

	f:Show()
	return f
end

local function releaseBar(f)
	if not f then return end
	f:Hide()
	f:ClearAllPoints()
	f.__id = nil

	f.sb:SetMinMaxValues(0, L.THRESHOLD_TO_BAR)
	f.sb:SetValue(L.THRESHOLD_TO_BAR)
	setBarFillFlat(f, L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A)

	f.txt:SetText("")
	f.rt:SetText("")
	if f.icon then
		f.icon:SetTexture(nil)
		f.icon:SetTexCoord(0, 1, 0, 1)
	end

	if f.endIndicatorsFrame and f.endIndicatorsFrame.__indicatorTextures then
		for _, tex in ipairs(f.endIndicatorsFrame.__indicatorTextures) do
			tex:Hide()
		end
	end
	if f.endIndicatorsFrame then
		f.endIndicatorsFrame:SetWidth(1)
	end

	f:SetScript("OnUpdate", nil)
	tinsert(barPool, f)
end

M.acquireIcon = acquireIcon
M.releaseIcon = releaseIcon
M.acquireBar = acquireBar
M.releaseBar = releaseBar
