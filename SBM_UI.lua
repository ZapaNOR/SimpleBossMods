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

local iconsParent = CreateFrame("Frame", ADDON_NAME .. "_Icons", UIParent)
iconsParent:SetSize(1, 1)
frames.iconsParent = iconsParent

local barsParent = CreateFrame("Frame", ADDON_NAME .. "_Bars", UIParent)
barsParent:SetSize(1, 1)
frames.barsParent = barsParent

local privateAurasAnchor = CreateFrame("Frame", ADDON_NAME .. "_PrivateAuras", UIParent)
privateAurasAnchor:SetSize(1, 1)
frames.privateAurasAnchor = privateAurasAnchor

local getPrivateAuraLayout

function M:UpdateIconsAnchorPosition()
	if not iconsParent then return end
	iconsParent:ClearAllPoints()
	local parent = UIParent
	local parentName = L.ICON_PARENT_NAME
	if type(parentName) == "string" and parentName ~= "" then
		parent = _G[parentName] or UIParent
	end
	iconsParent:SetPoint(
		L.ICON_ANCHOR_FROM or "TOPLEFT",
		parent,
		L.ICON_ANCHOR_TO or "CENTER",
		L.ICON_ANCHOR_X or 0,
		(L.ICON_ANCHOR_Y or 0) + C.GLOBAL_Y_NUDGE
	)
end

function M:UpdateBarsAnchorPosition()
	if not barsParent then return end
	barsParent:ClearAllPoints()
	local parent = UIParent
	local parentName = L.BAR_PARENT_NAME
	if type(parentName) == "string" and parentName ~= "" then
		parent = _G[parentName] or UIParent
	end
	barsParent:SetPoint(
		L.BAR_ANCHOR_FROM or "BOTTOMLEFT",
		parent,
		L.BAR_ANCHOR_TO or "TOPLEFT",
		L.BAR_ANCHOR_X or 0,
		(L.BAR_ANCHOR_Y or 0) + C.GLOBAL_Y_NUDGE
	)
end

function M:UpdatePrivateAuraAnchorPosition()
	if not privateAurasAnchor then return end
	local _, _, _, width, height = getPrivateAuraLayout()
	privateAurasAnchor:SetSize(width or 1, height or 1)
	privateAurasAnchor:ClearAllPoints()
	local parent = UIParent
	local parentName = L.PRIVATE_AURA_PARENT_NAME
	if type(parentName) == "string" and parentName ~= "" then
		parent = _G[parentName] or UIParent
	end
	privateAurasAnchor:SetPoint(
		L.PRIVATE_AURA_ANCHOR_FROM or "CENTER",
		parent,
		L.PRIVATE_AURA_ANCHOR_TO or "CENTER",
		L.PRIVATE_AURA_X or 0,
		(L.PRIVATE_AURA_Y or 0) + C.GLOBAL_Y_NUDGE
	)
end

local COMBAT_TIMER_PAD_X = 8
local COMBAT_TIMER_PAD_Y = 4
local COMBAT_TIMER_BORDER_THICKNESS = 1

local combatTimerFrame = CreateFrame("Frame", ADDON_NAME .. "_CombatTimer", UIParent)
combatTimerFrame:SetSize(1, 1)
do
	local parent = UIParent
	local parentName = L.COMBAT_TIMER_PARENT_NAME
	if type(parentName) == "string" and parentName ~= "" then
		parent = _G[parentName] or UIParent
	end
	combatTimerFrame:SetPoint(
		L.COMBAT_TIMER_ANCHOR_FROM or "CENTER",
		parent,
		L.COMBAT_TIMER_ANCHOR_TO or "CENTER",
		L.COMBAT_TIMER_X,
		(L.COMBAT_TIMER_Y or 0) + C.GLOBAL_Y_NUDGE
	)
end
combatTimerFrame:Hide()
frames.combatTimerFrame = combatTimerFrame

local combatTimerBg = combatTimerFrame:CreateTexture(nil, "BACKGROUND")
combatTimerBg:SetAllPoints()
combatTimerFrame.bg = combatTimerBg

local combatTimerText = combatTimerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
combatTimerText:SetPoint("CENTER", combatTimerFrame, "CENTER", 0, 0)
combatTimerFrame.text = combatTimerText

local privateAuraBorderThickness
local ensurePrivateAuraOverlay
getPrivateAuraLayout = function()
	local size = L.PRIVATE_AURA_SIZE or 0
	local gap = L.PRIVATE_AURA_GAP or 0
	local step = size + gap
	local maxCount = C.PRIVATE_AURA_MAX or 1
	local dir = L.PRIVATE_AURA_GROW or "RIGHT"
	local width, height, startX, startY, stepX, stepY

	if dir == "LEFT" or dir == "RIGHT" then
		width = size + step * (maxCount - 1)
		height = size
		stepX = (dir == "RIGHT") and step or -step
		stepY = 0
		startX = (dir == "RIGHT") and (-width * 0.5 + size * 0.5) or (width * 0.5 - size * 0.5)
		startY = 0
	else
		width = size
		height = size + step * (maxCount - 1)
		stepX = 0
		stepY = (dir == "UP") and step or -step
		startX = 0
		startY = (dir == "UP") and (-height * 0.5 + size * 0.5) or (height * 0.5 - size * 0.5)
	end

	return size, step, maxCount, width, height, startX, startY, stepX, stepY
end

M:UpdateIconsAnchorPosition()
M:UpdateBarsAnchorPosition()
M:UpdatePrivateAuraAnchorPosition()

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
	L.PRIVATE_AURA_X = x
	L.PRIVATE_AURA_Y = y
	if self.UpdatePrivateAuraAnchorPosition then
		self:UpdatePrivateAuraAnchorPosition()
	end
end

local function formatCombatTimer(secs)
	if not secs or secs < 0 then secs = 0 end
	local minutes = math.floor(secs / 60)
	local seconds = math.floor(secs % 60)
	return string.format("%02d:%02d", minutes, seconds)
end

local function updateCombatTimerSize()
	local w = combatTimerText:GetStringWidth() or 0
	local h = combatTimerText:GetStringHeight() or 0
	combatTimerFrame:SetSize(math.max(1, w + COMBAT_TIMER_PAD_X * 2), math.max(1, h + COMBAT_TIMER_PAD_Y * 2))
end

local function setCombatTimerText(seconds)
	local text = formatCombatTimer(seconds)
	if combatTimerFrame._lastText == text then return end
	combatTimerFrame._lastText = text
	combatTimerText:SetText(text)
	updateCombatTimerSize()
end

local function combatTimerOnUpdate()
	if not M._combatStartTime then return end
	local secs = GetTime() - M._combatStartTime
	if secs < 0 then secs = 0 end
	local whole = math.floor(secs)
	if combatTimerFrame._lastSeconds == whole then return end
	combatTimerFrame._lastSeconds = whole
	setCombatTimerText(whole)
end

local function hidePrivateAuraOverlays(self)
	if not self._privateAuraOverlays then return end
	for _, overlay in ipairs(self._privateAuraOverlays) do
		overlay:Hide()
	end
end

local function hideTestPrivateAuraFrames(self)
	if not self._testPrivateAuraFrames then return end
	for _, frame in ipairs(self._testPrivateAuraFrames) do
		frame:Hide()
	end
end

function M:UpdatePrivateAuraAnchor()
	if self.UpdatePrivateAuraAnchorPosition then
		self:UpdatePrivateAuraAnchorPosition()
	end
	if not (C_UnitAuras and C_UnitAuras.AddPrivateAuraAnchor) then return end

	hidePrivateAuraOverlays(self)

	if self._privateAuraAnchorIDs and C_UnitAuras.RemovePrivateAuraAnchor then
		for _, id in ipairs(self._privateAuraAnchorIDs) do
			if id then
				pcall(C_UnitAuras.RemovePrivateAuraAnchor, id)
			end
		end
	end
	self._privateAuraAnchorIDs = {}

	if not L.PRIVATE_AURA_ENABLED then
		privateAurasAnchor:SetSize(1, 1)
		privateAurasAnchor:Show()
		hidePrivateAuraOverlays(self)
		hideTestPrivateAuraFrames(self)
		return
	end

	privateAurasAnchor:Show()
	local size, _, _, _, _, startX, startY, stepX, stepY = getPrivateAuraLayout()
	for i = 1, (C.PRIVATE_AURA_MAX or 1) do
		local offsetX = startX + stepX * (i - 1)
		local offsetY = startY + stepY * (i - 1)

		local info = buildPrivateAuraAnchorInfo(i, offsetX, offsetY)
		local ok, id = pcall(C_UnitAuras.AddPrivateAuraAnchor, info)
		if ok then
			self._privateAuraAnchorIDs[i] = id
		end

		local overlay = ensurePrivateAuraOverlay and ensurePrivateAuraOverlay(self, i)
		if overlay then
			overlay:ClearAllPoints()
			overlay:SetPoint("CENTER", privateAurasAnchor, "CENTER", offsetX, offsetY)
			overlay:SetSize(size, size)
			overlay:SetFrameLevel(privateAurasAnchor:GetFrameLevel() + 50)
			M.ensureFullBorder(overlay, privateAuraBorderThickness())
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
		self:UpdatePrivateAuraFrames()
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
	if not L.PRIVATE_AURA_ENABLED then return 0 end
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

local function hidePrivateAuraBorders(frame)
	if not frame then return end
	local icon = frame.Icon
	local function hide(obj)
		if not obj or obj == icon then return end
		safeHideRegion(obj)
	end

	hide(frame.Border)
	hide(frame.IconBorder)
	hide(frame.IconOverlay)
	hide(frame.BorderTexture)
	hide(frame.Overlay)
	hide(frame.Glow)

	local regions = { frame:GetRegions() }
	for _, region in ipairs(regions) do
		if region ~= icon and region.GetObjectType and region:GetObjectType() == "Texture" then
			local tex = region.GetTexture and region:GetTexture()
			local atlas = region.GetAtlas and region:GetAtlas()
			if (type(tex) == "string" and tex:find("Debuff%-Overlays")) or
				(type(atlas) == "string" and atlas:lower():find("debuff")) then
				safeHideRegion(region)
			end
		end
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
	hidePrivateAuraBorders(frame)

	local holder = frame.__sbmPrivateAuraBorder
	if not holder then
		holder = CreateFrame("Frame", nil, frame)
		frame.__sbmPrivateAuraBorder = holder
	end
	holder:SetFrameLevel(frame:GetFrameLevel() + 6)
	holder:SetAllPoints(frame)
	M.ensureFullBorder(holder, privateAuraBorderThickness())
end

ensurePrivateAuraOverlay = function(self, index)
	self._privateAuraOverlays = self._privateAuraOverlays or {}
	local f = self._privateAuraOverlays[index]
	if not f then
		f = CreateFrame("Frame", nil, privateAurasAnchor)
		f.__sbmPrivateAuraOverlay = true
		f:EnableMouse(false)
		f:SetFrameStrata("HIGH")
		f:Hide()
		self._privateAuraOverlays[index] = f
	end
	return f
end

function M:UpdatePrivateAuraOverlays(visibleCount)
	if not L.PRIVATE_AURA_ENABLED then
		hidePrivateAuraOverlays(self)
		return
	end
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

function M:UpdatePrivateAuraFrames()
	if not L.PRIVATE_AURA_ENABLED then
		hidePrivateAuraOverlays(self)
		hideTestPrivateAuraFrames(self)
		return
	end
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
end

local function ensureTestPrivateAuraFrames(self)
	if self._testPrivateAuraFrames then return self._testPrivateAuraFrames end
	local frames = {}
	for i = 1, 4 do
		local f = CreateFrame("Frame", nil, privateAurasAnchor)
		f:SetSize(L.PRIVATE_AURA_SIZE, L.PRIVATE_AURA_SIZE)
		f.__sbmPrivateAuraTest = true

		local bg = f:CreateTexture(nil, "ARTWORK")
		bg:SetAllPoints()
		f.bg = bg

		local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		text:SetPoint("CENTER", f, "CENTER", 0, 0)
		text:SetTextColor(1, 1, 1, 1)
		text:SetShadowColor(0, 0, 0, 1)
		text:SetShadowOffset(1, -1)
		f.text = text

		f:Hide()
		frames[i] = f
	end
	self._testPrivateAuraFrames = frames
	return frames
end

function M:UpdateTestPrivateAura()
	if not L.PRIVATE_AURA_ENABLED then return end
	local frames = self._testPrivateAuraFrames
	if not frames then return end
	local size, _, _, _, _, startX, startY, stepX, stepY = getPrivateAuraLayout()
	local fontSize = math.max(12, math.floor(size * 0.6 + 0.5))

	for i, f in ipairs(frames) do
		f:SetSize(size, size)
		f:ClearAllPoints()
		local offsetX = startX + stepX * (i - 1)
		local offsetY = startY + stepY * (i - 1)
		f:SetPoint("CENTER", privateAurasAnchor, "CENTER", offsetX, offsetY)

		if f.bg then
			f.bg:SetAllPoints()
			f.bg:SetColorTexture(0, 0, 0, 1)
			f.bg:SetAlpha(0.75)
		end
		if f.text then
			f.text:SetFont(L.FONT_PATH or C.FONT_PATH, fontSize, C.FONT_FLAGS)
			if i == 1 then
				f.text:SetText("P")
			else
				f.text:SetText(tostring(i))
			end
		end

		if i == 1 then
			M.ensureFullBorder(f, 1, 1, 0, 0, 1)
		else
			M.ensureFullBorder(f, 1, 0, 0, 0, 1)
		end
	end
end

function M:ShowTestPrivateAura(show)
	if not L.PRIVATE_AURA_ENABLED then
		show = false
	end
	local frames = ensureTestPrivateAuraFrames(self)
	if show then
		for _, f in ipairs(frames) do
			f:Show()
		end
		self:UpdateTestPrivateAura()
	else
		for _, f in ipairs(frames) do
			f:Hide()
		end
	end
end

-- =========================
-- Combat timer
-- =========================
function M:UpdateCombatTimerAppearance()
	if not combatTimerFrame then return end
	combatTimerText:SetFont(L.COMBAT_TIMER_FONT_PATH or L.FONT_PATH or C.FONT_PATH, L.COMBAT_TIMER_FONT_SIZE or 16, C.FONT_FLAGS)
	combatTimerText:SetTextColor(L.COMBAT_TIMER_COLOR_R or 1, L.COMBAT_TIMER_COLOR_G or 1, L.COMBAT_TIMER_COLOR_B or 1, L.COMBAT_TIMER_COLOR_A or 1)
	combatTimerBg:SetColorTexture(L.COMBAT_TIMER_BG_R or 0, L.COMBAT_TIMER_BG_G or 0, L.COMBAT_TIMER_BG_B or 0, L.COMBAT_TIMER_BG_A or 1)
	combatTimerFrame:ClearAllPoints()
	local parent = UIParent
	local parentName = L.COMBAT_TIMER_PARENT_NAME
	if type(parentName) == "string" and parentName ~= "" then
		parent = _G[parentName] or UIParent
	end
	combatTimerFrame:SetPoint(
		L.COMBAT_TIMER_ANCHOR_FROM or "CENTER",
		parent,
		L.COMBAT_TIMER_ANCHOR_TO or "CENTER",
		L.COMBAT_TIMER_X or 0,
		(L.COMBAT_TIMER_Y or 0) + C.GLOBAL_Y_NUDGE
	)
	if M.ensureFullBorder then
		M.ensureFullBorder(combatTimerFrame, COMBAT_TIMER_BORDER_THICKNESS, L.COMBAT_TIMER_BORDER_R or 0, L.COMBAT_TIMER_BORDER_G or 0, L.COMBAT_TIMER_BORDER_B or 0, L.COMBAT_TIMER_BORDER_A or 1)
	end
	updateCombatTimerSize()
end

function M:StartCombatTimer(reset)
	if not L.COMBAT_TIMER_ENABLED then return end
	if reset or not self._combatStartTime then
		self._combatStartTime = GetTime()
	end
	combatTimerFrame._lastSeconds = nil
	setCombatTimerText(math.floor((GetTime() - self._combatStartTime) or 0))
	combatTimerFrame:SetScript("OnUpdate", combatTimerOnUpdate)
	combatTimerFrame:Show()
end

function M:StopCombatTimer()
	if combatTimerFrame then
		combatTimerFrame:SetScript("OnUpdate", nil)
		combatTimerFrame:Hide()
		combatTimerFrame._lastSeconds = nil
	end
	self._combatStartTime = nil
end

function M:UpdateCombatTimerState()
	if not L.COMBAT_TIMER_ENABLED then
		self:StopCombatTimer()
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		self:StartCombatTimer(false)
	else
		self:StopCombatTimer()
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
	local mirror = L.ICON_GROW_DIR == "LEFT_DOWN" or L.ICON_GROW_DIR == "LEFT_UP"

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
	local mirror = L.BAR_INDICATOR_ON_LEFT
	if mirror == nil then
		mirror = L.BAR_FILL_REVERSE
		if L.BAR_INDICATOR_SWAP then
			mirror = not mirror
		end
	end
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
	local idType = type(eventID)
	if idType ~= "number" and idType ~= "string" then return end

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
	local idType = type(eventID)
	if idType ~= "number" and idType ~= "string" then return end

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

	local iconOnRight = false
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
		f.sb:SetReverseFill(L.BAR_FILL_REVERSE)
	elseif f.sb.SetReverse then
		f.sb:SetReverse(L.BAR_FILL_REVERSE)
	end

	if f.endIndicatorsFrame then
		local indicatorOnLeft = L.BAR_INDICATOR_ON_LEFT
		if indicatorOnLeft == nil then
			indicatorOnLeft = L.BAR_FILL_REVERSE
			if L.BAR_INDICATOR_SWAP then
				indicatorOnLeft = not indicatorOnLeft
			end
		end
		f.endIndicatorsFrame:ClearAllPoints()
		if indicatorOnLeft then
			f.endIndicatorsFrame:SetPoint("RIGHT", f, "LEFT", -C.BAR_END_INDICATOR_GAP_X, 0)
		else
			f.endIndicatorsFrame:SetPoint("LEFT", f, "RIGHT", C.BAR_END_INDICATOR_GAP_X, 0)
		end
		f.endIndicatorsFrame:SetPoint("TOP", f, "TOP", 0, 0)
		f.endIndicatorsFrame:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
	end

	if f.txt then
		f.txt:ClearAllPoints()
		if L.BAR_FILL_REVERSE then
			f.txt:SetPoint("RIGHT", f.sb, "RIGHT", -6, 0)
			f.txt:SetJustifyH("RIGHT")
		else
			f.txt:SetPoint("LEFT", f.sb, "LEFT", 6, 0)
			f.txt:SetJustifyH("LEFT")
		end
	end
	if f.rt then
		f.rt:ClearAllPoints()
		if L.BAR_FILL_REVERSE then
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
	local texPath = L.BAR_TEX or C.BAR_TEX_DEFAULT or "Interface\\Buttons\\WHITE8X8"
	local aa = a or 1
	local hasSecret = type(issecretvalue) == "function" and (
		issecretvalue(r) or issecretvalue(g) or issecretvalue(b) or issecretvalue(aa)
	)
	if not hasSecret then
		if barFrame.__sbmBarTex == texPath
			and barFrame.__sbmBarR == r
			and barFrame.__sbmBarG == g
			and barFrame.__sbmBarB == b
			and barFrame.__sbmBarA == aa
			and barFrame.sbTex then
			return
		end
		barFrame.__sbmBarTex = texPath
		barFrame.__sbmBarR = r
		barFrame.__sbmBarG = g
		barFrame.__sbmBarB = b
		barFrame.__sbmBarA = aa
	else
		barFrame.__sbmBarTex = nil
		barFrame.__sbmBarR = nil
		barFrame.__sbmBarG = nil
		barFrame.__sbmBarB = nil
		barFrame.__sbmBarA = nil
	end

	barFrame.sb:SetStatusBarTexture(texPath)
	local tex = barFrame.sb:GetStatusBarTexture()
	barFrame.sbTex = tex
	barFrame.sb:SetStatusBarColor(r, g, b, aa)
	if tex then
		tex:SetDrawLayer("ARTWORK")
		tex:SetVertexColor(r, g, b, aa)
	end
end

M.setBarFillFlat = setBarFillFlat

-- =========================
-- Tooltips
-- =========================
local function isSecretValue(value)
	return type(issecretvalue) == "function" and issecretvalue(value)
end

local function getEventRecordFromFrame(frame)
	if not frame then return nil end
	local id = frame.__id
	if not id and frame.__owner and frame.__owner.__id then
		id = frame.__owner.__id
	end
	if not id then return nil end
	if not M.events then return nil end
	return M.events[id]
end

local function trySetSpellTooltip(spellID)
	if not GameTooltip then return false end
	if isSecretValue(spellID) then
		if not GameTooltip.SetSpellByID then return false end
		local ok, result = pcall(GameTooltip.SetSpellByID, GameTooltip, spellID)
		return ok and result ~= false
	end

	local numeric = tonumber(spellID)
	if type(numeric) ~= "number" or numeric <= 0 then
		return false
	end

	if GameTooltip.SetSpellByID then
		local ok, result = pcall(GameTooltip.SetSpellByID, GameTooltip, numeric)
		if ok and result ~= false then
			return true
		end
	end

	if GameTooltip.SetHyperlink then
		local linkID = math.floor(numeric + 0.5)
		local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "spell:" .. tostring(linkID))
		if ok then
			return true
		end
	end

	return false
end

local function parseTooltipSpellID(value)
	if isSecretValue(value) then
		local ok, asString = pcall(tostring, value)
		if not ok or type(asString) ~= "string" then
			return nil
		end
		local trimmedSecret = asString:match("^%s*(.-)%s*$")
		if trimmedSecret == "" then
			return nil
		end
		local secretNumeric = tonumber(trimmedSecret)
			or tonumber(trimmedSecret:match("^spell:(%d+)$"))
			or tonumber(trimmedSecret:match("^Timer(%d+)"))
			or tonumber(trimmedSecret:match("^Timerej(%d+)"))
			or tonumber(trimmedSecret:match("^ej(%d+)$"))
		if secretNumeric and secretNumeric > 0 then
			return secretNumeric
		end
		return nil
	end

	if type(value) == "number" then
		if value > 0 then
			return value
		end
		return nil
	end

	if type(value) ~= "string" then
		return nil
	end

	local trimmed = value:match("^%s*(.-)%s*$")
	if trimmed == "" then
		return nil
	end

	local numeric = tonumber(trimmed)
	if numeric and numeric > 0 then
		return numeric
	end

	numeric = tonumber(trimmed:match("^spell:(%d+)$"))
		or tonumber(trimmed:match("^Timer(%d+)"))
		or tonumber(trimmed:match("^Timerej(%d+)"))
		or tonumber(trimmed:match("^ej(%d+)$"))
	if numeric and numeric > 0 then
		return numeric
	end

	return nil
end

local function showEventTooltip(self)
	if not GameTooltip then return end
	local rec = getEventRecordFromFrame(self)
	if not rec then return end
	if type(GameTooltip_SetDefaultAnchor) == "function" then
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
	else
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
	end

	local eventInfo = rec.eventInfo
	local usedSpell = false
	if eventInfo then
		local parsedSpellID = parseTooltipSpellID(eventInfo.spellID)
		if parsedSpellID ~= nil then
			usedSpell = trySetSpellTooltip(parsedSpellID)
		end
	end

	if not usedSpell then
		local label = eventInfo and U.safeGetLabel(eventInfo) or nil
		if not isSecretValue(label) then
			if not label or label == "" then
				if type(rec.id) == "number" then
					label = "Event " .. tostring(rec.id)
				else
					label = "Ability"
				end
			end
		end
		GameTooltip:SetText(label or "Ability", 1, 1, 1, 1, true)
	end
	GameTooltip:Show()
end

local function hideEventTooltip(self)
	if not GameTooltip then return end
	if GameTooltip:IsOwned(self) then
		GameTooltip:Hide()
	end
end

local function iconTooltipOnEnter(self)
	showEventTooltip(self)
end

local function barIconTooltipOnEnter(self)
	showEventTooltip(self)
end

local function barTooltipOnEnter(self)
	showEventTooltip(self)
end

-- =========================
-- Pools
-- =========================
local pools = M.pools or { icon = {}, bar = {} }
M.pools = pools

local iconPool = pools.icon
local barPool = pools.bar

local function applyIconFont(fs)
	if not fs then return end
	fs:SetFont(L.ICON_FONT_PATH or L.FONT_PATH or C.FONT_PATH, L.ICON_FONT_SIZE, C.FONT_FLAGS)
	fs:SetShadowColor(0, 0, 0, 0)
	fs:SetShadowOffset(0, 0)
end

local function applyBarFont(fs)
	if not fs then return end
	fs:SetFont(L.FONT_PATH or C.FONT_PATH, L.BAR_FONT_SIZE, C.FONT_FLAGS)
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

		local pauseIcon = tf:CreateTexture(nil, "OVERLAY")
		pauseIcon:SetTexture(C.PAUSE_STATE_ICON)
		pauseIcon:SetPoint("TOPRIGHT", tf, "TOPRIGHT", -2, -2)
		pauseIcon:Hide()
		f.pauseIcon = pauseIcon

		local blockedIcon = tf:CreateTexture(nil, "OVERLAY")
		blockedIcon:SetTexture(C.BLOCKED_STATE_ICON)
		blockedIcon:SetPoint("TOPRIGHT", tf, "TOPRIGHT", -2, -2)
		blockedIcon:Hide()
		f.blockedIcon = blockedIcon

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

		f:EnableMouse(true)
		if f.SetMouseClickEnabled then
			f:SetMouseClickEnabled(false)
		end
		f:SetScript("OnEnter", iconTooltipOnEnter)
		f:SetScript("OnLeave", hideEventTooltip)
		f:SetScript("OnHide", hideEventTooltip)
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
	if f.pauseIcon and f.textOverlay then
		f.pauseIcon:SetDrawLayer("OVERLAY")
	end
	if f.blockedIcon and f.textOverlay then
		f.blockedIcon:SetDrawLayer("OVERLAY")
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
	if f.tex.SetDesaturated then
		f.tex:SetDesaturated(false)
	end
	f.tex:SetVertexColor(1, 1, 1, 1)
	ensureFullBorder(f.main, L.ICON_BORDER_THICKNESS, 0, 0, 0, 1)
	if f.cd then f.cd:Clear() end
	if f.timeText then f.timeText:SetText("") end
	if f.pauseIcon then f.pauseIcon:Hide() end
	if f.blockedIcon then f.blockedIcon:Hide() end

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
		f:EnableMouse(true)
		if f.SetMouseClickEnabled then
			f:SetMouseClickEnabled(false)
		end
		f:SetScript("OnEnter", barTooltipOnEnter)
		f:SetScript("OnLeave", hideEventTooltip)
		f:SetScript("OnHide", hideEventTooltip)

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
		iconFrame.__owner = f
		iconFrame:EnableMouse(true)
		if iconFrame.SetMouseClickEnabled then
			iconFrame:SetMouseClickEnabled(false)
		end
		iconFrame:SetScript("OnEnter", barIconTooltipOnEnter)
		iconFrame:SetScript("OnLeave", hideEventTooltip)
		iconFrame:SetScript("OnHide", hideEventTooltip)

		local icon = iconFrame:CreateTexture(nil, "ARTWORK")
		icon:SetAllPoints()
		f.icon = icon

		local sb = CreateFrame("StatusBar", nil, f)
		sb:SetPoint("LEFT", leftFrame, "RIGHT", 0, 0)
		sb:SetPoint("TOP", f, "TOP", 0, 0)
		sb:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
		sb:SetPoint("RIGHT", f, "RIGHT", 0, 0)
		sb:SetStatusBarTexture(L.BAR_TEX or C.BAR_TEX_DEFAULT)
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
	if M and M.ClearBarAnimation then
		M:ClearBarAnimation(f)
	end
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
