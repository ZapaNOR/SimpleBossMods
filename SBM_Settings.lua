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

local bitBand = (bit and bit.band) or (bit32 and bit32.band)

local function deepCopyTable(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopyTable(v)
	end
	return copy
end

local function flushEncounterEventColorRefresh()
	if type(M.BuildEncounterEventCache) ~= "function" then
		return
	end
	M._cacheRebuildPending = true
	if type(M.EnsureEncounterEventCache) == "function" then
		M:EnsureEncounterEventCache()
	else
		M:BuildEncounterEventCache()
	end
end

local function requestEncounterEventColorRefresh()
	if not (C_Timer and type(C_Timer.NewTimer) == "function") then
		flushEncounterEventColorRefresh()
		return
	end
	if M._encounterColorRefreshTimer and M._encounterColorRefreshTimer.Cancel then
		M._encounterColorRefreshTimer:Cancel()
	end
	M._encounterColorRefreshTimer = C_Timer.NewTimer(0.25, function()
		M._encounterColorRefreshTimer = nil
		flushEncounterEventColorRefresh()
	end)
	if type(M.EnsureEncounterEventCache) == "function" then
		M._cacheRebuildPending = true
	end
end

local function ensureColorPickerCloseHook()
	if M._sbmColorPickerCloseHooked then
		return
	end
	local pickerFrame = _G.ColorPickerFrame
	if not (pickerFrame and type(pickerFrame.HookScript) == "function") then
		return
	end
	local function flushPendingColorCommit()
		local commit = M._sbmPendingColorCommit
		M._sbmPendingColorCommit = nil
		if type(commit) == "function" then
			commit()
		end
	end
	pickerFrame:HookScript("OnHide", function()
		-- Let any immediate confirmation callbacks run first.
		if C_Timer and type(C_Timer.After) == "function" then
			C_Timer.After(0, flushPendingColorCommit)
		else
			flushPendingColorCommit()
		end
	end)
	M._sbmColorPickerCloseHooked = true
end

local INDICATOR_COLOR_ORDER = {
	"deadly",
	"enrage",
	"bleed",
	"magic",
	"disease",
	"curse",
	"poison",
	"tank",
	"healer",
	"dps",
	"severitylow",
	"severitymedium",
	"severityhigh",
}

local INDICATOR_COLOR_LABELS = {
	deadly = "Deadly",
	enrage = "Enrage",
	bleed = "Bleed",
	magic = "Magic",
	disease = "Disease",
	curse = "Curse",
	poison = "Poison",
	tank = "Tank",
	healer = "Healer",
	dps = "DPS",
	severitylow = "Low",
	severitymedium = "Medium",
	severityhigh = "High",
}

local INDICATOR_PRIORITY_GROUP_LABELS = {
	playerRole = "Player Role",
	dispels = "Dispels",
	roles = "Roles",
	other = "Other",
	severity = "Severity",
}

local CACHE_MASK_ORDER = {
	"deadly",
	"enrage",
	"bleed",
	"magic",
	"disease",
	"curse",
	"poison",
	"tank",
	"healer",
	"dps",
}

local CACHE_MASK_MAP = {
	deadly = 1,
	enrage = 2,
	bleed = 4,
	magic = 8,
	disease = 16,
	curse = 32,
	poison = 64,
	tank = 128,
	healer = 256,
	dps = 512,
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
function M:ResetAllSettings()
	SimpleBossModsDB = SimpleBossModsDB or {}
	SimpleBossModsDB.cfg = deepCopyTable(M.Defaults.cfg or {})

	if self.EnsureDefaults then
		self:EnsureDefaults()
	end
	M.SyncLiveConfig()

	if self.SetupKeystoneAutoInsert then
		self:SetupKeystoneAutoInsert()
	end
	if self.ApplyTimelineRecommendedMode then
		self:ApplyTimelineRecommendedMode()
	elseif self.ApplyTimelineConnectorMode then
		self:ApplyTimelineConnectorMode()
	end
	if self.UpdateIconsAnchorPosition then
		self:UpdateIconsAnchorPosition()
	end
	if self.UpdateBarsAnchorPosition then
		self:UpdateBarsAnchorPosition()
	end
	if self.UpdatePrivateAuraAnchor then
		self:UpdatePrivateAuraAnchor()
	elseif self.UpdatePrivateAuraAnchorPosition then
		self:UpdatePrivateAuraAnchorPosition()
	end
	if self.UpdatePrivateAuraFrames then
		self:UpdatePrivateAuraFrames()
	end
	if self.UpdateCombatTimerAppearance then
		self:UpdateCombatTimerAppearance()
	end
	if self.UpdateCombatTimerState then
		self:UpdateCombatTimerState()
	end

	requestEncounterEventColorRefresh()
	for id, rec in pairs(self.events or {}) do
		self:updateRecord(id, rec.eventInfo, rec.remaining)
	end
	if self.Tick then
		self:Tick()
	end
	if self.LayoutAll then
		self:LayoutAll()
	end
end

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

function M:ApplyIndicatorPriorityGroups(groups)
	if type(groups) ~= "table" then
		return
	end
	local normalized = groups
	if type(M.NormalizeIndicatorPriorityGroups) == "function" then
		normalized = M.NormalizeIndicatorPriorityGroups(groups)
	end
	SimpleBossModsDB.cfg.general.indicatorPriorityGroups = normalized
	M.SyncLiveConfig()
	requestEncounterEventColorRefresh()
	if self.Tick then
		self:Tick()
	end
	if self.LayoutAll then
		self:LayoutAll()
	end
end

function M:ApplyPriorityPresetIndicators()
	local gc = SimpleBossModsDB.cfg.general
	local defaults = M.Defaults.cfg.general
	local order = {
		"playerRole",
		"dispels",
		"roles",
		"other",
		"severity",
	}
	gc.indicatorPriorityGroups = (type(M.NormalizeIndicatorPriorityGroups) == "function")
		and M.NormalizeIndicatorPriorityGroups(order)
		or order
	gc.useDispelColors = defaults.useDispelColors ~= false
	gc.useRoleColors = defaults.useRoleColors ~= false
	gc.useOtherColors = defaults.useOtherColors ~= false
	gc.usePlayerRoleColor = defaults.usePlayerRoleColor ~= false
	gc.useSeverityColors = defaults.useSeverityColors ~= false

	M.SyncLiveConfig()
	requestEncounterEventColorRefresh()
	if self.Tick then
		self:Tick()
	end
	if self.LayoutAll then
		self:LayoutAll()
	end
end

function M:ApplyPriorityPresetSeverity()
	local gc = SimpleBossModsDB.cfg.general
	local order = {
		"severity",
		"dispels",
		"roles",
		"other",
		"playerRole",
	}
	gc.indicatorPriorityGroups = (type(M.NormalizeIndicatorPriorityGroups) == "function")
		and M.NormalizeIndicatorPriorityGroups(order)
		or order
	gc.useDispelColors = false
	gc.useRoleColors = false
	gc.useOtherColors = false
	gc.usePlayerRoleColor = false
	gc.useSeverityColors = true

	M.SyncLiveConfig()
	requestEncounterEventColorRefresh()
	if self.Tick then
		self:Tick()
	end
	if self.LayoutAll then
		self:LayoutAll()
	end
end

function M:ApplyUseDispelColors(enabled)
	SimpleBossModsDB.cfg.general.useDispelColors = enabled and true or false
	M.SyncLiveConfig()
	requestEncounterEventColorRefresh()
	if self.Tick then
		self:Tick()
	end
	if self.LayoutAll then
		self:LayoutAll()
	end
end

function M:ApplyUseRoleColors(enabled)
	SimpleBossModsDB.cfg.general.useRoleColors = enabled and true or false
	M.SyncLiveConfig()
	requestEncounterEventColorRefresh()
	if self.Tick then
		self:Tick()
	end
	if self.LayoutAll then
		self:LayoutAll()
	end
end

function M:ApplyUseOtherColors(enabled)
	SimpleBossModsDB.cfg.general.useOtherColors = enabled and true or false
	M.SyncLiveConfig()
	requestEncounterEventColorRefresh()
	if self.Tick then
		self:Tick()
	end
	if self.LayoutAll then
		self:LayoutAll()
	end
end

function M:ApplyUsePlayerRoleColor(enabled)
	SimpleBossModsDB.cfg.general.usePlayerRoleColor = enabled and true or false
	M.SyncLiveConfig()
	requestEncounterEventColorRefresh()
	if self.Tick then
		self:Tick()
	end
	if self.LayoutAll then
		self:LayoutAll()
	end
end

function M:ApplyUseSeverityColors(enabled)
	SimpleBossModsDB.cfg.general.useSeverityColors = enabled and true or false
	M.SyncLiveConfig()
	requestEncounterEventColorRefresh()
	if self.Tick then
		self:Tick()
	end
	if self.LayoutAll then
		self:LayoutAll()
	end
end

function M:ApplyUseIconBorderColors(enabled)
	SimpleBossModsDB.cfg.general.useIconBorderColors = enabled and true or false
	M.SyncLiveConfig()
	if self.Tick then
		self:Tick()
	end
	if self.LayoutAll then
		self:LayoutAll()
	end
end

function M:ApplyUseCustomPlayerRoleColor(enabled)
	SimpleBossModsDB.cfg.general.useCustomPlayerRoleColor = enabled and true or false
	M.SyncLiveConfig()
	requestEncounterEventColorRefresh()
	if self.LayoutAll then
		self:LayoutAll()
	end
end

function M:ApplyCustomPlayerRoleColor(r, g, b, a)
	local crc = SimpleBossModsDB.cfg.general.customPlayerRoleColor or {}
	crc.r = U.clamp(tonumber(r) or 1.0, 0, 1)
	crc.g = U.clamp(tonumber(g) or 0.84, 0, 1)
	crc.b = U.clamp(tonumber(b) or 0.0, 0, 1)
	crc.a = U.clamp(tonumber(a) or 1.0, 0, 1)
	SimpleBossModsDB.cfg.general.customPlayerRoleColor = crc
	
	M.SyncLiveConfig()
	requestEncounterEventColorRefresh()
	if self.LayoutAll then
		self:LayoutAll()
	end
end

function M:ApplyGeneralTimelineRecommendedSettings(enabled)
	SimpleBossModsDB.cfg.general.useRecommendedTimelineSettings = enabled and true or false
	M.SyncLiveConfig()
	if self.ApplyTimelineRecommendedMode then
		self:ApplyTimelineRecommendedMode()
	elseif self.ApplyTimelineConnectorMode then
		self:ApplyTimelineConnectorMode()
	end
	if not enabled then
		local timelineFrame = _G.EncounterTimeline
		if timelineFrame and type(timelineFrame.Show) == "function" then
			pcall(timelineFrame.Show, timelineFrame)
		end
	end
end

function M:ApplyGeneralAnimationConfig(animateIcons, animateBars)
	local gc = SimpleBossModsDB.cfg.general
	if animateIcons == nil then
		animateIcons = gc.animateIcons ~= false
	end
	if animateBars == nil then
		animateBars = gc.animateBars ~= false
	end
	gc.animateIcons = animateIcons and true or false
	gc.animateBars = animateBars and true or false

	M.SyncLiveConfig()
	if self.ClearTimelineAnimationState then
		self:ClearTimelineAnimationState()
	end
	if self.LayoutAll then
		self:LayoutAll()
	end
end

function M:ApplyGeneralIndicatorColor(key, r, g, b, a)
	local defaults = M.Defaults.cfg.general.indicatorColors[key]
	if not defaults then
		return
	end
	local gc = SimpleBossModsDB.cfg.general
	gc.indicatorColors = gc.indicatorColors or {}
	gc.indicatorColors[key] = gc.indicatorColors[key] or {}
	gc.indicatorColors[key].r = U.clamp(tonumber(r) or defaults.r, 0, 1)
	gc.indicatorColors[key].g = U.clamp(tonumber(g) or defaults.g, 0, 1)
	gc.indicatorColors[key].b = U.clamp(tonumber(b) or defaults.b, 0, 1)
	gc.indicatorColors[key].a = U.clamp(tonumber(a) or defaults.a, 0, 1)

	M.SyncLiveConfig()
	requestEncounterEventColorRefresh()

	if self.Tick then
		self:Tick()
	end
	if self.LayoutAll then
		self:LayoutAll()
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

function M:ApplyBarIndicatorVisibilityConfig(hideIndicators)
	local bc = SimpleBossModsDB.cfg.bars
	bc.hideIndicators = hideIndicators and true or false

	M.SyncLiveConfig()
	refreshBarMirrorAndIndicators()
end

function M:ApplyBarThresholdConfig(threshold)
	local gc = SimpleBossModsDB.cfg.general
	local v = tonumber(threshold)
	if v == nil then
		v = gc.thresholdToBar or C.THRESHOLD_TO_BAR
	end
	gc.thresholdToBar = U.clamp(v, 0, 600)

	M.SyncLiveConfig()
	requestEncounterEventColorRefresh()

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
			self._settingsTabGroup:SelectTab(self._settingsTabStatus.selected or "General")
		elseif frame._refreshAll then
			frame._refreshAll()
		end
		return
	end

	if Settings and Settings.OpenToCategory and type(self._settingsCategoryID) == "number" then
		Settings.OpenToCategory(self._settingsCategoryID)
	end
end

function M:CreateSettingsWindow()
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

	local function addTextInput(container, label, getValue, setValue, width)
		local input = AG:Create("EditBox")
		input:SetLabel(label)
		input:SetText(tostring(getValue() or ""))
		if width then
			input:SetRelativeWidth(width)
		else
			input:SetFullWidth(true)
		end
		input:SetCallback("OnEnterPressed", function(widget, _, text)
			setValue(text or "")
			widget:SetText(tostring(getValue() or ""))
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
		ensureColorPickerCloseHook()
		if width then
			cp:SetRelativeWidth(width)
		else
			cp:SetFullWidth(true)
		end
		local pendingR, pendingG, pendingB, pendingA
		local hasPending = false
		local function commitPendingColor()
			if not hasPending then
				return
			end
			hasPending = false
			local cr, cg, cb, ca = pendingR, pendingG, pendingB, pendingA
			pendingR, pendingG, pendingB, pendingA = nil, nil, nil, nil
			setValue(cr, cg, cb, ca)
			local sr, sg, sb, sa = getValue()
			cp:SetColor(sr, sg, sb, sa)
		end
		cp:SetCallback("OnValueChanged", function(_, _, nr, ng, nb, na)
			pendingR, pendingG, pendingB, pendingA = nr, ng, nb, na
			hasPending = true
			local pickerFrame = _G.ColorPickerFrame
			if pickerFrame and pickerFrame:IsShown() then
				M._sbmPendingColorCommit = commitPendingColor
			else
				if M._sbmPendingColorCommit == commitPendingColor then
					M._sbmPendingColorCommit = nil
				end
				commitPendingColor()
			end
		end)
		cp:SetCallback("OnValueConfirmed", function(_, _, nr, ng, nb, na)
			pendingR, pendingG, pendingB, pendingA = nr, ng, nb, na
			hasPending = true
			if M._sbmPendingColorCommit == commitPendingColor then
				M._sbmPendingColorCommit = nil
			end
			commitPendingColor()
		end)
		container:AddChild(cp)
		return cp
	end

		local function buildGeneralTab(container)
			local timeline = AG:Create("InlineGroup")
			timeline:SetTitle("Timeline")
			timeline:SetLayout("Flow")
			timeline:SetFullWidth(true)
			container:AddChild(timeline)

			addCheckBox(timeline, "Use recommended timeline settings",
				function() return SimpleBossModsDB.cfg.general.useRecommendedTimelineSettings ~= false end,
				function(value)
					if addon.ApplyGeneralTimelineRecommendedSettings then
						addon:ApplyGeneralTimelineRecommendedSettings(value)
					end
				end,
				1
			)

			addCheckBox(timeline, "Animate Icons",
				function() return SimpleBossModsDB.cfg.general.animateIcons ~= false end,
				function(value)
					if addon.ApplyGeneralAnimationConfig then
						addon:ApplyGeneralAnimationConfig(
							value,
							SimpleBossModsDB.cfg.general.animateBars ~= false
						)
					end
				end,
				0.5
			)

			addCheckBox(timeline, "Animate Bars",
				function() return SimpleBossModsDB.cfg.general.animateBars ~= false end,
				function(value)
					if addon.ApplyGeneralAnimationConfig then
						addon:ApplyGeneralAnimationConfig(
							SimpleBossModsDB.cfg.general.animateIcons ~= false,
							value
						)
					end
				end,
				0.5
			)

			local note = AG:Create("Label")
			note:SetText("Recommended: keeps the Blizzard timeline active, sets it to Bars, and hides the Blizzard timeline frame so SBM receives better event data.")
			note:SetFullWidth(true)
			timeline:AddChild(note)

			local note2 = AG:Create("Label")
			note2:SetText("Disable this if you want Blizzard timeline behavior unchanged.")
			note2:SetFullWidth(true)
			timeline:AddChild(note2)

			local maintenance = AG:Create("InlineGroup")
			maintenance:SetTitle("Maintenance")
			maintenance:SetLayout("Flow")
			maintenance:SetFullWidth(true)
			container:AddChild(maintenance)

			local resetAll = AG:Create("Button")
			resetAll:SetText("Reset all settings")
			resetAll:SetFullWidth(true)
			resetAll:SetCallback("OnClick", function()
				if addon.ResetAllSettings then
					addon:ResetAllSettings()
				end
				if addon._settingsTabGroup then
					local selected = (addon._settingsTabStatus and addon._settingsTabStatus.selected) or "General"
					if addon._settingsTabStatus then
						addon._settingsTabStatus.selected = nil
					end
					addon._settingsTabGroup:SelectTab(selected)
				end
			end)
			maintenance:AddChild(resetAll)
		end

		local function buildColorsTab(container)
			local function rebuildColorsTab()
				container:ReleaseChildren()
				buildColorsTab(container)
				container:DoLayout()
				if container.FixScroll then
					container:FixScroll()
				end
			end

			local defaults = AG:Create("InlineGroup")
			defaults:SetTitle("Default Colors")
			defaults:SetLayout("Flow")
			defaults:SetFullWidth(true)
			container:AddChild(defaults)

			addColorPicker(defaults, "Bar Color",
				function() return L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A end,
				function(r, g, b, a) addon:ApplyBarColor(r, g, b, a) end,
				0.33
			)

			addColorPicker(defaults, "Background Color",
				function() return L.BAR_BG_R, L.BAR_BG_G, L.BAR_BG_B, L.BAR_BG_A end,
				function(r, g, b, a) addon:ApplyBarBgColor(r, g, b, a) end,
				0.33
			)

			addCheckBox(defaults, "Use icon border colors",
				function() return SimpleBossModsDB.cfg.general.useIconBorderColors and true or false end,
				function(v) M:ApplyUseIconBorderColors(v) end,
				0.33
			)

			local presets = AG:Create("InlineGroup")
			presets:SetTitle("Presets")
			presets:SetLayout("Flow")
			presets:SetFullWidth(true)
			container:AddChild(presets)

			local indicatorsPreset = AG:Create("Button")
			indicatorsPreset:SetText("Indicators")
			indicatorsPreset:SetRelativeWidth(0.5)
			indicatorsPreset:SetCallback("OnClick", function()
				M:ApplyPriorityPresetIndicators()
				rebuildColorsTab()
			end)
			presets:AddChild(indicatorsPreset)

			local severityPreset = AG:Create("Button")
			severityPreset:SetText("Severity")
			severityPreset:SetRelativeWidth(0.5)
			severityPreset:SetCallback("OnClick", function()
				M:ApplyPriorityPresetSeverity()
				rebuildColorsTab()
			end)
			presets:AddChild(severityPreset)

			local priorityGroup = AG:Create("InlineGroup")
			priorityGroup:SetTitle("Priority")
			priorityGroup:SetLayout("Flow")
			priorityGroup:SetFullWidth(true)
			container:AddChild(priorityGroup)

			local priorityLabel = AG:Create("Label")
			priorityLabel:SetText("If multiple criteria are met, this list decides which color is shown.")
			priorityLabel:SetFullWidth(true)
			priorityGroup:AddChild(priorityLabel)

			local groupOrder = SimpleBossModsDB.cfg.general.indicatorPriorityGroups
			if type(M.NormalizeIndicatorPriorityGroups) == "function" then
				groupOrder = M.NormalizeIndicatorPriorityGroups(groupOrder)
			end
			SimpleBossModsDB.cfg.general.indicatorPriorityGroups = groupOrder

			for idx, key in ipairs(groupOrder) do
				local nameWidth = 0.33
				local toggleWidth = 0.25
				local moveWidth = 0.20
				local row = AG:Create("SimpleGroup")
				row:SetLayout("Flow")
				row:SetFullWidth(true)
				priorityGroup:AddChild(row)

				local name = AG:Create("Label")
				name:SetText(string.format("%d. %s", idx, INDICATOR_PRIORITY_GROUP_LABELS[key] or key))
				name:SetRelativeWidth(nameWidth)
				row:AddChild(name)
				local hasToggle = false

				if key == "playerRole" then
					addCheckBox(row, "Use custom color",
						function() return SimpleBossModsDB.cfg.general.useCustomPlayerRoleColor and true or false end,
						function(v) M:ApplyUseCustomPlayerRoleColor(v) end,
						toggleWidth
					)
					hasToggle = true
				elseif key == "dispels" then
					addCheckBox(row, "Use colors",
						function() return SimpleBossModsDB.cfg.general.useDispelColors ~= false end,
						function(v) M:ApplyUseDispelColors(v) end,
						toggleWidth
					)
					hasToggle = true
				elseif key == "roles" then
					addCheckBox(row, "Use colors",
						function() return SimpleBossModsDB.cfg.general.useRoleColors ~= false end,
						function(v) M:ApplyUseRoleColors(v) end,
						toggleWidth
					)
					hasToggle = true
				elseif key == "other" then
					addCheckBox(row, "Use colors",
						function() return SimpleBossModsDB.cfg.general.useOtherColors ~= false end,
						function(v) M:ApplyUseOtherColors(v) end,
						toggleWidth
					)
					hasToggle = true
				elseif key == "severity" then
					addCheckBox(row, "Use colors",
						function() return SimpleBossModsDB.cfg.general.useSeverityColors ~= false end,
						function(v) M:ApplyUseSeverityColors(v) end,
						toggleWidth
					)
					hasToggle = true
				end

				if not hasToggle then
					local spacer = AG:Create("Label")
					spacer:SetText("")
					spacer:SetRelativeWidth(toggleWidth)
					row:AddChild(spacer)
				end

				local upButton = AG:Create("Button")
				upButton:SetText("Up")
				upButton:SetRelativeWidth(moveWidth)
				upButton:SetDisabled(idx == 1)
				upButton:SetCallback("OnClick", function()
					local newOrder = {}
					for i, groupKey in ipairs(groupOrder) do
						newOrder[i] = groupKey
					end
					newOrder[idx], newOrder[idx - 1] = newOrder[idx - 1], newOrder[idx]
					M:ApplyIndicatorPriorityGroups(newOrder)
					rebuildColorsTab()
				end)
				row:AddChild(upButton)

				local downButton = AG:Create("Button")
				downButton:SetText("Down")
				downButton:SetRelativeWidth(moveWidth)
				downButton:SetDisabled(idx == #groupOrder)
				downButton:SetCallback("OnClick", function()
					local newOrder = {}
					for i, groupKey in ipairs(groupOrder) do
						newOrder[i] = groupKey
					end
					newOrder[idx], newOrder[idx + 1] = newOrder[idx + 1], newOrder[idx]
					M:ApplyIndicatorPriorityGroups(newOrder)
					rebuildColorsTab()
				end)
				row:AddChild(downButton)
			end

			local indicators = AG:Create("InlineGroup")
			indicators:SetTitle("Indicators")
			indicators:SetLayout("Flow")
			indicators:SetFullWidth(true)
			container:AddChild(indicators)

			local dispelsGroup = AG:Create("InlineGroup")
			dispelsGroup:SetTitle("Dispels")
			dispelsGroup:SetLayout("Flow")
			dispelsGroup:SetFullWidth(true)
			indicators:AddChild(dispelsGroup)

			local dispels = { "magic", "disease", "curse", "poison", "bleed" }
			for _, key in ipairs(dispels) do
				local label = INDICATOR_COLOR_LABELS[key] or key:gsub("^%l", string.upper)
				addColorPicker(dispelsGroup, label,
					function()
						local colors = SimpleBossModsDB.cfg.general.indicatorColors or M.Defaults.cfg.general.indicatorColors
						local c = colors[key] or M.Defaults.cfg.general.indicatorColors[key]
						return c.r, c.g, c.b, c.a
					end,
					function(r, g, b, a)
						if addon.ApplyGeneralIndicatorColor then
							addon:ApplyGeneralIndicatorColor(key, r, g, b, a)
						end
					end,
					0.33
				)
			end

			local rolesGroup = AG:Create("InlineGroup")
			rolesGroup:SetTitle("Roles")
			rolesGroup:SetLayout("Flow")
			rolesGroup:SetFullWidth(true)
			indicators:AddChild(rolesGroup)

			local roles = { "tank", "healer", "dps" }
			for _, key in ipairs(roles) do
				local label = INDICATOR_COLOR_LABELS[key] or key:gsub("^%l", string.upper)
				addColorPicker(rolesGroup, label,
					function()
						local colors = SimpleBossModsDB.cfg.general.indicatorColors or M.Defaults.cfg.general.indicatorColors
						local c = colors[key] or M.Defaults.cfg.general.indicatorColors[key]
						return c.r, c.g, c.b, c.a
					end,
					function(r, g, b, a)
						if addon.ApplyGeneralIndicatorColor then
							addon:ApplyGeneralIndicatorColor(key, r, g, b, a)
						end
					end,
					0.33
				)
			end

			local otherGroup = AG:Create("InlineGroup")
			otherGroup:SetTitle("Other")
			otherGroup:SetLayout("Flow")
			otherGroup:SetFullWidth(true)
			indicators:AddChild(otherGroup)

			local other = { "deadly", "enrage" }
			for _, key in ipairs(other) do
				local label = INDICATOR_COLOR_LABELS[key] or key:gsub("^%l", string.upper)
				addColorPicker(otherGroup, label,
					function()
						local colors = SimpleBossModsDB.cfg.general.indicatorColors or M.Defaults.cfg.general.indicatorColors
						local c = colors[key] or M.Defaults.cfg.general.indicatorColors[key]
						return c.r, c.g, c.b, c.a
					end,
					function(r, g, b, a)
						if addon.ApplyGeneralIndicatorColor then
							addon:ApplyGeneralIndicatorColor(key, r, g, b, a)
						end
					end,
					0.33
				)
			end

			local playerRoleGroup = AG:Create("InlineGroup")
			playerRoleGroup:SetTitle("Player Role")
			playerRoleGroup:SetLayout("Flow")
			playerRoleGroup:SetFullWidth(true)
			indicators:AddChild(playerRoleGroup)

			addColorPicker(playerRoleGroup, "Player Role Color",
				function()
					local c = SimpleBossModsDB.cfg.general.customPlayerRoleColor or M.Defaults.cfg.general.customPlayerRoleColor
					return c.r, c.g, c.b, c.a
				end,
				function(r, g, b, a)
					M:ApplyCustomPlayerRoleColor(r, g, b, a)
				end,
				0.33
			)

			local severityGroup = AG:Create("InlineGroup")
			severityGroup:SetTitle("Severity")
			severityGroup:SetLayout("Flow")
			severityGroup:SetFullWidth(true)
			container:AddChild(severityGroup)

			local severities = { "severitylow", "severitymedium", "severityhigh" }
			for _, key in ipairs(severities) do
				local label = INDICATOR_COLOR_LABELS[key] or key
				addColorPicker(severityGroup, label,
					function()
						local colors = SimpleBossModsDB.cfg.general.indicatorColors or M.Defaults.cfg.general.indicatorColors
						local c = colors[key] or M.Defaults.cfg.general.indicatorColors[key]
						return c.r, c.g, c.b, c.a
					end,
					function(r, g, b, a)
						if addon.ApplyGeneralIndicatorColor then
							addon:ApplyGeneralIndicatorColor(key, r, g, b, a)
						end
					end,
					0.33
				)
			end
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

		addNumberInput(bars, "Display bars when seconds remaining (0 = icons only)",
			function() return SimpleBossModsDB.cfg.general.thresholdToBar end,
			function(v) addon:ApplyBarThresholdConfig(v) end,
			1
		)

		addCheckBox(bars, "Swap Icon Side",
			function() return SimpleBossModsDB.cfg.bars.swapIconSide end,
			function(v) addon:ApplyBarIconSideConfig(v) end,
			0.25
		)

		addCheckBox(bars, "Swap Indicator Side",
			function() return SimpleBossModsDB.cfg.bars.swapIndicatorSide end,
			function(v) addon:ApplyBarIndicatorSideConfig(v) end,
			0.25
		)

		addCheckBox(bars, "Hide Icon",
			function() return SimpleBossModsDB.cfg.bars.hideIcon end,
			function(v) addon:ApplyBarIconVisibilityConfig(v) end,
			0.25
		)

		addCheckBox(bars, "Hide Indicators",
			function() return SimpleBossModsDB.cfg.bars.hideIndicators end,
			function(v) addon:ApplyBarIndicatorVisibilityConfig(v) end,
			0.25
		)

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

	local status = { selected = "General" }
	addon._settingsTabStatus = status

	local tabs = AG:Create("TabGroup")
	tabs:SetLayout("Flow")
		tabs:SetFullWidth(true)
		tabs:SetFullHeight(true)
		tabs:SetTabs({
			{ text = "General", value = "General" },
			{ text = "Colors", value = "Colors" },
			{ text = "Large Icons", value = "Icons" },
			{ text = "Bars", value = "Bars" },
			{ text = "Dungeon", value = "Dungeon" },
			{ text = "Combat Timer", value = "Combat" },
		{ text = "Private Auras", value = "Private" },
	})
	tabs:SetStatusTable(status)
		local validTabs = {
			General = true,
			Colors = true,
			Icons = true,
			Bars = true,
			Dungeon = true,
			Combat = true,
		Private = true,
	}
	if status.selected == "Media" then
		status.selected = "Bars"
	elseif not validTabs[status.selected] then
		status.selected = "General"
	end
	tabs:SetCallback("OnGroupSelected", function(container, _, group)
		container:ReleaseChildren()
		local scroll = AG:Create("ScrollFrame")
		scroll:SetLayout("Flow")
		scroll:SetFullWidth(true)
		scroll:SetFullHeight(true)
		container:AddChild(scroll)

		if group == "General" then
			buildGeneralTab(scroll)
		elseif group == "Colors" then
			buildColorsTab(scroll)
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
