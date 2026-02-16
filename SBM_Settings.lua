-- SimpleBossMods settings panel and live config apply.

local ADDON_NAME = ...
local M = _G[ADDON_NAME]
if not M then return end

local C = M.Const
local L = M.Live
local U = M.Util
local AG = LibStub and LibStub("AceGUI-3.0", true)
local LSM = M.LSM or (LibStub and LibStub("LibSharedMedia-3.0", true))
local isGUIOpen = false

local ANCHOR_POINT_OPTIONS = {
	{ label = "Top Left", value = "TOPLEFT" },
	{ label = "Top", value = "TOP" },
	{ label = "Top Right", value = "TOPRIGHT" },
	{ label = "Left", value = "LEFT" },
	{ label = "Center", value = "CENTER" },
	{ label = "Right", value = "RIGHT" },
	{ label = "Bottom Left", value = "BOTTOMLEFT" },
	{ label = "Bottom", value = "BOTTOM" },
	{ label = "Bottom Right", value = "BOTTOMRIGHT" },
}

local ANCHOR_PARENT_OPTIONS = {
	{ label = "UIParent", value = "NONE" },
	{ label = "SBM: Icons", value = "SimpleBossMods_Icons" },
	{ label = "SBM: Bars", value = "SimpleBossMods_Bars" },
	{ label = "SBM: Private Auras", value = "SimpleBossMods_PrivateAuras" },
	{ label = "Blizzard: Player Frame", value = "PlayerFrame" },
	{ label = "Blizzard: Target Frame", value = "TargetFrame" },
	{ label = "Blizzard: Focus Frame", value = "FocusFrame" },
	{ label = "Blizzard: Minimap", value = "MinimapCluster" },
}

local ANCHOR_POINT_MAP = {
	TOPLEFT = "Top Left",
	TOP = "Top",
	TOPRIGHT = "Top Right",
	LEFT = "Left",
	CENTER = "Center",
	RIGHT = "Right",
	BOTTOMLEFT = "Bottom Left",
	BOTTOM = "Bottom",
	BOTTOMRIGHT = "Bottom Right",
}

local function isAddonLoaded(name)
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		return C_AddOns.IsAddOnLoaded(name)
	end
	if IsAddOnLoaded then
		return IsAddOnLoaded(name)
	end
	return false
end

local function buildAnchorParentLists(currentValue)
	local list = {}
	local map = {}
	local function add(label, value)
		if map[value] then return end
		list[#list + 1] = { label = label, value = value }
		map[value] = label
	end

	for _, opt in ipairs(ANCHOR_PARENT_OPTIONS) do
		add(opt.label, opt.value)
	end

	if isAddonLoaded("BetterCooldownManager") then
		add("BCDM: Essential Cooldown Viewer", "EssentialCooldownViewer")
		add("BCDM: Utility Cooldown Viewer", "UtilityCooldownViewer")
		add("BCDM: Power Bar", "BCDM_PowerBar")
		add("BCDM: Secondary Power Bar", "BCDM_SecondaryPowerBar")
		add("BCDM: Cast Bar", "BCDM_CastBar")
		add("BCDM: Trinket Bar", "BCDM_TrinketBar")
		add("BCDM: Custom Cooldown Viewer", "BCDM_CustomCooldownViewer")
		add("BCDM: Custom Item Bar", "BCDM_CustomItemBar")
		add("BCDM: Custom Item Spell Bar", "BCDM_CustomItemSpellBar")
		add("BCDM: Additional Custom Viewer", "BCDM_AdditionalCustomCooldownViewer")
	end

	if isAddonLoaded("UnhaltedUnitFrames") then
		add("UUF: Player Frame", "UUF_Player")
		add("UUF: Target Frame", "UUF_Target")
		add("UUF: Focus Frame", "UUF_Focus")
		add("UUF: Pet Frame", "UUF_Pet")
		add("UUF: Target Target", "UUF_TargetTarget")
		add("UUF: Focus Target", "UUF_FocusTarget")
		add("UUF: CDM Anchor", "UUF_CDMAnchor")
	end

	if currentValue and currentValue ~= "" and not map[currentValue] then
		add(currentValue, currentValue)
	end

	return list, map
end

local function refreshBarFrame(f, isPool)
	if not f then return end
	f:SetSize(L.BAR_WIDTH, L.BAR_HEIGHT)
	M.ensureFullBorder(f, L.BAR_BORDER_THICKNESS)

	if M.applyBarMirror then
		M.applyBarMirror(f)
	else
		if f.leftFrame then
			f.leftFrame:SetWidth(L.BAR_HEIGHT)
			M.ensureRightDivider(f.leftFrame, L.BAR_BORDER_THICKNESS)
		end
		if f.iconFrame then
			f.iconFrame:SetSize(L.BAR_HEIGHT, L.BAR_HEIGHT)
		end
	end

	if isPool and f.endIndicatorsFrame then
		f.endIndicatorsFrame:SetWidth(1)
	end
	if f.txt then M.applyBarFont(f.txt) end
	if f.rt then M.applyBarFont(f.rt) end
	M.setBarFillFlat(f, L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A)
	if f.bg then
		f.bg:SetColorTexture(L.BAR_BG_R, L.BAR_BG_G, L.BAR_BG_B, 1)
		f.bg:SetAlpha(L.BAR_BG_A)
	end
end

local function refreshBarMirrorAndIndicators()
	for _, rec in pairs(M.events) do
		if rec.barFrame then
			M.applyBarMirror(rec.barFrame)
			M.applyIndicatorsToBarEnd(rec.barFrame, rec.id)
		end
	end
	for _, f in ipairs(M.pools.bar) do
		M.applyBarMirror(f)
	end
	M:LayoutAll()
end

-- =========================
-- Apply config live
-- =========================
function M:ApplyGeneralConfig(gap, autoInsertKeystone)
	SimpleBossModsDB.cfg.general.gap = tonumber(gap) or (SimpleBossModsDB.cfg.general.gap or 6)
	if autoInsertKeystone == nil then
		SimpleBossModsDB.cfg.general.autoInsertKeystone = SimpleBossModsDB.cfg.general.autoInsertKeystone and true or false
	else
		SimpleBossModsDB.cfg.general.autoInsertKeystone = autoInsertKeystone and true or false
	end

	M.SyncLiveConfig()
	if M.SetupKeystoneAutoInsert then
		M:SetupKeystoneAutoInsert()
	end
	M:LayoutAll()
end

function M:ApplyConnectorHideDBMBars(enabled)
	SimpleBossModsDB.cfg.connectors = SimpleBossModsDB.cfg.connectors or {}
	SimpleBossModsDB.cfg.connectors.hideDBMBars = enabled and true or false
	M.SyncLiveConfig()
	if self.ApplyDBMConnectorBarVisibility then
		self:ApplyDBMConnectorBarVisibility(self.GetActiveConnectorID and self:GetActiveConnectorID() or nil)
	end
end

function M:ApplyConnectorHideBigWigsBars(enabled)
	SimpleBossModsDB.cfg.connectors = SimpleBossModsDB.cfg.connectors or {}
	SimpleBossModsDB.cfg.connectors.hideBigWigsBars = enabled and true or false
	M.SyncLiveConfig()
	if self.ApplyBigWigsConnectorBarVisibility then
		self:ApplyBigWigsConnectorBarVisibility(self.GetActiveConnectorID and self:GetActiveConnectorID() or nil)
	end
end

function M:ApplyConnectorUseRecommendedSettings(enabled)
	SimpleBossModsDB.cfg.connectors = SimpleBossModsDB.cfg.connectors or {}
	SimpleBossModsDB.cfg.connectors.useRecommendedSettings = enabled and true or false
	M.SyncLiveConfig()
	if self.ApplyTimelineConnectorMode then
		self:ApplyTimelineConnectorMode()
	end
	if not enabled and self.GetActiveConnectorID and self:GetActiveConnectorID() == "timeline" then
		local timelineFrame = _G.EncounterTimeline
		if timelineFrame and type(timelineFrame.Show) == "function" then
			pcall(timelineFrame.Show, timelineFrame)
		end
	end
end

function M:ApplyConnectorDisableBlizzardTimeline(enabled)
	SimpleBossModsDB.cfg.connectors = SimpleBossModsDB.cfg.connectors or {}
	SimpleBossModsDB.cfg.connectors.disableBlizzardTimeline = enabled and true or false
	M.SyncLiveConfig()
	if self.ApplyConnectorTimelineState then
		self:ApplyConnectorTimelineState(self.GetActiveConnectorID and self:GetActiveConnectorID() or nil)
	end
end

function M:ApplyConnectorUseDBMColors(enabled)
	SimpleBossModsDB.cfg.connectors = SimpleBossModsDB.cfg.connectors or {}
	SimpleBossModsDB.cfg.connectors.useDBMColors = enabled and true or false
	M.SyncLiveConfig()
	if self.GetActiveConnectorID and self:GetActiveConnectorID() == "dbm" then
		if self.Tick then
			self:Tick()
		end
		if self.LayoutAll then
			self:LayoutAll()
		end
	end
end

function M:ApplyConnectorBigWigsColorMode(mode)
	SimpleBossModsDB.cfg.connectors = SimpleBossModsDB.cfg.connectors or {}
	mode = (type(mode) == "string") and mode:lower() or "normal"
	if mode ~= "emphasized" then
		mode = "normal"
	end
	SimpleBossModsDB.cfg.connectors.bigWigsColorMode = mode
	M.SyncLiveConfig()
	if self.GetActiveConnectorID and self:GetActiveConnectorID() == "bigwigs" then
		if self.Tick then
			self:Tick()
		end
		if self.LayoutAll then
			self:LayoutAll()
		end
	end
end

function M:ApplyIconConfig(size, fontSize, borderThickness)
	local ic = SimpleBossModsDB.cfg.icons
	ic.size = U.clamp(U.round(size), 16, 128)
	ic.fontSize = U.clamp(U.round(fontSize), 10, 48)
	ic.borderThickness = U.clamp(U.round(borderThickness), 0, 6)

	M.SyncLiveConfig()

	for _, rec in pairs(self.events) do
		if rec.iconFrame then
			rec.iconFrame:SetSize(L.ICON_SIZE, L.ICON_SIZE)
			M.ensureFullBorder(rec.iconFrame.main, L.ICON_BORDER_THICKNESS)
			M.applyIconFont(rec.iconFrame.timeText)
		end
	end
	for _, f in ipairs(M.pools.icon) do
		f:SetSize(L.ICON_SIZE, L.ICON_SIZE)
		M.ensureFullBorder(f.main, L.ICON_BORDER_THICKNESS)
		M.applyIconFont(f.timeText)
	end

	self:LayoutAll()
end

function M:ApplyIconEnabled(enabled)
	local ic = SimpleBossModsDB.cfg.icons
	ic.enabled = enabled and true or false

	M.SyncLiveConfig()

	if not ic.enabled then
		for _, rec in pairs(self.events) do
			if rec.iconFrame then
				M.releaseIcon(rec.iconFrame)
				rec.iconFrame = nil
			end
		end
	else
		for id, rec in pairs(self.events) do
			self:updateRecord(id, rec.eventInfo, rec.remaining)
		end
	end

	self:LayoutAll()
end

function M:ApplyIconLayoutConfig(gap, perRow, limit)
	local ic = SimpleBossModsDB.cfg.icons
	local g = tonumber(gap)
	if g == nil then g = ic.gap end
	ic.gap = U.clamp(U.round(g), -50, 50)

	local pr = tonumber(perRow)
	if pr == nil then pr = ic.perRow end
	ic.perRow = U.clamp(U.round(pr), 1, 20)

	local lim = tonumber(limit)
	if lim == nil then lim = ic.limit end
	ic.limit = U.clamp(U.round(lim), 0, 200)

	M.SyncLiveConfig()
	self:LayoutAll()
end

function M:ApplyIconGrowDirection(dir)
	local ic = SimpleBossModsDB.cfg.icons
	if type(dir) == "string" then
		local v = dir:upper():gsub("%s+", "_")
		if v == "BOTTOM_DOWN" then
			v = "LEFT_DOWN"
		elseif v == "BOTTOM_UP" then
			v = "LEFT_UP"
		end
		if v == "LEFT_DOWN" or v == "LEFT_UP" or v == "RIGHT_DOWN" or v == "RIGHT_UP" then
			ic.growDirection = v
		end
	end
	M.SyncLiveConfig()
	self:LayoutAll()
end

function M:ApplyIconAnchorFrom(point)
	local ic = SimpleBossModsDB.cfg.icons
	if type(point) == "string" and point ~= "" then
		ic.anchorFrom = point
	end
	M.SyncLiveConfig()
	if M.UpdateIconsAnchorPosition then
		M:UpdateIconsAnchorPosition()
	end
end

function M:ApplyIconAnchorTo(point)
	local ic = SimpleBossModsDB.cfg.icons
	if type(point) == "string" and point ~= "" then
		ic.anchorTo = point
	end
	M.SyncLiveConfig()
	if M.UpdateIconsAnchorPosition then
		M:UpdateIconsAnchorPosition()
	end
end

function M:ApplyIconAnchorParent(parentName)
	local ic = SimpleBossModsDB.cfg.icons
	if type(parentName) == "string" and parentName ~= "" then
		ic.anchorParent = parentName
	end
	ic.customParent = ""
	M.SyncLiveConfig()
	if M.UpdateIconsAnchorPosition then
		M:UpdateIconsAnchorPosition()
	end
end

function M:ApplyIconCustomParent(name)
	local ic = SimpleBossModsDB.cfg.icons
	if type(name) ~= "string" then
		name = ""
	end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	ic.customParent = name
	M.SyncLiveConfig()
	if M.UpdateIconsAnchorPosition then
		M:UpdateIconsAnchorPosition()
	end
end

function M:ApplyIconAnchorPosition(x, y)
	local ic = SimpleBossModsDB.cfg.icons
	ic.x = tonumber(x) or ic.x or 0
	ic.y = tonumber(y) or ic.y or 0
	M.SyncLiveConfig()
	if M.UpdateIconsAnchorPosition then
		M:UpdateIconsAnchorPosition()
	end
end

function M:ApplyBarGrowDirection(dir)
	local bc = SimpleBossModsDB.cfg.bars
	if type(dir) == "string" then
		local v = dir:upper()
		if v == "UP" or v == "DOWN" then
			bc.growDirection = v
		end
	end
	M.SyncLiveConfig()
	self:LayoutAll()
end

function M:ApplyBarSortOrder(order)
	local bc = SimpleBossModsDB.cfg.bars
	if order == "ASC" then
		bc.sortAscending = true
	elseif order == "DESC" then
		bc.sortAscending = false
	end
	M.SyncLiveConfig()
	self:LayoutAll()
end

function M:ApplyBarFillDirection(dir)
	local bc = SimpleBossModsDB.cfg.bars
	if type(dir) == "string" then
		local v = dir:upper()
		if v == "LEFT" or v == "RIGHT" then
			bc.fillDirection = v
		end
	end
	M.SyncLiveConfig()
	refreshBarMirrorAndIndicators()
end

function M:ApplyBarAnchorFrom(point)
	local bc = SimpleBossModsDB.cfg.bars
	if type(point) == "string" and point ~= "" then
		bc.anchorFrom = point
	end
	M.SyncLiveConfig()
	if M.UpdateBarsAnchorPosition then
		M:UpdateBarsAnchorPosition()
	end
end

function M:ApplyBarAnchorTo(point)
	local bc = SimpleBossModsDB.cfg.bars
	if type(point) == "string" and point ~= "" then
		bc.anchorTo = point
	end
	M.SyncLiveConfig()
	if M.UpdateBarsAnchorPosition then
		M:UpdateBarsAnchorPosition()
	end
end

function M:ApplyBarAnchorParent(parentName)
	local bc = SimpleBossModsDB.cfg.bars
	if type(parentName) == "string" and parentName ~= "" then
		bc.anchorParent = parentName
	end
	bc.customParent = ""
	M.SyncLiveConfig()
	if M.UpdateBarsAnchorPosition then
		M:UpdateBarsAnchorPosition()
	end
end

function M:ApplyBarCustomParent(name)
	local bc = SimpleBossModsDB.cfg.bars
	if type(name) ~= "string" then
		name = ""
	end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	bc.customParent = name
	M.SyncLiveConfig()
	if M.UpdateBarsAnchorPosition then
		M:UpdateBarsAnchorPosition()
	end
end

function M:ApplyBarAnchorPosition(x, y)
	local bc = SimpleBossModsDB.cfg.bars
	bc.x = tonumber(x) or bc.x or 0
	bc.y = tonumber(y) or bc.y or 0
	M.SyncLiveConfig()
	if M.UpdateBarsAnchorPosition then
		M:UpdateBarsAnchorPosition()
	end
end

function M:ApplyBarConfig(width, height, fontSize, borderThickness)
	local bc = SimpleBossModsDB.cfg.bars
	bc.width = U.clamp(U.round(width), 120, 800)
	bc.height = U.clamp(U.round(height), 12, 80)
	bc.fontSize = U.clamp(U.round(fontSize), 8, 32)
	bc.borderThickness = U.clamp(U.round(borderThickness), 1, 6)

	M.SyncLiveConfig()

	for _, rec in pairs(self.events) do
		if rec.barFrame then
			refreshBarFrame(rec.barFrame, false)
		end
	end
	for _, f in ipairs(M.pools.bar) do
		refreshBarFrame(f, true)
	end

	self:LayoutAll()
end

function M:ApplyBarIconSideConfig(swapIconSide)
	local bc = SimpleBossModsDB.cfg.bars
	bc.swapIconSide = swapIconSide and true or false

	M.SyncLiveConfig()
	refreshBarMirrorAndIndicators()
end

function M:ApplyBarIndicatorSideConfig(swapIndicatorSide)
	local bc = SimpleBossModsDB.cfg.bars
	bc.swapIndicatorSide = swapIndicatorSide and true or false

	M.SyncLiveConfig()
	refreshBarMirrorAndIndicators()
end

function M:ApplyBarIconVisibilityConfig(hideIcon)
	local bc = SimpleBossModsDB.cfg.bars
	bc.hideIcon = hideIcon and true or false

	M.SyncLiveConfig()
	refreshBarMirrorAndIndicators()
end

function M:ApplyBarThresholdConfig(threshold)
	local gc = SimpleBossModsDB.cfg.general
	local v = tonumber(threshold)
	if v == nil then
		v = gc.thresholdToBar or C.THRESHOLD_TO_BAR
	end
	gc.thresholdToBar = U.clamp(v, 0.1, 600)

	M.SyncLiveConfig()

	for id, rec in pairs(self.events) do
		self:updateRecord(id, rec.eventInfo, rec.remaining)
	end

	self:LayoutAll()
end

function M:ApplyBarColor(r, g, b, a)
	local bc = SimpleBossModsDB.cfg.bars
	bc.color = bc.color or {}
	bc.color.r = U.clamp(tonumber(r) or L.BAR_FG_R, 0, 1)
	bc.color.g = U.clamp(tonumber(g) or L.BAR_FG_G, 0, 1)
	bc.color.b = U.clamp(tonumber(b) or L.BAR_FG_B, 0, 1)
	bc.color.a = U.clamp(tonumber(a) or L.BAR_FG_A, 0, 1)

	M.SyncLiveConfig()

	for id, rec in pairs(self.events) do
		self:updateRecord(id, rec.eventInfo, rec.remaining)
	end
	for _, f in ipairs(M.pools.bar) do
		M.setBarFillFlat(f, L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A)
	end
	self:LayoutAll()
end

function M:ApplySeverityColor(level, r, g, b, a)
	local key = tostring(level or ""):lower()
	if key ~= "low" and key ~= "medium" and key ~= "high" then
		return
	end

	local cfg = SimpleBossModsDB.cfg
	cfg.colors = cfg.colors or {}
	cfg.colors.severity = cfg.colors.severity or {}
	cfg.colors.severity[key] = cfg.colors.severity[key] or {}

	local target = cfg.colors.severity[key]
	if key == "low" then
		target.r = U.clamp(tonumber(r) or L.SEVERITY_LOW_R, 0, 1)
		target.g = U.clamp(tonumber(g) or L.SEVERITY_LOW_G, 0, 1)
		target.b = U.clamp(tonumber(b) or L.SEVERITY_LOW_B, 0, 1)
		target.a = U.clamp(tonumber(a) or L.SEVERITY_LOW_A, 0, 1)
	elseif key == "high" then
		target.r = U.clamp(tonumber(r) or L.SEVERITY_HIGH_R, 0, 1)
		target.g = U.clamp(tonumber(g) or L.SEVERITY_HIGH_G, 0, 1)
		target.b = U.clamp(tonumber(b) or L.SEVERITY_HIGH_B, 0, 1)
		target.a = U.clamp(tonumber(a) or L.SEVERITY_HIGH_A, 0, 1)
	else
		target.r = U.clamp(tonumber(r) or L.SEVERITY_MEDIUM_R, 0, 1)
		target.g = U.clamp(tonumber(g) or L.SEVERITY_MEDIUM_G, 0, 1)
		target.b = U.clamp(tonumber(b) or L.SEVERITY_MEDIUM_B, 0, 1)
		target.a = U.clamp(tonumber(a) or L.SEVERITY_MEDIUM_A, 0, 1)
	end

	M.SyncLiveConfig()

	for id, rec in pairs(self.events) do
		self:updateRecord(id, rec.eventInfo, rec.remaining)
	end
	for _, f in ipairs(M.pools.bar) do
		M.setBarFillFlat(f, L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A)
	end
	self:LayoutAll()
end

function M:ApplyBarBgColor(r, g, b, a)
	local bc = SimpleBossModsDB.cfg.bars
	bc.bgColor = bc.bgColor or {}
	bc.bgColor.r = U.clamp(tonumber(r) or L.BAR_BG_R, 0, 1)
	bc.bgColor.g = U.clamp(tonumber(g) or L.BAR_BG_G, 0, 1)
	bc.bgColor.b = U.clamp(tonumber(b) or L.BAR_BG_B, 0, 1)
	bc.bgColor.a = U.clamp(tonumber(a) or L.BAR_BG_A, 0, 1)

	M.SyncLiveConfig()

	for _, rec in pairs(self.events) do
		if rec.barFrame and rec.barFrame.bg then
			rec.barFrame.bg:SetColorTexture(L.BAR_BG_R, L.BAR_BG_G, L.BAR_BG_B, 1)
			rec.barFrame.bg:SetAlpha(L.BAR_BG_A)
		end
	end
	for _, f in ipairs(M.pools.bar) do
		if f.bg then
			f.bg:SetColorTexture(L.BAR_BG_R, L.BAR_BG_G, L.BAR_BG_B, 1)
			f.bg:SetAlpha(L.BAR_BG_A)
		end
	end
end

function M:ApplyFontConfig(fontKey)
	local gc = SimpleBossModsDB.cfg.general
	gc.font = fontKey or M.Defaults.cfg.general.font

	M.SyncLiveConfig()

	for _, rec in pairs(self.events) do
		if rec.barFrame then
			if rec.barFrame.txt then M.applyBarFont(rec.barFrame.txt) end
			if rec.barFrame.rt then M.applyBarFont(rec.barFrame.rt) end
		end
	end
	for _, f in ipairs(M.pools.bar) do
		if f.txt then M.applyBarFont(f.txt) end
		if f.rt then M.applyBarFont(f.rt) end
	end
	if self.UpdateTestPrivateAura then
		self:UpdateTestPrivateAura()
	end
end

function M:ApplyBarTextureConfig(textureKey)
	local bc = SimpleBossModsDB.cfg.bars
	bc.texture = textureKey or M.Defaults.cfg.bars.texture

	M.SyncLiveConfig()

	for id, rec in pairs(self.events) do
		self:updateRecord(id, rec.eventInfo, rec.remaining)
	end
	for _, f in ipairs(M.pools.bar) do
		M.setBarFillFlat(f, L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A)
	end
	self:LayoutAll()
end

function M:ApplyIconFontConfig(fontKey)
	local ic = SimpleBossModsDB.cfg.icons
	ic.font = fontKey or M.Defaults.cfg.icons.font

	M.SyncLiveConfig()

	for _, rec in pairs(self.events) do
		if rec.iconFrame then
			M.applyIconFont(rec.iconFrame.timeText)
		end
	end
	for _, f in ipairs(M.pools.icon) do
		M.applyIconFont(f.timeText)
	end
end

function M:ApplyIndicatorConfig(iconSize, barSize)
	local ic = SimpleBossModsDB.cfg.indicators
	ic.iconSize = U.clamp(U.round(iconSize), 0, 32)
	ic.barSize = U.clamp(U.round(barSize), 0, 32)

	M.SyncLiveConfig()

	for _, rec in pairs(self.events) do
		if rec.iconFrame then
			M.applyIndicatorsToIconFrame(rec.iconFrame, rec.id)
		end
		if rec.barFrame then
			M.applyIndicatorsToBarEnd(rec.barFrame, rec.id)
		end
	end

	self:LayoutAll()
end

function M:ApplyPrivateAuraConfig(size, gap, growDirection, x, y)
	local pc = SimpleBossModsDB.cfg.privateAuras
	pc.size = U.clamp(U.round(size), 16, 128)
	pc.gap = U.clamp(U.round(gap), 0, 50)
	if type(growDirection) == "string" then
		local dir = growDirection:upper()
		if dir == "LEFT" or dir == "RIGHT" or dir == "UP" or dir == "DOWN" then
			pc.growDirection = dir
		end
	end
	pc.x = tonumber(x) or pc.x or 0
	pc.y = tonumber(y) or pc.y or 0

	M.SyncLiveConfig()
	if M.UpdatePrivateAuraAnchorPosition then
		M:UpdatePrivateAuraAnchorPosition()
	end
	if M.UpdatePrivateAuraAnchor then
		M:UpdatePrivateAuraAnchor()
	end
end

function M:ApplyPrivateAuraEnabled(enabled)
	local pc = SimpleBossModsDB.cfg.privateAuras
	pc.enabled = enabled and true or false
	M.SyncLiveConfig()
	if not pc.enabled then
		if M.ShowTestPrivateAura then
			M:ShowTestPrivateAura(false)
		end
	end
	if M.UpdatePrivateAuraAnchor then
		M:UpdatePrivateAuraAnchor()
	end
	if M.UpdatePrivateAuraFrames then
		M:UpdatePrivateAuraFrames()
	end
	if pc.enabled and M._testActive and M.ShowTestPrivateAura then
		M:ShowTestPrivateAura(true)
	end
end

function M:ApplyPrivateAuraPosition(x, y)
	local pc = SimpleBossModsDB.cfg.privateAuras
	pc.x = tonumber(x) or pc.x or 0
	pc.y = tonumber(y) or pc.y or 0
	M.SyncLiveConfig()
	if M.UpdatePrivateAuraAnchorPosition then
		M:UpdatePrivateAuraAnchorPosition()
	end
end

function M:ApplyPrivateAuraAnchorFrom(point)
	local pc = SimpleBossModsDB.cfg.privateAuras
	if type(point) == "string" and point ~= "" then
		pc.anchorFrom = point
	end
	M.SyncLiveConfig()
	if M.UpdatePrivateAuraAnchorPosition then
		M:UpdatePrivateAuraAnchorPosition()
	end
end

function M:ApplyPrivateAuraAnchorTo(point)
	local pc = SimpleBossModsDB.cfg.privateAuras
	if type(point) == "string" and point ~= "" then
		pc.anchorTo = point
	end
	M.SyncLiveConfig()
	if M.UpdatePrivateAuraAnchorPosition then
		M:UpdatePrivateAuraAnchorPosition()
	end
end

function M:ApplyPrivateAuraAnchorParent(parentName)
	local pc = SimpleBossModsDB.cfg.privateAuras
	if type(parentName) == "string" and parentName ~= "" then
		pc.anchorParent = parentName
	end
	pc.customParent = ""
	M.SyncLiveConfig()
	if M.UpdatePrivateAuraAnchorPosition then
		M:UpdatePrivateAuraAnchorPosition()
	end
end

function M:ApplyPrivateAuraCustomParent(name)
	local pc = SimpleBossModsDB.cfg.privateAuras
	if type(name) ~= "string" then
		name = ""
	end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	pc.customParent = name
	M.SyncLiveConfig()
	if M.UpdatePrivateAuraAnchorPosition then
		M:UpdatePrivateAuraAnchorPosition()
	end
end

-- =========================
-- Combat Timer config
-- =========================
function M:ApplyCombatTimerEnabled(enabled)
	local ct = SimpleBossModsDB.cfg.combatTimer
	ct.enabled = enabled and true or false
	M.SyncLiveConfig()
	if M.UpdateCombatTimerState then
		M:UpdateCombatTimerState()
	end
	if ct.enabled and M._testActive and M.StartCombatTimer then
		M._testCombatTimer = true
		M:StartCombatTimer(true)
	end
	if not ct.enabled then
		M._testCombatTimer = nil
	end
end

function M:ApplyCombatTimerFont(fontKey)
	local ct = SimpleBossModsDB.cfg.combatTimer
	ct.font = fontKey or M.Defaults.cfg.combatTimer.font
	M.SyncLiveConfig()
	if M.UpdateCombatTimerAppearance then
		M:UpdateCombatTimerAppearance()
	end
end

function M:ApplyCombatTimerFontSize(size)
	local ct = SimpleBossModsDB.cfg.combatTimer
	ct.fontSize = U.clamp(U.round(size), 8, 72)
	M.SyncLiveConfig()
	if M.UpdateCombatTimerAppearance then
		M:UpdateCombatTimerAppearance()
	end
end

function M:ApplyCombatTimerPosition(x, y)
	local ct = SimpleBossModsDB.cfg.combatTimer
	ct.x = tonumber(x) or ct.x or 0
	ct.y = tonumber(y) or ct.y or 0
	M.SyncLiveConfig()
	if M.UpdateCombatTimerAppearance then
		M:UpdateCombatTimerAppearance()
	end
end

function M:ApplyCombatTimerAnchorFrom(point)
	local ct = SimpleBossModsDB.cfg.combatTimer
	if type(point) == "string" and point ~= "" then
		ct.anchorFrom = point
	end
	M.SyncLiveConfig()
	if M.UpdateCombatTimerAppearance then
		M:UpdateCombatTimerAppearance()
	end
end

function M:ApplyCombatTimerAnchorTo(point)
	local ct = SimpleBossModsDB.cfg.combatTimer
	if type(point) == "string" and point ~= "" then
		ct.anchorTo = point
	end
	M.SyncLiveConfig()
	if M.UpdateCombatTimerAppearance then
		M:UpdateCombatTimerAppearance()
	end
end

function M:ApplyCombatTimerAnchorParent(parentName)
	local ct = SimpleBossModsDB.cfg.combatTimer
	if type(parentName) == "string" and parentName ~= "" then
		ct.anchorParent = parentName
	end
	ct.customParent = ""
	M.SyncLiveConfig()
	if M.UpdateCombatTimerAppearance then
		M:UpdateCombatTimerAppearance()
	end
end

function M:ApplyCombatTimerCustomParent(name)
	local ct = SimpleBossModsDB.cfg.combatTimer
	if type(name) ~= "string" then
		name = ""
	end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	ct.customParent = name
	M.SyncLiveConfig()
	if M.UpdateCombatTimerAppearance then
		M:UpdateCombatTimerAppearance()
	end
end

function M:ApplyCombatTimerColor(r, g, b, a)
	local ct = SimpleBossModsDB.cfg.combatTimer
	ct.color = ct.color or {}
	ct.color.r = U.clamp(tonumber(r) or L.COMBAT_TIMER_COLOR_R or 1, 0, 1)
	ct.color.g = U.clamp(tonumber(g) or L.COMBAT_TIMER_COLOR_G or 1, 0, 1)
	ct.color.b = U.clamp(tonumber(b) or L.COMBAT_TIMER_COLOR_B or 1, 0, 1)
	ct.color.a = U.clamp(tonumber(a) or L.COMBAT_TIMER_COLOR_A or 1, 0, 1)
	M.SyncLiveConfig()
	if M.UpdateCombatTimerAppearance then
		M:UpdateCombatTimerAppearance()
	end
end

function M:ApplyCombatTimerBorderColor(r, g, b, a)
	local ct = SimpleBossModsDB.cfg.combatTimer
	ct.borderColor = ct.borderColor or {}
	ct.borderColor.r = U.clamp(tonumber(r) or L.COMBAT_TIMER_BORDER_R or 0, 0, 1)
	ct.borderColor.g = U.clamp(tonumber(g) or L.COMBAT_TIMER_BORDER_G or 0, 0, 1)
	ct.borderColor.b = U.clamp(tonumber(b) or L.COMBAT_TIMER_BORDER_B or 0, 0, 1)
	ct.borderColor.a = U.clamp(tonumber(a) or L.COMBAT_TIMER_BORDER_A or 1, 0, 1)
	M.SyncLiveConfig()
	if M.UpdateCombatTimerAppearance then
		M:UpdateCombatTimerAppearance()
	end
end

function M:ApplyCombatTimerBgColor(r, g, b, a)
	local ct = SimpleBossModsDB.cfg.combatTimer
	ct.bgColor = ct.bgColor or {}
	ct.bgColor.r = U.clamp(tonumber(r) or L.COMBAT_TIMER_BG_R or 0, 0, 1)
	ct.bgColor.g = U.clamp(tonumber(g) or L.COMBAT_TIMER_BG_G or 0, 0, 1)
	ct.bgColor.b = U.clamp(tonumber(b) or L.COMBAT_TIMER_BG_B or 0, 0, 1)
	ct.bgColor.a = U.clamp(tonumber(a) or L.COMBAT_TIMER_BG_A or 1, 0, 1)
	M.SyncLiveConfig()
	if M.UpdateCombatTimerAppearance then
		M:UpdateCombatTimerAppearance()
	end
end

-- =========================
-- Settings Window
-- =========================
function M:OpenSettings()
	if InCombatLockdown() then return end
	local frame = self._settingsWindow
	if not frame then
		frame = self:CreateSettingsWindow()
	end

	if frame then
		if frame.Show then
			frame:Show()
		end
		if frame.Raise then
			frame:Raise()
		end
		if self._settingsTabGroup and self._settingsTabStatus then
			self._settingsTabGroup:SelectTab(self._settingsTabStatus.selected or "Connectors")
		elseif frame._refreshAll then
			frame._refreshAll()
		end
		return
	end

	if Settings and Settings.OpenToCategory and type(self._settingsCategoryID) == "number" then
		Settings.OpenToCategory(self._settingsCategoryID)
	end
end

function M:CreateLegacySettingsWindow()
	if self._settingsWindow then return self._settingsWindow end
	if self.EnsureDefaults then
		self:EnsureDefaults()
	end

	local panel = CreateFrame("Frame", "SimpleBossModsSettings", UIParent, "ButtonFrameTemplate")
	panel:SetSize(420, 640)
	panel:SetPoint("CENTER")
	panel:SetToplevel(true)
	panel:SetFrameStrata("DIALOG")
	panel:SetClampedToScreen(true)
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", panel.StartMoving)
	panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
	panel:Hide()

	if ButtonFrameTemplate_HidePortrait then
		ButtonFrameTemplate_HidePortrait(panel)
	end
	if panel.TitleText then
		panel.TitleText:SetText("Simple Boss Mods")
	end
	if type(UISpecialFrames) == "table" and panel:GetName() then
		table.insert(UISpecialFrames, panel:GetName())
	end

	local inset = panel.Inset or panel
	local TAB_TOP_OFFSET = -34
	local TAB_X_OFFSET = 20
	local BOTTOM_BAR_HEIGHT = 28
	local BOTTOM_BAR_PADDING = 10
	local LABEL_X = 0
	local INPUT_X = 204
	local ROW_H = 26
	local SECTION_INDENT = 8
	local HEADER_SPACING = 6
	local SECTION_SPACING = 12
	local inputs = {}
	local tabs = {}
	local tabsById = {}
	local SelectTab

	panel.tabPadding = 8
	panel.minTabWidth = 70
	panel.maxTabWidth = 140

	local function LayoutTab(tab)
		if not tab then return end
		local content = tab.content
		if not content then return end
		local y = -8
		for _, section in ipairs(tab.sections) do
			local header = section.header
			header:Show()
			header:ClearAllPoints()
			header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
			header:SetPoint("RIGHT", content, "RIGHT", -8, 0)
			header:UpdateCollapsedState(section.collapsed)
			y = y - header:GetHeight() - HEADER_SPACING

			if section.collapsed then
				for _, row in ipairs(section.rows) do
					row:Hide()
				end
			else
				for _, row in ipairs(section.rows) do
					row:Show()
					row:ClearAllPoints()
					row:SetPoint("TOPLEFT", content, "TOPLEFT", section.indent or 0, y)
					row:SetPoint("RIGHT", content, "RIGHT", -8, 0)
					y = y - (row.height or ROW_H)
				end
			end

			y = y - SECTION_SPACING
		end
		content:SetHeight((-y) + 8)
	end

	local function CreateTab(id, label)
		local tab = {
			id = id,
			label = label,
			sections = {},
		}

		local button = CreateFrame("Button", nil, panel, "PanelTopTabButtonTemplate")
		button:SetID(id)
		button:SetText(label)
		if id == 1 then
			button:SetPoint("TOPLEFT", panel, "TOPLEFT", TAB_X_OFFSET, -28)
		end
		tab.button = button

		local scroll = CreateFrame("ScrollFrame", nil, inset, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, TAB_TOP_OFFSET)
		scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -26, 6 + BOTTOM_BAR_HEIGHT + BOTTOM_BAR_PADDING)
		scroll:Hide()

		local content = CreateFrame("Frame", nil, scroll)
		content:SetPoint("TOPLEFT", 0, 0)
		content:SetPoint("TOPRIGHT", 0, 0)
		content:SetHeight(1)
		scroll:SetScrollChild(content)

		tab.scroll = scroll
		tab.content = content

		scroll:HookScript("OnSizeChanged", function(self, width)
			content:SetWidth(width)
			LayoutTab(tab)
		end)
		content:SetWidth(scroll:GetWidth() or 1)

		button:SetScript("OnClick", function()
			SelectTab(id)
		end)

		table.insert(tabs, tab)
		tabsById[id] = tab
		return tab
	end

	SelectTab = function(id)
		local tab = tabsById[id] or tabs[1]
		if not tab then return end
		for _, t in ipairs(tabs) do
			t.scroll:SetShown(t == tab)
		end
		PanelTemplates_SetTab(panel, tab.id)
		LayoutTab(tab)
	end

	local function OpenColorPicker(r, g, b, a, changedCallback)
		if not ColorPickerFrame then return end
		local function getPickerAlpha()
			if ColorPickerFrame.GetColorAlpha then
				return ColorPickerFrame:GetColorAlpha()
			end
			if OpacitySliderFrame and OpacitySliderFrame.GetValue then
				return OpacitySliderFrame:GetValue()
			end
			return a or 1
		end
		local function apply()
			local nr, ng, nb = ColorPickerFrame:GetColorRGB()
			local na = getPickerAlpha()
			changedCallback(nr, ng, nb, na)
		end

		if ColorPickerFrame.SetupColorPickerAndShow then
			local info = {
				r = r,
				g = g,
				b = b,
				opacity = a or 1,
				hasOpacity = true,
				swatchFunc = apply,
				opacityFunc = apply,
				cancelFunc = function(prev)
					if not prev then return end
					local pr = prev.r or r
					local pg = prev.g or g
					local pb = prev.b or b
					local pa = prev.opacity or prev.a or a or 1
					changedCallback(pr, pg, pb, pa)
				end,
				previousValues = { r = r, g = g, b = b, opacity = a or 1 },
			}
			ColorPickerFrame:SetupColorPickerAndShow(info)
			return
		end

		ColorPickerFrame:Hide()
		ColorPickerFrame.hasOpacity = true
		ColorPickerFrame.opacity = 1 - (a or 1)
		ColorPickerFrame.previousValues = { r = r, g = g, b = b, a = a }
		ColorPickerFrame.func = apply
		ColorPickerFrame.opacityFunc = apply
		ColorPickerFrame.cancelFunc = function(prev)
			if not prev then return end
			local pr = prev.r or r
			local pg = prev.g or g
			local pb = prev.b or b
			local pa = prev.a or (prev.opacity and (1 - prev.opacity)) or a or 1
			changedCallback(pr, pg, pb, pa)
		end
		ColorPickerFrame:SetColorRGB(r, g, b)
		ColorPickerFrame:Show()
	end

	local function buildFontOptions()
		if not LSM then return nil end
		local list = {}
		for key in pairs(LSM:HashTable("font")) do
			list[#list + 1] = { label = key, value = key }
		end
		table.sort(list, function(a, b) return a.label < b.label end)
		return list
	end


	local function CreateSection(tab, title, collapsed)
		local header = CreateFrame("Button", nil, tab.content, "ListHeaderThreeSliceTemplate")
		header:SetHeaderText(title)
		local section = {
			header = header,
			rows = {},
			collapsed = collapsed and true or false,
			indent = SECTION_INDENT,
		}
		header:SetClickHandler(function()
			section.collapsed = not section.collapsed
			header:UpdateCollapsedState(section.collapsed)
			LayoutTab(tab)
		end)
		header:UpdateCollapsedState(section.collapsed)
		table.insert(tab.sections, section)
		return section
	end

	local function CreateRow(section, height)
		local row = CreateFrame("Frame", nil, section.header:GetParent())
		row.height = height or ROW_H
		row:SetHeight(row.height)
		table.insert(section.rows, row)
		return row
	end

	local function AddNumberRow(section, label, get, set, tooltip, allowDecimal, allowNegative)
		local row = CreateRow(section, ROW_H)
		local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		fs:SetPoint("LEFT", row, "LEFT", LABEL_X, 0)
		fs:SetText(label)
		fs:SetJustifyH("LEFT")

		local eb = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
		eb:SetSize(110, 22)
		eb:SetAutoFocus(false)
		eb:SetPoint("LEFT", row, "LEFT", INPUT_X, 0)

		-- allow decimals: do NOT SetNumeric(true) (it blocks '.' in many clients)
		if not allowDecimal and not allowNegative then
			eb:SetNumeric(true)
		end

		local function refresh()
			local v = get()
			eb:SetText(tostring(v))
		end

		local function apply()
			local v = tonumber(eb:GetText())
			if v == nil then
				refresh()
				return
			end
			set(v)
			refresh()
		end

		eb:SetScript("OnEnterPressed", function(self) self:ClearFocus(); apply() end)
		eb:SetScript("OnEditFocusLost", function() apply() end)
		eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); refresh() end)

		if tooltip then
			fs:SetScript("OnEnter", function()
				GameTooltip:SetOwner(fs, "ANCHOR_RIGHT")
				GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
				GameTooltip:Show()
			end)
			fs:SetScript("OnLeave", function() GameTooltip:Hide() end)
		end

		table.insert(inputs, refresh)
		return eb
	end

	local function AddTextRow(section, label, get, set, tooltip)
		local row = CreateRow(section, ROW_H)
		local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		fs:SetPoint("LEFT", row, "LEFT", LABEL_X, 0)
		fs:SetText(label)
		fs:SetJustifyH("LEFT")

		local eb = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
		eb:SetSize(180, 22)
		eb:SetAutoFocus(false)
		eb:SetPoint("LEFT", row, "LEFT", INPUT_X, 0)

		local function refresh()
			local v = get()
			if v == nil then v = "" end
			eb:SetText(tostring(v))
		end

		local function apply()
			local v = eb:GetText()
			set(v)
			refresh()
		end

		eb:SetScript("OnEnterPressed", function(self) self:ClearFocus(); apply() end)
		eb:SetScript("OnEditFocusLost", function() apply() end)
		eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); refresh() end)

		if tooltip then
			fs:SetScript("OnEnter", function()
				GameTooltip:SetOwner(fs, "ANCHOR_RIGHT")
				GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
				GameTooltip:Show()
			end)
			fs:SetScript("OnLeave", function() GameTooltip:Hide() end)
		end

		table.insert(inputs, refresh)
		return eb
	end

	local function AddCheckRow(section, label, get, set, tooltip)
		local row = CreateRow(section, ROW_H)
		local cb = CreateFrame("CheckButton", nil, row, "ChatConfigCheckButtonTemplate")
		cb:SetPoint("LEFT", row, "LEFT", LABEL_X, 0)
		if cb.Text then
			cb.Text:SetText(label)
		elseif cb.text then
			cb.text:SetText(label)
		else
			local t = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
			t:SetPoint("LEFT", cb, "RIGHT", 4, 0)
			t:SetText(label)
			cb._label = t
		end

		local function refresh()
			cb:SetChecked(get() and true or false)
		end

		cb:SetScript("OnClick", function(self)
			set(self:GetChecked() and true or false)
		end)

		if tooltip then
			cb:SetScript("OnEnter", function()
				GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
				GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
				GameTooltip:Show()
			end)
			cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
		end

		table.insert(inputs, refresh)
		return cb
	end

	local function AddDropdownRow(section, label, options, get, set, tooltip)
		local row = CreateRow(section, ROW_H)
		local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		fs:SetPoint("LEFT", row, "LEFT", LABEL_X, 0)
		fs:SetText(label)

		local dd = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
		dd:SetPoint("TOPLEFT", row, "TOPLEFT", INPUT_X - 16, -6)
		UIDropDownMenu_SetWidth(dd, 110)

		local function refresh()
			local val = get()
			local text = nil
			for _, opt in ipairs(options) do
				if opt.value == val then
					text = opt.label
					break
				end
			end
			UIDropDownMenu_SetSelectedValue(dd, val)
			UIDropDownMenu_SetText(dd, text or tostring(val or ""))
		end

		UIDropDownMenu_Initialize(dd, function(_, level)
			if level and level > 1 then return end
			for _, opt in ipairs(options) do
				local info = UIDropDownMenu_CreateInfo()
				info.text = opt.label
				info.arg1 = opt.value
				info.func = function(_, arg1)
					set(arg1)
					UIDropDownMenu_SetSelectedValue(dd, arg1)
					UIDropDownMenu_SetText(dd, opt.label)
				end
				info.checked = (get() == opt.value)
				UIDropDownMenu_AddButton(info)
			end
		end)

		if tooltip then
			fs:SetScript("OnEnter", function()
				GameTooltip:SetOwner(fs, "ANCHOR_RIGHT")
				GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
				GameTooltip:Show()
			end)
			fs:SetScript("OnLeave", function() GameTooltip:Hide() end)
		end

		table.insert(inputs, refresh)
		return dd
	end

	local function AddColorRow(section, label, get, set)
		local row = CreateRow(section, ROW_H)
		local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		fs:SetPoint("LEFT", row, "LEFT", LABEL_X, 0)
		fs:SetText(label)

		local swatch = CreateFrame("Button", nil, row, "BackdropTemplate")
		swatch:SetSize(22, 22)
		swatch:SetPoint("LEFT", row, "LEFT", INPUT_X, 0)
		swatch:SetBackdrop({
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 12,
			insets = { left = 2, right = 2, top = 2, bottom = 2 },
		})
		swatch:SetBackdropColor(0, 0, 0, 1)

		local tex = swatch:CreateTexture(nil, "ARTWORK")
		tex:SetPoint("TOPLEFT", 3, -3)
		tex:SetPoint("BOTTOMRIGHT", -3, 3)
		swatch.tex = tex

		local function refresh()
			local r, g, b, a = get()
			swatch.tex:SetColorTexture(r, g, b, a or 1)
		end

		swatch:SetScript("OnClick", function()
			local r, g, b, a = get()
			OpenColorPicker(r, g, b, a or 1, function(nr, ng, nb, na)
				set(nr, ng, nb, na)
				refresh()
			end)
		end)

		table.insert(inputs, refresh)
		return swatch
	end

	local function AddButton(section, label, onClick)
		local row = CreateRow(section, ROW_H)
		local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		btn:SetSize(160, 22)
		btn:SetPoint("LEFT", row, "LEFT", LABEL_X, 0)
		btn:SetText(label)
		btn:SetScript("OnClick", onClick)
		return btn
	end

	local function RefreshAll()
		if M and M.EnsureDefaults then
			M:EnsureDefaults()
		end
		for _, r in ipairs(inputs) do r() end
	end

	local displayTab = CreateTab(1, "Display")
	local dungeonTab = CreateTab(2, "Dungeon")
	local combatTab = CreateTab(3, "Combat Timer")
	local privateTab = CreateTab(4, "Private Auras")

	PanelTemplates_SetNumTabs(panel, #tabs)
	local bottomBar = CreateFrame("Frame", nil, panel)
	bottomBar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 8)
	bottomBar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 8)
	bottomBar:SetHeight(BOTTOM_BAR_HEIGHT)

	local startBtn = CreateFrame("Button", nil, bottomBar, "UIPanelButtonTemplate")
	startBtn:SetSize(120, 22)
	startBtn:SetPoint("CENTER", bottomBar, "CENTER", -70, 0)
	startBtn:SetText("Start Test")
	startBtn:SetScript("OnClick", function() M:StartTest() end)

	local stopBtn = CreateFrame("Button", nil, bottomBar, "UIPanelButtonTemplate")
	stopBtn:SetSize(120, 22)
	stopBtn:SetPoint("LEFT", startBtn, "RIGHT", 12, 0)
	stopBtn:SetText("Stop Test")
	stopBtn:SetScript("OnClick", function() M:StopTest() end)

	local dungeonSection = CreateSection(dungeonTab, "Mythic+")
	AddCheckRow(dungeonSection, "Auto Insert Keystone",
		function() return SimpleBossModsDB.cfg.general.autoInsertKeystone end,
		function(v) M:ApplyGeneralConfig(SimpleBossModsDB.cfg.general.gap or 6, v) end,
		"Automatically inserts your keystone when the Mythic+ socket opens."
	)

	local iconGrowDirections = {
		{ label = "Left down", value = "LEFT_DOWN" },
		{ label = "Left up", value = "LEFT_UP" },
		{ label = "Right down", value = "RIGHT_DOWN" },
		{ label = "Right up", value = "RIGHT_UP" },
	}

	local barGrowDirections = {
		{ label = "Up", value = "UP" },
		{ label = "Down", value = "DOWN" },
	}

	local barSortOptions = {
		{ label = "Ascending (lowest first)", value = "ASC" },
		{ label = "Descending (highest first)", value = "DESC" },
	}

	local barFillOptions = {
		{ label = "Left", value = "LEFT" },
		{ label = "Right", value = "RIGHT" },
	}

	local iconsSection = CreateSection(displayTab, "Icons")
	AddCheckRow(iconsSection, "Enable Large Icons",
		function() return SimpleBossModsDB.cfg.icons.enabled ~= false end,
		function(v) M:ApplyIconEnabled(v) end,
		"Disables the big icon row above/below the bars."
	)
	AddNumberRow(iconsSection, "Indicator Size",
		function() return SimpleBossModsDB.cfg.indicators.iconSize or 0 end,
		function(v) M:ApplyIndicatorConfig(v, SimpleBossModsDB.cfg.indicators.barSize or 0) end,
		"0 uses auto size."
	)
	AddNumberRow(iconsSection, "Gap",
		function() return SimpleBossModsDB.cfg.icons.gap end,
		function(v) M:ApplyIconLayoutConfig(v, SimpleBossModsDB.cfg.icons.perRow, SimpleBossModsDB.cfg.icons.limit) end,
		"Space between large icons. Supports negative values."
	)
	AddNumberRow(iconsSection, "Per Row",
		function() return SimpleBossModsDB.cfg.icons.perRow end,
		function(v) M:ApplyIconLayoutConfig(SimpleBossModsDB.cfg.icons.gap, v, SimpleBossModsDB.cfg.icons.limit) end
	)
	AddNumberRow(iconsSection, "Max",
		function() return SimpleBossModsDB.cfg.icons.limit end,
		function(v) M:ApplyIconLayoutConfig(SimpleBossModsDB.cfg.icons.gap, SimpleBossModsDB.cfg.icons.perRow, v) end,
		"0 means unlimited."
	)
	AddNumberRow(iconsSection, "Size",
		function() return SimpleBossModsDB.cfg.icons.size end,
		function(v) M:ApplyIconConfig(v, SimpleBossModsDB.cfg.icons.fontSize, SimpleBossModsDB.cfg.icons.borderThickness) end
	)
	AddNumberRow(iconsSection, "Font Size",
		function() return SimpleBossModsDB.cfg.icons.fontSize end,
		function(v) M:ApplyIconConfig(SimpleBossModsDB.cfg.icons.size, v, SimpleBossModsDB.cfg.icons.borderThickness) end
	)
	AddNumberRow(iconsSection, "Border Thickness",
		function() return SimpleBossModsDB.cfg.icons.borderThickness end,
		function(v) M:ApplyIconConfig(SimpleBossModsDB.cfg.icons.size, SimpleBossModsDB.cfg.icons.fontSize, v) end,
		"0 disables icon border."
	)
	AddDropdownRow(iconsSection, "Grow Direction",
		iconGrowDirections,
		function() return SimpleBossModsDB.cfg.icons.growDirection end,
		function(v) M:ApplyIconGrowDirection(v) end
	)

	local iconsAnchor = CreateSection(displayTab, "Large Icons Anchor")
	local iconsAnchorParentOptions = select(1, buildAnchorParentLists(SimpleBossModsDB.cfg.icons.anchorParent))
	AddDropdownRow(iconsAnchor, "Anchor From",
		ANCHOR_POINT_OPTIONS,
		function() return SimpleBossModsDB.cfg.icons.anchorFrom end,
		function(v) M:ApplyIconAnchorFrom(v) end
	)
	AddDropdownRow(iconsAnchor, "Anchor To Parent",
		iconsAnchorParentOptions,
		function() return SimpleBossModsDB.cfg.icons.anchorParent end,
		function(v)
			M:ApplyIconAnchorParent(v)
			RefreshAll()
		end
	)
	AddDropdownRow(iconsAnchor, "Anchor To",
		ANCHOR_POINT_OPTIONS,
		function() return SimpleBossModsDB.cfg.icons.anchorTo end,
		function(v) M:ApplyIconAnchorTo(v) end
	)
	AddTextRow(iconsAnchor, "Custom Parent (optional)",
		function() return SimpleBossModsDB.cfg.icons.customParent or "" end,
		function(v) M:ApplyIconCustomParent(v) end,
		"Overrides 'Anchor To Parent' when set. Use a global frame name, e.g. UIParent."
	)
	AddNumberRow(iconsAnchor, "X Offset",
		function() return SimpleBossModsDB.cfg.icons.x or 0 end,
		function(v) M:ApplyIconAnchorPosition(v, SimpleBossModsDB.cfg.icons.y or 0) end,
		nil, true
	)
	AddNumberRow(iconsAnchor, "Y Offset",
		function() return SimpleBossModsDB.cfg.icons.y or 0 end,
		function(v) M:ApplyIconAnchorPosition(SimpleBossModsDB.cfg.icons.x or 0, v) end,
		nil, true
	)

	local barsAnchor = CreateSection(displayTab, "Bars Anchor")
	local barsAnchorParentOptions = select(1, buildAnchorParentLists(SimpleBossModsDB.cfg.bars.anchorParent))
	AddDropdownRow(barsAnchor, "Anchor From",
		ANCHOR_POINT_OPTIONS,
		function() return SimpleBossModsDB.cfg.bars.anchorFrom end,
		function(v) M:ApplyBarAnchorFrom(v) end
	)
	AddDropdownRow(barsAnchor, "Anchor To Parent",
		barsAnchorParentOptions,
		function() return SimpleBossModsDB.cfg.bars.anchorParent end,
		function(v)
			M:ApplyBarAnchorParent(v)
			RefreshAll()
		end
	)
	AddDropdownRow(barsAnchor, "Anchor To",
		ANCHOR_POINT_OPTIONS,
		function() return SimpleBossModsDB.cfg.bars.anchorTo end,
		function(v) M:ApplyBarAnchorTo(v) end
	)
	AddTextRow(barsAnchor, "Custom Parent (optional)",
		function() return SimpleBossModsDB.cfg.bars.customParent or "" end,
		function(v) M:ApplyBarCustomParent(v) end,
		"Overrides 'Anchor To Parent' when set. Use a global frame name, e.g. UIParent."
	)
	AddNumberRow(barsAnchor, "X Offset",
		function() return SimpleBossModsDB.cfg.bars.x or 0 end,
		function(v) M:ApplyBarAnchorPosition(v, SimpleBossModsDB.cfg.bars.y or 0) end,
		nil, true
	)
	AddNumberRow(barsAnchor, "Y Offset",
		function() return SimpleBossModsDB.cfg.bars.y or 0 end,
		function(v) M:ApplyBarAnchorPosition(SimpleBossModsDB.cfg.bars.x or 0, v) end,
		nil, true
	)

	local barsSection = CreateSection(displayTab, "Bars")
	AddNumberRow(barsSection, "Width",
		function() return SimpleBossModsDB.cfg.bars.width end,
		function(v) M:ApplyBarConfig(v, SimpleBossModsDB.cfg.bars.height, SimpleBossModsDB.cfg.bars.fontSize, SimpleBossModsDB.cfg.bars.borderThickness) end
	)
	AddNumberRow(barsSection, "Height",
		function() return SimpleBossModsDB.cfg.bars.height end,
		function(v) M:ApplyBarConfig(SimpleBossModsDB.cfg.bars.width, v, SimpleBossModsDB.cfg.bars.fontSize, SimpleBossModsDB.cfg.bars.borderThickness) end
	)
	AddNumberRow(barsSection, "Font Size",
		function() return SimpleBossModsDB.cfg.bars.fontSize end,
		function(v) M:ApplyBarConfig(SimpleBossModsDB.cfg.bars.width, SimpleBossModsDB.cfg.bars.height, v, SimpleBossModsDB.cfg.bars.borderThickness) end
	)
	AddNumberRow(barsSection, "Border Thickness",
		function() return SimpleBossModsDB.cfg.bars.borderThickness end,
		function(v) M:ApplyBarConfig(SimpleBossModsDB.cfg.bars.width, SimpleBossModsDB.cfg.bars.height, SimpleBossModsDB.cfg.bars.fontSize, v) end
	)
	AddNumberRow(barsSection, "Indicator Size",
		function() return SimpleBossModsDB.cfg.indicators.barSize or 0 end,
		function(v) M:ApplyIndicatorConfig(SimpleBossModsDB.cfg.indicators.iconSize or 0, v) end,
		"0 uses auto size."
	)
	AddNumberRow(barsSection, "Bar Gap",
		function() return SimpleBossModsDB.cfg.general.gap or 6 end,
		function(v) M:ApplyGeneralConfig(U.clamp(U.round(v), -30, 30), SimpleBossModsDB.cfg.general.autoInsertKeystone) end,
		"Space between bars.", false, true
	)
	AddDropdownRow(barsSection, "Grow Direction",
		barGrowDirections,
		function() return SimpleBossModsDB.cfg.bars.growDirection end,
		function(v) M:ApplyBarGrowDirection(v) end
	)
	AddDropdownRow(barsSection, "Sort Order",
		barSortOptions,
		function() return (SimpleBossModsDB.cfg.bars.sortAscending ~= false) and "ASC" or "DESC" end,
		function(v) M:ApplyBarSortOrder(v) end
	)
	AddDropdownRow(barsSection, "Fill Direction",
		barFillOptions,
		function() return SimpleBossModsDB.cfg.bars.fillDirection end,
		function(v) M:ApplyBarFillDirection(v) end
	)
	AddNumberRow(barsSection, "Display bars when seconds remaining",
		function() return SimpleBossModsDB.cfg.general.thresholdToBar end,
		function(v) M:ApplyBarThresholdConfig(v) end,
		"Bars show at or below this time. Icons use this threshold when enabled.", true
	)
	AddCheckRow(barsSection, "Swap Icon Side",
		function() return SimpleBossModsDB.cfg.bars.swapIconSide end,
		function(v) M:ApplyBarIconSideConfig(v) end,
		"Move the icon to the opposite side."
	)
	AddCheckRow(barsSection, "Swap Indicator Side",
		function() return SimpleBossModsDB.cfg.bars.swapIndicatorSide end,
		function(v) M:ApplyBarIndicatorSideConfig(v) end,
		"Move the end indicators to the opposite side."
	)
	AddCheckRow(barsSection, "Hide Icon",
		function() return SimpleBossModsDB.cfg.bars.hideIcon end,
		function(v) M:ApplyBarIconVisibilityConfig(v) end,
		"Hide the icon without changing text alignment or fill direction."
	)
	AddColorRow(barsSection, "Default Bar Color (Timeline)",
		function() return L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A end,
		function(r, g, b, a) M:ApplyBarColor(r, g, b, a) end
	)
	AddColorRow(barsSection, "Default Background Color",
		function() return L.BAR_BG_R, L.BAR_BG_G, L.BAR_BG_B, L.BAR_BG_A end,
		function(r, g, b, a) M:ApplyBarBgColor(r, g, b, a) end
	)

	local combatEnable = CreateSection(combatTab, "Combat Timer")
	AddCheckRow(combatEnable, "Enable Combat Timer",
		function() return SimpleBossModsDB.cfg.combatTimer.enabled end,
		function(v) M:ApplyCombatTimerEnabled(v) end,
		"Shows a timer while you are in combat."
	)

	local combatAnchor = CreateSection(combatTab, "Anchor")
	local combatAnchorParentOptions = select(1, buildAnchorParentLists(SimpleBossModsDB.cfg.combatTimer.anchorParent))
	AddDropdownRow(combatAnchor, "Anchor From",
		ANCHOR_POINT_OPTIONS,
		function() return SimpleBossModsDB.cfg.combatTimer.anchorFrom end,
		function(v) M:ApplyCombatTimerAnchorFrom(v) end
	)
	AddDropdownRow(combatAnchor, "Anchor To Parent",
		combatAnchorParentOptions,
		function() return SimpleBossModsDB.cfg.combatTimer.anchorParent end,
		function(v)
			M:ApplyCombatTimerAnchorParent(v)
			RefreshAll()
		end
	)
	AddDropdownRow(combatAnchor, "Anchor To",
		ANCHOR_POINT_OPTIONS,
		function() return SimpleBossModsDB.cfg.combatTimer.anchorTo end,
		function(v) M:ApplyCombatTimerAnchorTo(v) end
	)
	AddTextRow(combatAnchor, "Custom Parent (optional)",
		function() return SimpleBossModsDB.cfg.combatTimer.customParent or "" end,
		function(v) M:ApplyCombatTimerCustomParent(v) end,
		"Overrides 'Anchor To Parent' when set. Use a global frame name, e.g. PlayerFrame."
	)
	AddNumberRow(combatAnchor, "X Offset",
		function() return SimpleBossModsDB.cfg.combatTimer.x or 0 end,
		function(v) M:ApplyCombatTimerPosition(v, SimpleBossModsDB.cfg.combatTimer.y or 0) end,
		nil, true
	)
	AddNumberRow(combatAnchor, "Y Offset",
		function() return SimpleBossModsDB.cfg.combatTimer.y or 0 end,
		function(v) M:ApplyCombatTimerPosition(SimpleBossModsDB.cfg.combatTimer.x or 0, v) end,
		nil, true
	)

	local combatText = CreateSection(combatTab, "Text")
	AddNumberRow(combatText, "Font Size",
		function() return SimpleBossModsDB.cfg.combatTimer.fontSize end,
		function(v) M:ApplyCombatTimerFontSize(v) end
	)

	local fontOptions = buildFontOptions()
	if fontOptions then
		AddDropdownRow(combatText, "Font",
			fontOptions,
			function() return SimpleBossModsDB.cfg.combatTimer.font end,
			function(v) M:ApplyCombatTimerFont(v) end
		)
	else
		local row = CreateRow(combatText, ROW_H)
		local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		fs:SetPoint("LEFT", row, "LEFT", LABEL_X, 0)
		fs:SetText("LibSharedMedia is not available.")
	end

	local combatColors = CreateSection(combatTab, "Colors")
	AddColorRow(combatColors, "Text Color",
		function()
			local c = SimpleBossModsDB.cfg.combatTimer.color
			return c.r, c.g, c.b, c.a
		end,
		function(r, g, b, a) M:ApplyCombatTimerColor(r, g, b, a) end
	)
	AddColorRow(combatColors, "Border Color",
		function()
			local c = SimpleBossModsDB.cfg.combatTimer.borderColor
			return c.r, c.g, c.b, c.a
		end,
		function(r, g, b, a) M:ApplyCombatTimerBorderColor(r, g, b, a) end
	)
	AddColorRow(combatColors, "Background Color",
		function()
			local c = SimpleBossModsDB.cfg.combatTimer.bgColor
			return c.r, c.g, c.b, c.a
		end,
		function(r, g, b, a) M:ApplyCombatTimerBgColor(r, g, b, a) end
	)

	local privateAuraDirections = {
		{ label = "Right", value = "RIGHT" },
		{ label = "Left", value = "LEFT" },
		{ label = "Up", value = "UP" },
		{ label = "Down", value = "DOWN" },
	}

	local privateEnable = CreateSection(privateTab, "Private Auras")
	AddCheckRow(privateEnable, "Enable Tracking",
		function() return SimpleBossModsDB.cfg.privateAuras.enabled ~= false end,
		function(v) M:ApplyPrivateAuraEnabled(v) end,
		"Toggle private aura icon tracking."
	)

	local privateAnchor = CreateSection(privateTab, "Anchor")
	local privateAnchorParentOptions = select(1, buildAnchorParentLists(SimpleBossModsDB.cfg.privateAuras.anchorParent))
	AddDropdownRow(privateAnchor, "Anchor From",
		ANCHOR_POINT_OPTIONS,
		function() return SimpleBossModsDB.cfg.privateAuras.anchorFrom end,
		function(v) M:ApplyPrivateAuraAnchorFrom(v) end
	)
	AddDropdownRow(privateAnchor, "Anchor To Parent",
		privateAnchorParentOptions,
		function() return SimpleBossModsDB.cfg.privateAuras.anchorParent end,
		function(v)
			M:ApplyPrivateAuraAnchorParent(v)
			RefreshAll()
		end
	)
	AddDropdownRow(privateAnchor, "Anchor To",
		ANCHOR_POINT_OPTIONS,
		function() return SimpleBossModsDB.cfg.privateAuras.anchorTo end,
		function(v) M:ApplyPrivateAuraAnchorTo(v) end
	)
	AddTextRow(privateAnchor, "Custom Parent (optional)",
		function() return SimpleBossModsDB.cfg.privateAuras.customParent or "" end,
		function(v) M:ApplyPrivateAuraCustomParent(v) end,
		"Overrides 'Anchor To Parent' when set. Use a global frame name, e.g. PlayerFrame."
	)
	AddNumberRow(privateAnchor, "X Offset",
		function() return SimpleBossModsDB.cfg.privateAuras.x or 0 end,
		function(v) M:ApplyPrivateAuraPosition(v, SimpleBossModsDB.cfg.privateAuras.y or 0) end,
		nil, true
	)
	AddNumberRow(privateAnchor, "Y Offset",
		function() return SimpleBossModsDB.cfg.privateAuras.y or 0 end,
		function(v) M:ApplyPrivateAuraPosition(SimpleBossModsDB.cfg.privateAuras.x or 0, v) end,
		nil, true
	)

	local privateLayout = CreateSection(privateTab, "Layout")
	AddNumberRow(privateLayout, "Icon Size",
		function() return SimpleBossModsDB.cfg.privateAuras.size end,
		function(v)
			M:ApplyPrivateAuraConfig(
				v,
				SimpleBossModsDB.cfg.privateAuras.gap,
				SimpleBossModsDB.cfg.privateAuras.growDirection,
				SimpleBossModsDB.cfg.privateAuras.x,
				SimpleBossModsDB.cfg.privateAuras.y
			)
		end
	)

	AddNumberRow(privateLayout, "Icon Gap",
		function() return SimpleBossModsDB.cfg.privateAuras.gap end,
		function(v)
			M:ApplyPrivateAuraConfig(
				SimpleBossModsDB.cfg.privateAuras.size,
				v,
				SimpleBossModsDB.cfg.privateAuras.growDirection,
				SimpleBossModsDB.cfg.privateAuras.x,
				SimpleBossModsDB.cfg.privateAuras.y
			)
		end
	)

	AddDropdownRow(privateLayout, "Grow Direction",
		privateAuraDirections,
		function() return SimpleBossModsDB.cfg.privateAuras.growDirection end,
		function(v)
			M:ApplyPrivateAuraConfig(
				SimpleBossModsDB.cfg.privateAuras.size,
				SimpleBossModsDB.cfg.privateAuras.gap,
				v,
				SimpleBossModsDB.cfg.privateAuras.x,
				SimpleBossModsDB.cfg.privateAuras.y
			)
		end,
		"Icon growth direction from the private aura anchor."
	)

	for _, tab in ipairs(tabs) do
		LayoutTab(tab)
	end
	SelectTab(1)

	panel._refreshAll = RefreshAll
	panel:SetScript("OnShow", function()
		if M and M.EnsureDefaults then
			M:EnsureDefaults()
		end
		RefreshAll()
		M:LayoutAll()
	end)

	panel:SetScript("OnHide", function()
		M:StopTest()
		M:LayoutAll()
	end)

	self._settingsWindow = panel
	return panel
end

-- =========================
-- Settings Window (AceGUI)
-- =========================
function M:CreateSettingsWindow()
	if not AG then
		return self:CreateLegacySettingsWindow()
	end
	if isGUIOpen then return self._settingsWindow end
	if InCombatLockdown() then return end
	if self.EnsureDefaults then
		self:EnsureDefaults()
	end
	M.SyncLiveConfig()

	isGUIOpen = true
	local addon = self

	local frame = AG:Create("Frame")
	frame:SetTitle("Simple Boss Mods")
	frame:SetLayout("Fill")
	frame:SetWidth(900)
	frame:SetHeight(600)
	frame:EnableResize(false)
	frame:SetCallback("OnClose", function(widget)
		addon:StopTest()
		if addon._settingsTestBar then
			addon._settingsTestBar:Hide()
			addon._settingsTestBar:SetParent(nil)
			addon._settingsTestBar = nil
		end
		AG:Release(widget)
		isGUIOpen = false
		addon._settingsWindow = nil
		addon._settingsTabGroup = nil
		addon._settingsTabStatus = nil
	end)
	frame.frame:SetClampedToScreen(true)
	frame.frame:SetFrameStrata("DIALOG")

	addon._settingsWindow = frame
	local baseFrame = frame.frame
	local statusbg = frame.statustext and frame.statustext:GetParent() or nil

	local testBar = CreateFrame("Frame", nil, baseFrame)
	testBar:SetPoint("BOTTOMLEFT", 15, 15)
	testBar:SetHeight(24)
	testBar:SetFrameLevel(baseFrame:GetFrameLevel() + 5)

	local startTestBtn = CreateFrame("Button", nil, testBar, "UIPanelButtonTemplate")
	startTestBtn:SetSize(90, 20)
	startTestBtn:SetPoint("LEFT", testBar, "LEFT", 0, 0)
	startTestBtn:SetText("Start Test")
	startTestBtn:SetScript("OnClick", function() addon:StartTest() end)

	local stopTestBtn = CreateFrame("Button", nil, testBar, "UIPanelButtonTemplate")
	stopTestBtn:SetSize(90, 20)
	stopTestBtn:SetPoint("LEFT", startTestBtn, "RIGHT", 6, 0)
	stopTestBtn:SetText("Stop Test")
	stopTestBtn:SetScript("OnClick", function() addon:StopTest() end)

	testBar:SetWidth(startTestBtn:GetWidth() + stopTestBtn:GetWidth() + 6)
	addon._settingsTestBar = testBar

	if statusbg then
		statusbg:ClearAllPoints()
		statusbg:SetPoint("BOTTOMLEFT", testBar, "BOTTOMRIGHT", 8, 0)
		statusbg:SetPoint("BOTTOMRIGHT", -132, 15)
	end

	local function addNumberInput(container, label, getValue, setValue, width)
		local input = AG:Create("EditBox")
		input:SetLabel(label)
		input:SetText(tostring(getValue()))
		if width then
			input:SetRelativeWidth(width)
		else
			input:SetFullWidth(true)
		end
		input:SetCallback("OnEnterPressed", function(widget, _, text)
			local value = tonumber(text)
			if value == nil then
				widget:SetText(tostring(getValue()))
				return
			end
			setValue(value)
			widget:SetText(tostring(getValue()))
		end)
		container:AddChild(input)
		return input
	end

	local function addCheckBox(container, label, getValue, setValue, width)
		local cb = AG:Create("CheckBox")
		cb:SetLabel(label)
		cb:SetValue(getValue() and true or false)
		if width then
			cb:SetRelativeWidth(width)
		else
			cb:SetFullWidth(true)
		end
		cb:SetCallback("OnValueChanged", function(_, _, value)
			setValue(value)
		end)
		container:AddChild(cb)
		return cb
	end

	local function addDropdown(container, label, list, getValue, setValue, width, order)
		local dd = AG:Create("Dropdown")
		dd:SetLabel(label)
		if type(order) == "table" and #order > 0 then
			dd:SetList(list, order)
		else
			dd:SetList(list)
		end
		dd:SetValue(getValue())
		if width then
			dd:SetRelativeWidth(width)
		else
			dd:SetFullWidth(true)
		end
		dd:SetCallback("OnValueChanged", function(widget, _, value)
			setValue(value)
			widget:SetValue(getValue())
		end)
		container:AddChild(dd)
		return dd
	end

	local function addColorPicker(container, label, getValue, setValue, width)
		local cp = AG:Create("ColorPicker")
		cp:SetLabel(label)
		cp:SetHasAlpha(true)
		local r, g, b, a = getValue()
		cp:SetColor(r, g, b, a)
		if width then
			cp:SetRelativeWidth(width)
		else
			cp:SetFullWidth(true)
		end
		cp:SetCallback("OnValueChanged", function(_, _, nr, ng, nb, na)
			setValue(nr, ng, nb, na)
		end)
		container:AddChild(cp)
		return cp
	end

	local function buildConnectorsTab(container)
		if addon.RefreshConnectorState then
			addon:RefreshConnectorState()
		end

		local controls = AG:Create("InlineGroup")
		controls:SetTitle("Connector Source")
		controls:SetLayout("Flow")
		controls:SetFullWidth(true)
		container:AddChild(controls)

		local statuses = addon.GetConnectorStatuses and addon:GetConnectorStatuses() or {}
		local list = {}
		local byID = {}
		local order = {}
		local seen = {}
		local preferredOrder = { "timeline", "bigwigs", "dbm" }
		for _, info in ipairs(statuses) do
			byID[info.id] = info
		end
		for _, id in ipairs(preferredOrder) do
			local info = byID[id]
			if info then
				list[id] = info.label
				order[#order + 1] = id
				seen[id] = true
			end
		end
		for _, info in ipairs(statuses) do
			if not seen[info.id] then
				list[info.id] = info.label
				order[#order + 1] = info.id
				seen[info.id] = true
			end
		end

		local optionsGroup = AG:Create("InlineGroup")
		optionsGroup:SetTitle("Connector Options")
		optionsGroup:SetLayout("Flow")
		optionsGroup:SetFullWidth(true)
		container:AddChild(optionsGroup)

		local infoGroup = AG:Create("InlineGroup")
		infoGroup:SetTitle("Credits")
		infoGroup:SetLayout("Flow")
		infoGroup:SetFullWidth(true)
		container:AddChild(infoGroup)

		local function addInfoLine(text)
			local line = AG:Create("Label")
			line:SetText(text)
			line:SetFullWidth(true)
			infoGroup:AddChild(line)
		end

		local function setCreditsVisible(visible)
			if infoGroup and infoGroup.frame then
				infoGroup.frame:SetShown(visible and true or false)
				if container and container.DoLayout then
					container:DoLayout()
				end
			end
		end

		local function getSelectedConnectorID()
			if addon.GetRequestedConnectorID then
				return addon:GetRequestedConnectorID()
			end
			return (SimpleBossModsDB.cfg.connectors and SimpleBossModsDB.cfg.connectors.provider) or "timeline"
		end

		local function refreshCredits(selectedID)
			infoGroup:ReleaseChildren()
			selectedID = tostring(selectedID or "timeline"):lower()

			if selectedID == "timeline" then
				setCreditsVisible(false)
				return
			end

			setCreditsVisible(true)
			if selectedID == "bigwigs" then
				addInfoLine("|cffffd200BigWigs Credits|r")
				addInfoLine("Authors: The BigWigs Team and contributors.")
				addInfoLine("GitHub: https://github.com/BigWigsMods/BigWigs")
				addInfoLine("Requires BigWigs to be installed and loaded (and LittleWigs for dungeon coverage).")
				addInfoLine("This connector depends on BigWigs data and would not work without their development work.")
				addInfoLine("All rights belong to the BigWigs authors. Please support the official project.")
			else
				addInfoLine("|cffffd200DBM Credits|r")
				addInfoLine("Authors: Deadly Boss Mods team, led by MysticalOS, and contributors.")
				addInfoLine("GitHub: https://github.com/DeadlyBossMods/DeadlyBossMods")
				addInfoLine("Requires Deadly Boss Mods (DBM) to be installed and loaded.")
				addInfoLine("This connector depends on DBM data and would not work without their development work.")
				addInfoLine("All rights belong to the DBM authors. Please support the official project.")
			end
		end

		local function refreshConnectorOptions(selectedID)
			optionsGroup:ReleaseChildren()
			selectedID = tostring(selectedID or "timeline"):lower()

			if selectedID == "timeline" then
				addCheckBox(optionsGroup, "Use recommended settings",
					function()
						local connectors = SimpleBossModsDB.cfg.connectors
						return not connectors or connectors.useRecommendedSettings ~= false
					end,
					function(value)
						if addon.ApplyConnectorUseRecommendedSettings then
							addon:ApplyConnectorUseRecommendedSettings(value)
						end
					end,
					1
				)

				local note = AG:Create("Label")
				note:SetText("Recommended: keeps the Blizzard timeline active, sets it to Bars, and hides the Blizzard frame so SBM gets better event data.")
				note:SetFullWidth(true)
				optionsGroup:AddChild(note)

				local note2 = AG:Create("Label")
				note2:SetText("Disable this if you prefer using your own timeline settings.")
				note2:SetFullWidth(true)
				optionsGroup:AddChild(note2)
			elseif selectedID == "bigwigs" then
				addCheckBox(optionsGroup, "Disable Blizzard timeline",
					function()
						local connectors = SimpleBossModsDB.cfg.connectors
						return connectors and connectors.disableBlizzardTimeline == true
					end,
					function(value)
						if addon.ApplyConnectorDisableBlizzardTimeline then
							addon:ApplyConnectorDisableBlizzardTimeline(value)
						end
					end,
					1
				)

				local timelineNote = AG:Create("Label")
				timelineNote:SetText("Optional. Disables the Blizzard encounter timeline while using external connectors.")
				timelineNote:SetFullWidth(true)
				optionsGroup:AddChild(timelineNote)

				addDropdown(optionsGroup, "BigWigs bar colors",
					{
						normal = "Normal",
						emphasized = "Emphasized",
					},
					function()
						local connectors = SimpleBossModsDB.cfg.connectors
						local mode = connectors and connectors.bigWigsColorMode or "normal"
						mode = (type(mode) == "string") and mode:lower() or "normal"
						if mode ~= "emphasized" then
							mode = "normal"
						end
						return mode
					end,
					function(value)
						if addon.ApplyConnectorBigWigsColorMode then
							addon:ApplyConnectorBigWigsColorMode(value)
						end
					end,
					1
				)

				local colorsModeNote = AG:Create("Label")
				colorsModeNote:SetText("Choose whether SBM uses BigWigs normal or emphasized bar colors (including per-ability overrides).")
				colorsModeNote:SetFullWidth(true)
				optionsGroup:AddChild(colorsModeNote)

				addCheckBox(optionsGroup, "Hide BigWigs bars",
					function()
						local connectors = SimpleBossModsDB.cfg.connectors
						return not connectors or connectors.hideBigWigsBars ~= false
					end,
					function(value)
						if addon.ApplyConnectorHideBigWigsBars then
							addon:ApplyConnectorHideBigWigsBars(value)
						end
					end,
					1
				)

				local note = AG:Create("Label")
				note:SetText("Enabled by default. Hides native BigWigs bars while SBM uses BigWigs as connector.")
				note:SetFullWidth(true)
				optionsGroup:AddChild(note)
			elseif selectedID == "dbm" then
				addCheckBox(optionsGroup, "Disable Blizzard timeline",
					function()
						local connectors = SimpleBossModsDB.cfg.connectors
						return connectors and connectors.disableBlizzardTimeline == true
					end,
					function(value)
						if addon.ApplyConnectorDisableBlizzardTimeline then
							addon:ApplyConnectorDisableBlizzardTimeline(value)
						end
					end,
					1
				)

				local timelineNote = AG:Create("Label")
				timelineNote:SetText("Optional. Disables the Blizzard encounter timeline while using external connectors.")
				timelineNote:SetFullWidth(true)
				optionsGroup:AddChild(timelineNote)

				addCheckBox(optionsGroup, "Use DBM colors",
					function()
						local connectors = SimpleBossModsDB.cfg.connectors
						return not connectors or connectors.useDBMColors ~= false
					end,
					function(value)
						if addon.ApplyConnectorUseDBMColors then
							addon:ApplyConnectorUseDBMColors(value)
						end
					end,
					1
				)

				local colorsNote = AG:Create("Label")
				colorsNote:SetText("Enabled by default. Uses DBM default/type bar colors for all DBM abilities.")
				colorsNote:SetFullWidth(true)
				optionsGroup:AddChild(colorsNote)

				addCheckBox(optionsGroup, "Hide DBM bars",
					function()
						local connectors = SimpleBossModsDB.cfg.connectors
						return not connectors or connectors.hideDBMBars ~= false
					end,
					function(value)
						if addon.ApplyConnectorHideDBMBars then
							addon:ApplyConnectorHideDBMBars(value)
						end
					end,
					1
				)

				local note = AG:Create("Label")
				note:SetText("Enabled by default. Hides native DBM bars while SBM uses DBM as connector.")
				note:SetFullWidth(true)
				optionsGroup:AddChild(note)
			end
		end

		local connectorDropdown = addDropdown(controls, "Active Connector",
			list,
			function()
				return getSelectedConnectorID()
			end,
			function(value)
				if addon.SetConnector then
					local ok, reason = addon:SetConnector(value)
					if not ok and type(reason) == "string" and reason ~= "" then
						print("SimpleBossMods:", reason)
					end
				end
				local selectedID = getSelectedConnectorID()
				refreshCredits(selectedID)
				refreshConnectorOptions(selectedID)
			end,
			1,
			order
		)
		if connectorDropdown and connectorDropdown.SetItemDisabled then
			for id, info in pairs(byID) do
				connectorDropdown:SetItemDisabled(id, not info.available)
			end
		end

		local selectedID = getSelectedConnectorID()
		refreshCredits(selectedID)
		refreshConnectorOptions(selectedID)
	end

	local function buildDungeonTab(container)
		local mythic = AG:Create("InlineGroup")
		mythic:SetTitle("Mythic+")
		mythic:SetLayout("Flow")
		mythic:SetFullWidth(true)
		container:AddChild(mythic)

		addCheckBox(mythic, "Auto Insert Keystone",
			function() return SimpleBossModsDB.cfg.general.autoInsertKeystone end,
			function(v)
				addon:ApplyGeneralConfig(
					SimpleBossModsDB.cfg.general.gap or 6,
					v
				)
			end,
			1
		)
	end

	local function buildIconsTab(container)
		local enabled = SimpleBossModsDB.cfg.icons.enabled ~= false
		local enable = AG:Create("InlineGroup")
		enable:SetTitle("Large Icons")
		enable:SetLayout("Flow")
		enable:SetFullWidth(true)
		container:AddChild(enable)

		local toggle = AG:Create("CheckBox")
		toggle:SetLabel("Enable Large Icons")
		toggle:SetValue(enabled)
		toggle:SetFullWidth(true)
		toggle:SetCallback("OnValueChanged", function(_, _, value)
			addon:ApplyIconEnabled(value)
			container:ReleaseChildren()
			buildIconsTab(container)
		end)
		enable:AddChild(toggle)

		if not enabled then
			local note = AG:Create("Label")
			note:SetText("Large icons are currently disabled.")
			note:SetFullWidth(true)
			container:AddChild(note)
			return
		end

		local _, iconAnchorParentMap = buildAnchorParentLists(SimpleBossModsDB.cfg.icons.anchorParent)

		local anchor = AG:Create("InlineGroup")
		anchor:SetTitle("Anchor")
		anchor:SetLayout("Flow")
		anchor:SetFullWidth(true)
		container:AddChild(anchor)

		local customParent

		addDropdown(anchor, "Anchor From",
			ANCHOR_POINT_MAP,
			function() return SimpleBossModsDB.cfg.icons.anchorFrom end,
			function(v) addon:ApplyIconAnchorFrom(v) end,
			0.33
		)

		addDropdown(anchor, "Anchor To Parent",
			iconAnchorParentMap,
			function() return SimpleBossModsDB.cfg.icons.anchorParent end,
			function(v)
				addon:ApplyIconAnchorParent(v)
				if customParent then
					customParent:SetText(SimpleBossModsDB.cfg.icons.customParent or "")
				end
			end,
			0.33
		)

		addDropdown(anchor, "Anchor To",
			ANCHOR_POINT_MAP,
			function() return SimpleBossModsDB.cfg.icons.anchorTo end,
			function(v) addon:ApplyIconAnchorTo(v) end,
			0.33
		)

		customParent = AG:Create("EditBox")
		customParent:SetLabel("Custom Parent (optional)")
		customParent:SetText(SimpleBossModsDB.cfg.icons.customParent or "")
		customParent:SetFullWidth(true)
		customParent:SetCallback("OnEnterPressed", function(widget, _, text)
			addon:ApplyIconCustomParent(text)
			widget:SetText(SimpleBossModsDB.cfg.icons.customParent or "")
		end)
		anchor:AddChild(customParent)

		addNumberInput(anchor, "X Offset",
			function() return SimpleBossModsDB.cfg.icons.x or 0 end,
			function(v) addon:ApplyIconAnchorPosition(v, SimpleBossModsDB.cfg.icons.y or 0) end,
			0.5
		)

		addNumberInput(anchor, "Y Offset",
			function() return SimpleBossModsDB.cfg.icons.y or 0 end,
			function(v) addon:ApplyIconAnchorPosition(SimpleBossModsDB.cfg.icons.x or 0, v) end,
			0.5
		)

		local icons = AG:Create("InlineGroup")
		icons:SetTitle("Layout")
		icons:SetLayout("Flow")
		icons:SetFullWidth(true)
		container:AddChild(icons)

		addNumberInput(icons, "Size",
			function() return SimpleBossModsDB.cfg.icons.size end,
			function(v) addon:ApplyIconConfig(v, SimpleBossModsDB.cfg.icons.fontSize, SimpleBossModsDB.cfg.icons.borderThickness) end,
			0.25
		)

		addNumberInput(icons, "Font Size",
			function() return SimpleBossModsDB.cfg.icons.fontSize end,
			function(v) addon:ApplyIconConfig(SimpleBossModsDB.cfg.icons.size, v, SimpleBossModsDB.cfg.icons.borderThickness) end,
			0.25
		)

		addNumberInput(icons, "Border Thickness",
			function() return SimpleBossModsDB.cfg.icons.borderThickness end,
			function(v) addon:ApplyIconConfig(SimpleBossModsDB.cfg.icons.size, SimpleBossModsDB.cfg.icons.fontSize, v) end,
			0.25
		)

		addNumberInput(icons, "Indicator Size",
			function() return SimpleBossModsDB.cfg.indicators.iconSize or 0 end,
			function(v) addon:ApplyIndicatorConfig(v, SimpleBossModsDB.cfg.indicators.barSize or 0) end,
			0.25
		)

		addNumberInput(icons, "Gap",
			function() return SimpleBossModsDB.cfg.icons.gap end,
			function(v) addon:ApplyIconLayoutConfig(v, SimpleBossModsDB.cfg.icons.perRow, SimpleBossModsDB.cfg.icons.limit) end,
			0.33
		)

		addNumberInput(icons, "Per Row",
			function() return SimpleBossModsDB.cfg.icons.perRow end,
			function(v) addon:ApplyIconLayoutConfig(SimpleBossModsDB.cfg.icons.gap, v, SimpleBossModsDB.cfg.icons.limit) end,
			0.33
		)

		addNumberInput(icons, "Max (0 = unlimited)",
			function() return SimpleBossModsDB.cfg.icons.limit end,
			function(v) addon:ApplyIconLayoutConfig(SimpleBossModsDB.cfg.icons.gap, SimpleBossModsDB.cfg.icons.perRow, v) end,
			0.33
		)

		addDropdown(icons, "Grow Direction",
			{
				LEFT_DOWN = "Left down",
				LEFT_UP = "Left up",
				RIGHT_DOWN = "Right down",
				RIGHT_UP = "Right up",
			},
			function() return SimpleBossModsDB.cfg.icons.growDirection end,
			function(v) addon:ApplyIconGrowDirection(v) end,
			0.5
		)

		if LSM then
			local iconFontDropdown = AG:Create("LSM30_Font")
			iconFontDropdown:SetLabel("Font")
			iconFontDropdown:SetList(LSM:HashTable("font"))
			iconFontDropdown:SetValue(SimpleBossModsDB.cfg.icons.font)
			iconFontDropdown:SetRelativeWidth(0.5)
			iconFontDropdown:SetCallback("OnValueChanged", function(widget, _, value)
				addon:ApplyIconFontConfig(value)
				widget:SetValue(SimpleBossModsDB.cfg.icons.font)
			end)
			icons:AddChild(iconFontDropdown)
		else
			local label = AG:Create("Label")
			label:SetText("LibSharedMedia is not available.")
			label:SetFullWidth(true)
			icons:AddChild(label)
		end
	end

	local function buildBarsTab(container)
		local _, barsAnchorParentMap = buildAnchorParentLists(SimpleBossModsDB.cfg.bars.anchorParent)

		local anchor = AG:Create("InlineGroup")
		anchor:SetTitle("Anchor")
		anchor:SetLayout("Flow")
		anchor:SetFullWidth(true)
		container:AddChild(anchor)

		local customParent

		addDropdown(anchor, "Anchor From",
			ANCHOR_POINT_MAP,
			function() return SimpleBossModsDB.cfg.bars.anchorFrom end,
			function(v) addon:ApplyBarAnchorFrom(v) end,
			0.33
		)

		addDropdown(anchor, "Anchor To Parent",
			barsAnchorParentMap,
			function() return SimpleBossModsDB.cfg.bars.anchorParent end,
			function(v)
				addon:ApplyBarAnchorParent(v)
				if customParent then
					customParent:SetText(SimpleBossModsDB.cfg.bars.customParent or "")
				end
			end,
			0.33
		)

		addDropdown(anchor, "Anchor To",
			ANCHOR_POINT_MAP,
			function() return SimpleBossModsDB.cfg.bars.anchorTo end,
			function(v) addon:ApplyBarAnchorTo(v) end,
			0.33
		)

		customParent = AG:Create("EditBox")
		customParent:SetLabel("Custom Parent (optional)")
		customParent:SetText(SimpleBossModsDB.cfg.bars.customParent or "")
		customParent:SetFullWidth(true)
		customParent:SetCallback("OnEnterPressed", function(widget, _, text)
			addon:ApplyBarCustomParent(text)
			widget:SetText(SimpleBossModsDB.cfg.bars.customParent or "")
		end)
		anchor:AddChild(customParent)

		addNumberInput(anchor, "X Offset",
			function() return SimpleBossModsDB.cfg.bars.x or 0 end,
			function(v) addon:ApplyBarAnchorPosition(v, SimpleBossModsDB.cfg.bars.y or 0) end,
			0.5
		)

		addNumberInput(anchor, "Y Offset",
			function() return SimpleBossModsDB.cfg.bars.y or 0 end,
			function(v) addon:ApplyBarAnchorPosition(SimpleBossModsDB.cfg.bars.x or 0, v) end,
			0.5
		)

		local bars = AG:Create("InlineGroup")
		bars:SetTitle("Bars")
		bars:SetLayout("Flow")
		bars:SetFullWidth(true)
		container:AddChild(bars)

		addNumberInput(bars, "Width",
			function() return SimpleBossModsDB.cfg.bars.width end,
			function(v) addon:ApplyBarConfig(v, SimpleBossModsDB.cfg.bars.height, SimpleBossModsDB.cfg.bars.fontSize, SimpleBossModsDB.cfg.bars.borderThickness) end,
			0.25
		)

		addNumberInput(bars, "Height",
			function() return SimpleBossModsDB.cfg.bars.height end,
			function(v) addon:ApplyBarConfig(SimpleBossModsDB.cfg.bars.width, v, SimpleBossModsDB.cfg.bars.fontSize, SimpleBossModsDB.cfg.bars.borderThickness) end,
			0.25
		)

		addNumberInput(bars, "Font Size",
			function() return SimpleBossModsDB.cfg.bars.fontSize end,
			function(v) addon:ApplyBarConfig(SimpleBossModsDB.cfg.bars.width, SimpleBossModsDB.cfg.bars.height, v, SimpleBossModsDB.cfg.bars.borderThickness) end,
			0.25
		)

		addNumberInput(bars, "Border Thickness",
			function() return SimpleBossModsDB.cfg.bars.borderThickness end,
			function(v) addon:ApplyBarConfig(SimpleBossModsDB.cfg.bars.width, SimpleBossModsDB.cfg.bars.height, SimpleBossModsDB.cfg.bars.fontSize, v) end,
			0.25
		)

		addNumberInput(bars, "Indicator Size",
			function() return SimpleBossModsDB.cfg.indicators.barSize or 0 end,
			function(v) addon:ApplyIndicatorConfig(SimpleBossModsDB.cfg.indicators.iconSize or 0, v) end,
			0.5
		)

		addNumberInput(bars, "Bar Gap",
			function() return SimpleBossModsDB.cfg.general.gap or 6 end,
			function(v)
				addon:ApplyGeneralConfig(
					v,
					SimpleBossModsDB.cfg.general.autoInsertKeystone
				)
			end,
			0.5
		)

		addDropdown(bars, "Grow Direction",
			{ UP = "Up", DOWN = "Down" },
			function() return SimpleBossModsDB.cfg.bars.growDirection end,
			function(v) addon:ApplyBarGrowDirection(v) end,
			0.33
		)

		addDropdown(bars, "Sort Order",
			{ ASC = "Ascending (lowest first)", DESC = "Descending (highest first)" },
			function() return (SimpleBossModsDB.cfg.bars.sortAscending ~= false) and "ASC" or "DESC" end,
			function(v) addon:ApplyBarSortOrder(v) end,
			0.33
		)

		addDropdown(bars, "Fill Direction",
			{ LEFT = "Left", RIGHT = "Right" },
			function() return SimpleBossModsDB.cfg.bars.fillDirection end,
			function(v) addon:ApplyBarFillDirection(v) end,
			0.33
		)

		addNumberInput(bars, "Display bars when seconds remaining",
			function() return SimpleBossModsDB.cfg.general.thresholdToBar end,
			function(v) addon:ApplyBarThresholdConfig(v) end,
			1
		)

		addCheckBox(bars, "Swap Icon Side",
			function() return SimpleBossModsDB.cfg.bars.swapIconSide end,
			function(v) addon:ApplyBarIconSideConfig(v) end,
			0.5
		)

		addCheckBox(bars, "Swap Indicator Side",
			function() return SimpleBossModsDB.cfg.bars.swapIndicatorSide end,
			function(v) addon:ApplyBarIndicatorSideConfig(v) end,
			0.5
		)

		addCheckBox(bars, "Hide Icon",
			function() return SimpleBossModsDB.cfg.bars.hideIcon end,
			function(v) addon:ApplyBarIconVisibilityConfig(v) end,
			0.5
		)

		local defaults = AG:Create("InlineGroup")
		defaults:SetTitle("Default Colors (Timeline)")
		defaults:SetLayout("Flow")
		defaults:SetFullWidth(true)
		container:AddChild(defaults)

		addColorPicker(defaults, "Default Bar Color",
			function() return L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A end,
			function(r, g, b, a) addon:ApplyBarColor(r, g, b, a) end,
			0.5
		)

		addColorPicker(defaults, "Default Background Color",
			function() return L.BAR_BG_R, L.BAR_BG_G, L.BAR_BG_B, L.BAR_BG_A end,
			function(r, g, b, a) addon:ApplyBarBgColor(r, g, b, a) end,
			0.5
		)

		local defaultsNote = AG:Create("Label")
		defaultsNote:SetText("Timeline uses these defaults. BigWigs/DBM colors are sourced from their connectors.")
		defaultsNote:SetFullWidth(true)
		defaults:AddChild(defaultsNote)

		local media = AG:Create("InlineGroup")
		media:SetTitle("Fonts & Textures")
		media:SetLayout("Flow")
		media:SetFullWidth(true)
		container:AddChild(media)

		if LSM then
			local fontDropdown = AG:Create("LSM30_Font")
			fontDropdown:SetLabel("Font")
			fontDropdown:SetList(LSM:HashTable("font"))
			fontDropdown:SetValue(SimpleBossModsDB.cfg.general.font)
			fontDropdown:SetRelativeWidth(0.5)
			fontDropdown:SetCallback("OnValueChanged", function(widget, _, value)
				addon:ApplyFontConfig(value)
				widget:SetValue(SimpleBossModsDB.cfg.general.font)
			end)
			media:AddChild(fontDropdown)

			local barTextureDropdown = AG:Create("LSM30_Statusbar")
			barTextureDropdown:SetLabel("Texture")
			barTextureDropdown:SetList(LSM:HashTable("statusbar"))
			barTextureDropdown:SetValue(SimpleBossModsDB.cfg.bars.texture)
			barTextureDropdown:SetRelativeWidth(0.5)
			barTextureDropdown:SetCallback("OnValueChanged", function(widget, _, value)
				addon:ApplyBarTextureConfig(value)
				widget:SetValue(SimpleBossModsDB.cfg.bars.texture)
			end)
			media:AddChild(barTextureDropdown)
		else
			local label = AG:Create("Label")
			label:SetText("LibSharedMedia is not available.")
			label:SetFullWidth(true)
			media:AddChild(label)
		end

	end
	local function buildCombatTimerTab(container)
		local enabled = SimpleBossModsDB.cfg.combatTimer.enabled and true or false
		local enable = AG:Create("InlineGroup")
		enable:SetTitle("Combat Timer")
		enable:SetLayout("Flow")
		enable:SetFullWidth(true)
		container:AddChild(enable)

		local toggle = AG:Create("CheckBox")
		toggle:SetLabel("Enable Combat Timer")
		toggle:SetValue(enabled)
		toggle:SetFullWidth(true)
		toggle:SetCallback("OnValueChanged", function(_, _, value)
			addon:ApplyCombatTimerEnabled(value)
			container:ReleaseChildren()
			buildCombatTimerTab(container)
		end)
		enable:AddChild(toggle)

		if not enabled then
			local note = AG:Create("Label")
			note:SetText("Combat timer is currently disabled.")
			note:SetFullWidth(true)
			container:AddChild(note)
			return
		end

		local _, combatAnchorParentMap = buildAnchorParentLists(SimpleBossModsDB.cfg.combatTimer.anchorParent)

		local anchor = AG:Create("InlineGroup")
		anchor:SetTitle("Anchor")
		anchor:SetLayout("Flow")
		anchor:SetFullWidth(true)
		container:AddChild(anchor)

		local customParent

		addDropdown(anchor, "Anchor From",
			ANCHOR_POINT_MAP,
			function() return SimpleBossModsDB.cfg.combatTimer.anchorFrom end,
			function(v) addon:ApplyCombatTimerAnchorFrom(v) end,
			0.33
		)

		addDropdown(anchor, "Anchor To Parent",
			combatAnchorParentMap,
			function() return SimpleBossModsDB.cfg.combatTimer.anchorParent end,
			function(v)
				addon:ApplyCombatTimerAnchorParent(v)
				if customParent then
					customParent:SetText(SimpleBossModsDB.cfg.combatTimer.customParent or "")
				end
			end,
			0.33
		)

		addDropdown(anchor, "Anchor To",
			ANCHOR_POINT_MAP,
			function() return SimpleBossModsDB.cfg.combatTimer.anchorTo end,
			function(v) addon:ApplyCombatTimerAnchorTo(v) end,
			0.33
		)

		customParent = AG:Create("EditBox")
		customParent:SetLabel("Custom Parent (optional)")
		customParent:SetText(SimpleBossModsDB.cfg.combatTimer.customParent or "")
		customParent:SetFullWidth(true)
		customParent:SetCallback("OnEnterPressed", function(widget, _, text)
			addon:ApplyCombatTimerCustomParent(text)
			widget:SetText(SimpleBossModsDB.cfg.combatTimer.customParent or "")
		end)
		anchor:AddChild(customParent)

		addNumberInput(anchor, "X Offset",
			function() return SimpleBossModsDB.cfg.combatTimer.x or 0 end,
			function(v) addon:ApplyCombatTimerPosition(v, SimpleBossModsDB.cfg.combatTimer.y or 0) end,
			0.5
		)

		addNumberInput(anchor, "Y Offset",
			function() return SimpleBossModsDB.cfg.combatTimer.y or 0 end,
			function(v) addon:ApplyCombatTimerPosition(SimpleBossModsDB.cfg.combatTimer.x or 0, v) end,
			0.5
		)

		local text = AG:Create("InlineGroup")
		text:SetTitle("Text")
		text:SetLayout("Flow")
		text:SetFullWidth(true)
		container:AddChild(text)

		addNumberInput(text, "Font Size",
			function() return SimpleBossModsDB.cfg.combatTimer.fontSize end,
			function(v) addon:ApplyCombatTimerFontSize(v) end,
			0.5
		)

		if LSM then
			local fontDropdown = AG:Create("LSM30_Font")
			fontDropdown:SetLabel("Font")
			fontDropdown:SetList(LSM:HashTable("font"))
			fontDropdown:SetValue(SimpleBossModsDB.cfg.combatTimer.font)
			fontDropdown:SetRelativeWidth(0.5)
			fontDropdown:SetCallback("OnValueChanged", function(widget, _, value)
				addon:ApplyCombatTimerFont(value)
				widget:SetValue(SimpleBossModsDB.cfg.combatTimer.font)
			end)
			text:AddChild(fontDropdown)
		else
			local label = AG:Create("Label")
			label:SetText("LibSharedMedia is not available.")
			label:SetFullWidth(true)
			text:AddChild(label)
		end

		local colors = AG:Create("InlineGroup")
		colors:SetTitle("Colors")
		colors:SetLayout("Flow")
		colors:SetFullWidth(true)
		container:AddChild(colors)

		addColorPicker(colors, "Text Color",
			function()
				local c = SimpleBossModsDB.cfg.combatTimer.color
				return c.r, c.g, c.b, c.a
			end,
			function(r, g, b, a) addon:ApplyCombatTimerColor(r, g, b, a) end,
			0.33
		)

		addColorPicker(colors, "Border Color",
			function()
				local c = SimpleBossModsDB.cfg.combatTimer.borderColor
				return c.r, c.g, c.b, c.a
			end,
			function(r, g, b, a) addon:ApplyCombatTimerBorderColor(r, g, b, a) end,
			0.33
		)

		addColorPicker(colors, "Background Color",
			function()
				local c = SimpleBossModsDB.cfg.combatTimer.bgColor
				return c.r, c.g, c.b, c.a
			end,
			function(r, g, b, a) addon:ApplyCombatTimerBgColor(r, g, b, a) end,
			0.33
		)
	end

	local function buildPrivateTab(container)
		local enabled = SimpleBossModsDB.cfg.privateAuras.enabled ~= false
		local enable = AG:Create("InlineGroup")
		enable:SetTitle("Private Auras")
		enable:SetLayout("Flow")
		enable:SetFullWidth(true)
		container:AddChild(enable)

		local toggle = AG:Create("CheckBox")
		toggle:SetLabel("Enable Tracking")
		toggle:SetValue(enabled)
		toggle:SetFullWidth(true)
		toggle:SetCallback("OnValueChanged", function(_, _, value)
			addon:ApplyPrivateAuraEnabled(value)
			container:ReleaseChildren()
			buildPrivateTab(container)
		end)
		enable:AddChild(toggle)

		if not enabled then
			local note = AG:Create("Label")
			note:SetText("Private aura tracking is currently disabled.")
			note:SetFullWidth(true)
			container:AddChild(note)
			return
		end

		local _, privateAnchorParentMap = buildAnchorParentLists(SimpleBossModsDB.cfg.privateAuras.anchorParent)

		local anchor = AG:Create("InlineGroup")
		anchor:SetTitle("Anchor")
		anchor:SetLayout("Flow")
		anchor:SetFullWidth(true)
		container:AddChild(anchor)

		local customParent

		addDropdown(anchor, "Anchor From",
			ANCHOR_POINT_MAP,
			function() return SimpleBossModsDB.cfg.privateAuras.anchorFrom end,
			function(v) addon:ApplyPrivateAuraAnchorFrom(v) end,
			0.33
		)

		addDropdown(anchor, "Anchor To Parent",
			privateAnchorParentMap,
			function() return SimpleBossModsDB.cfg.privateAuras.anchorParent end,
			function(v)
				addon:ApplyPrivateAuraAnchorParent(v)
				if customParent then
					customParent:SetText(SimpleBossModsDB.cfg.privateAuras.customParent or "")
				end
			end,
			0.33
		)

		addDropdown(anchor, "Anchor To",
			ANCHOR_POINT_MAP,
			function() return SimpleBossModsDB.cfg.privateAuras.anchorTo end,
			function(v) addon:ApplyPrivateAuraAnchorTo(v) end,
			0.33
		)

		customParent = AG:Create("EditBox")
		customParent:SetLabel("Custom Parent (optional)")
		customParent:SetText(SimpleBossModsDB.cfg.privateAuras.customParent or "")
		customParent:SetFullWidth(true)
		customParent:SetCallback("OnEnterPressed", function(widget, _, text)
			addon:ApplyPrivateAuraCustomParent(text)
			widget:SetText(SimpleBossModsDB.cfg.privateAuras.customParent or "")
		end)
		anchor:AddChild(customParent)

		addNumberInput(anchor, "X Offset",
			function() return SimpleBossModsDB.cfg.privateAuras.x or 0 end,
			function(v) addon:ApplyPrivateAuraPosition(v, SimpleBossModsDB.cfg.privateAuras.y or 0) end,
			0.5
		)

		addNumberInput(anchor, "Y Offset",
			function() return SimpleBossModsDB.cfg.privateAuras.y or 0 end,
			function(v) addon:ApplyPrivateAuraPosition(SimpleBossModsDB.cfg.privateAuras.x or 0, v) end,
			0.5
		)

		local layout = AG:Create("InlineGroup")
		layout:SetTitle("Layout")
		layout:SetLayout("Flow")
		layout:SetFullWidth(true)
		container:AddChild(layout)

		addNumberInput(layout, "Icon Size",
			function() return SimpleBossModsDB.cfg.privateAuras.size end,
			function(v)
				addon:ApplyPrivateAuraConfig(
					v,
					SimpleBossModsDB.cfg.privateAuras.gap,
					SimpleBossModsDB.cfg.privateAuras.growDirection,
					SimpleBossModsDB.cfg.privateAuras.x,
					SimpleBossModsDB.cfg.privateAuras.y
				)
			end,
			0.5
		)

		addNumberInput(layout, "Icon Gap",
			function() return SimpleBossModsDB.cfg.privateAuras.gap end,
			function(v)
				addon:ApplyPrivateAuraConfig(
					SimpleBossModsDB.cfg.privateAuras.size,
					v,
					SimpleBossModsDB.cfg.privateAuras.growDirection,
					SimpleBossModsDB.cfg.privateAuras.x,
					SimpleBossModsDB.cfg.privateAuras.y
				)
			end,
			0.5
		)

		addDropdown(layout, "Grow Direction",
			{ RIGHT = "Right", LEFT = "Left", UP = "Up", DOWN = "Down" },
			function() return SimpleBossModsDB.cfg.privateAuras.growDirection end,
			function(v)
				addon:ApplyPrivateAuraConfig(
					SimpleBossModsDB.cfg.privateAuras.size,
					SimpleBossModsDB.cfg.privateAuras.gap,
					v,
					SimpleBossModsDB.cfg.privateAuras.x,
					SimpleBossModsDB.cfg.privateAuras.y
				)
			end,
			1
		)
	end

	local status = { selected = "Connectors" }
	addon._settingsTabStatus = status

	local tabs = AG:Create("TabGroup")
	tabs:SetLayout("Flow")
	tabs:SetFullWidth(true)
	tabs:SetFullHeight(true)
	tabs:SetTabs({
		{ text = "Connectors", value = "Connectors" },
		{ text = "Large Icons", value = "Icons" },
		{ text = "Bars", value = "Bars" },
		{ text = "Dungeon", value = "Dungeon" },
		{ text = "Combat Timer", value = "Combat" },
		{ text = "Private Auras", value = "Private" },
	})
	tabs:SetStatusTable(status)
	local validTabs = {
		Connectors = true,
		Icons = true,
		Bars = true,
		Dungeon = true,
		Combat = true,
		Private = true,
	}
	if status.selected == "Media" then
		status.selected = "Bars"
	elseif not validTabs[status.selected] then
		status.selected = "Connectors"
	end
	tabs:SetCallback("OnGroupSelected", function(container, _, group)
		container:ReleaseChildren()
		local scroll = AG:Create("ScrollFrame")
		scroll:SetLayout("Flow")
		scroll:SetFullWidth(true)
		scroll:SetFullHeight(true)
		container:AddChild(scroll)

		if group == "Connectors" then
			buildConnectorsTab(scroll)
		elseif group == "Icons" then
			buildIconsTab(scroll)
		elseif group == "Bars" then
			buildBarsTab(scroll)
		elseif group == "Dungeon" then
			buildDungeonTab(scroll)
		elseif group == "Combat" then
			buildCombatTimerTab(scroll)
		elseif group == "Private" then
			buildPrivateTab(scroll)
		end
		scroll:DoLayout()
		if scroll.FixScroll then
			scroll:FixScroll()
		end
	end)
	tabs:SelectTab(status.selected)
	addon._settingsTabGroup = tabs
	frame:AddChild(tabs)

	return frame
end

-- =========================
-- Settings Panel (Button-only)
-- =========================
function M:CreateSettingsPanel()
	if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end

	local panel = CreateFrame("Frame")
	panel.name = M._settingsCategoryName

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Simple Boss Mods")

	local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	desc:SetWidth(520)
	desc:SetJustifyH("LEFT")
	desc:SetText("Settings open in a separate window. Use the button below or type /sbm.")

	local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	btn:SetSize(200, 24)
	btn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
	btn:SetText("Open Settings")
	btn:SetScript("OnClick", function() M:OpenSettings() end)

	local category = Settings.RegisterCanvasLayoutCategory(panel, M._settingsCategoryName)
	Settings.RegisterAddOnCategory(category)

	if category and type(category.GetID) == "function" then
		M._settingsCategoryID = category:GetID()
	elseif category and type(category.ID) == "number" then
		M._settingsCategoryID = category.ID
	end

	panel:SetScript("OnShow", function()
		if M and M.EnsureDefaults then
			M:EnsureDefaults()
		end
	end)
end
