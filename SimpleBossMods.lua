-- SimpleBossMods.lua (Core)
-- Shared constants, defaults, and utility helpers.

local ADDON_NAME = ...
local M = _G[ADDON_NAME]
if not M then
	M = {}
	_G[ADDON_NAME] = M
end

M.Const = M.Const or {}
local C = M.Const

-- Font
C.FONT_PATH = "Interface\\AddOns\\SimpleBossMods\\media\\fonts\\Expressway.ttf"
C.FONT_FLAGS = "OUTLINE" -- or "THICKOUTLINE"

-- Bar texture (flat)
C.BAR_TEX_DEFAULT = "Interface\\TARGETINGFRAME\\UI-StatusBar"

-- Defaults
C.THRESHOLD_TO_BAR = 5.0
C.ICON_ZOOM = 0.10
C.ICONS_PER_ROW = 5
C.TICK_INTERVAL = 0.20

-- Move everything slightly up (requested)
C.GLOBAL_Y_NUDGE = 0.1

-- Manual timers
C.PULL_ICON = "Interface\\Icons\\Ability_Warrior_Charge"
C.BREAK_ICON = "Interface\\Icons\\INV_Misc_DeliciousPizza"
C.PULL_LABEL = "Pull"
C.BREAK_LABEL = "Break"

-- Indicators
C.INDICATOR_MAX = 6
C.INDICATOR_MASK = 1023 -- all bits
-- Private aura anchor slots (max icons in the group)
C.PRIVATE_AURA_MAX = 8

-- Bars: indicator icons outside to the right
C.BAR_END_INDICATOR_GAP_X = 6

-- Default bar colors
C.BAR_FG_R, C.BAR_FG_G, C.BAR_FG_B, C.BAR_FG_A = (255/255), (152/255), (0/255), 1.0
C.BAR_BG_R, C.BAR_BG_G, C.BAR_BG_B, C.BAR_BG_A = 0.0, 0.0, 0.0, 0.90

M.Defaults = M.Defaults or {
	pos = { x = 500, y = 50 },
	cfg = {
		general = {
			gap = 8,
			mirror = false,
			barsBelow = false,
			autoInsertKeystone = false,
			thresholdToBar = C.THRESHOLD_TO_BAR,
		},
		icons = { size = 64, fontSize = 32, borderThickness = 2 },
		bars = {
			width = 352,
			height = 36,
			fontSize = 16,
			borderThickness = 2,
			swapIconSide = false,
			hideIcon = false,
			color = {
				r = C.BAR_FG_R,
				g = C.BAR_FG_G,
				b = C.BAR_FG_B,
				a = C.BAR_FG_A,
			},
			bgColor = {
				r = C.BAR_BG_R,
				g = C.BAR_BG_G,
				b = C.BAR_BG_B,
				a = C.BAR_BG_A,
			},
		},
		indicators = { iconSize = 10, barSize = 20 },
		privateAuras = {
			size = 48,
			gap = 6,
			growDirection = "RIGHT",
			x = 0,
			y = 0,
			soundKitID = 316476,
		},
	},
}

function M:EnsureDefaults()
	SimpleBossModsDB = SimpleBossModsDB or {}
	SimpleBossModsDB.pos = SimpleBossModsDB.pos or { x = M.Defaults.pos.x, y = M.Defaults.pos.y }
	SimpleBossModsDB.cfg = SimpleBossModsDB.cfg or {}
	SimpleBossModsDB.manualTimers = SimpleBossModsDB.manualTimers or {}

	local cfg = SimpleBossModsDB.cfg
	cfg.general = cfg.general or {
		gap = M.Defaults.cfg.general.gap,
		mirror = M.Defaults.cfg.general.mirror,
		barsBelow = M.Defaults.cfg.general.barsBelow,
		autoInsertKeystone = M.Defaults.cfg.general.autoInsertKeystone,
		thresholdToBar = M.Defaults.cfg.general.thresholdToBar,
	}
	if cfg.general.mirror == nil then
		cfg.general.mirror = M.Defaults.cfg.general.mirror
	end
	if cfg.general.barsBelow == nil then
		cfg.general.barsBelow = M.Defaults.cfg.general.barsBelow
	end
	if cfg.general.autoInsertKeystone == nil then
		cfg.general.autoInsertKeystone = M.Defaults.cfg.general.autoInsertKeystone
	end
	if cfg.general.thresholdToBar == nil then
		cfg.general.thresholdToBar = M.Defaults.cfg.general.thresholdToBar
	end
	cfg.icons = cfg.icons or {
		size = M.Defaults.cfg.icons.size,
		fontSize = M.Defaults.cfg.icons.fontSize,
		borderThickness = M.Defaults.cfg.icons.borderThickness,
	}
	cfg.bars = cfg.bars or {
		width = M.Defaults.cfg.bars.width,
		height = M.Defaults.cfg.bars.height,
		fontSize = M.Defaults.cfg.bars.fontSize,
		borderThickness = M.Defaults.cfg.bars.borderThickness,
		swapIconSide = M.Defaults.cfg.bars.swapIconSide,
		hideIcon = M.Defaults.cfg.bars.hideIcon,
	}
	if cfg.bars.swapIconSide == nil then
		cfg.bars.swapIconSide = M.Defaults.cfg.bars.swapIconSide
	end
	if cfg.bars.hideIcon == nil then
		cfg.bars.hideIcon = M.Defaults.cfg.bars.hideIcon
	end
	cfg.bars.color = cfg.bars.color or {
		r = M.Defaults.cfg.bars.color.r,
		g = M.Defaults.cfg.bars.color.g,
		b = M.Defaults.cfg.bars.color.b,
		a = M.Defaults.cfg.bars.color.a,
	}
	cfg.bars.bgColor = cfg.bars.bgColor or {
		r = M.Defaults.cfg.bars.bgColor.r,
		g = M.Defaults.cfg.bars.bgColor.g,
		b = M.Defaults.cfg.bars.bgColor.b,
		a = M.Defaults.cfg.bars.bgColor.a,
	}
	local function approx(a, b)
		if type(a) ~= "number" or type(b) ~= "number" then return false end
		return math.abs(a - b) < 0.0001
	end
	local function repairColor(color, defR, defG, defB, defA)
		if type(color.r) ~= "number" then color.r = defR end
		if type(color.g) ~= "number" then color.g = defG end
		if type(color.b) ~= "number" then color.b = defB end
		if type(color.a) ~= "number" then color.a = defA end
		if color.a == 0 and approx(color.r, defR) and approx(color.g, defG) and approx(color.b, defB) then
			color.a = defA
		end
	end
	repairColor(cfg.bars.color, M.Defaults.cfg.bars.color.r, M.Defaults.cfg.bars.color.g, M.Defaults.cfg.bars.color.b, M.Defaults.cfg.bars.color.a)
	repairColor(cfg.bars.bgColor, M.Defaults.cfg.bars.bgColor.r, M.Defaults.cfg.bars.bgColor.g, M.Defaults.cfg.bars.bgColor.b, M.Defaults.cfg.bars.bgColor.a)
	cfg.indicators = cfg.indicators or {
		iconSize = M.Defaults.cfg.indicators.iconSize,
		barSize = M.Defaults.cfg.indicators.barSize,
	}
	cfg.privateAuras = cfg.privateAuras or {
		size = M.Defaults.cfg.privateAuras.size,
		gap = M.Defaults.cfg.privateAuras.gap,
		growDirection = M.Defaults.cfg.privateAuras.growDirection,
		x = M.Defaults.cfg.privateAuras.x,
		y = M.Defaults.cfg.privateAuras.y,
		soundKitID = M.Defaults.cfg.privateAuras.soundKitID,
	}
	if cfg.privateAuras.size == nil then
		cfg.privateAuras.size = M.Defaults.cfg.privateAuras.size
	end
	if cfg.privateAuras.gap == nil then
		cfg.privateAuras.gap = M.Defaults.cfg.privateAuras.gap
	end
	if cfg.privateAuras.x == nil then
		cfg.privateAuras.x = M.Defaults.cfg.privateAuras.x
	end
	if cfg.privateAuras.y == nil then
		cfg.privateAuras.y = M.Defaults.cfg.privateAuras.y
	end
	if cfg.privateAuras.soundKitID == nil then
		cfg.privateAuras.soundKitID = M.Defaults.cfg.privateAuras.soundKitID
	end
	do
		local dir = cfg.privateAuras.growDirection
		if type(dir) ~= "string" then
			dir = M.Defaults.cfg.privateAuras.growDirection
		end
		dir = dir:upper()
		if dir ~= "LEFT" and dir ~= "RIGHT" and dir ~= "UP" and dir ~= "DOWN" then
			dir = M.Defaults.cfg.privateAuras.growDirection
		end
		cfg.privateAuras.growDirection = dir
	end
end

M.Live = M.Live or {}
local L = M.Live

M.Util = M.Util or {}
local U = M.Util

function U.clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

function U.round(v)
	v = tonumber(v) or 0
	if v >= 0 then return math.floor(v + 0.5) end
	return math.ceil(v - 0.5)
end

function M.SyncLiveConfig()
	local gc = SimpleBossModsDB.cfg.general
	local ic = SimpleBossModsDB.cfg.icons
	local bc = SimpleBossModsDB.cfg.bars
	local inc = SimpleBossModsDB.cfg.indicators
	local pc = SimpleBossModsDB.cfg.privateAuras or M.Defaults.cfg.privateAuras

	L.GAP = tonumber(gc.gap) or 6
	L.MIRROR = gc.mirror and true or false
	L.BARS_BELOW = gc.barsBelow and true or false
	L.AUTO_INSERT_KEYSTONE = gc.autoInsertKeystone and true or false
	L.THRESHOLD_TO_BAR = U.clamp(tonumber(gc.thresholdToBar) or C.THRESHOLD_TO_BAR, 0.1, 600)

	L.ICON_SIZE = ic.size
	L.ICON_FONT_SIZE = ic.fontSize
	L.ICON_BORDER_THICKNESS = ic.borderThickness

	L.BAR_WIDTH = bc.width
	L.BAR_HEIGHT = bc.height
	L.BAR_FONT_SIZE = bc.fontSize
	L.BAR_BORDER_THICKNESS = bc.borderThickness
	L.BAR_ICON_SWAP = bc.swapIconSide and true or false
	L.BAR_ICON_HIDDEN = bc.hideIcon and true or false
	local barColor = bc.color or {}
	L.BAR_FG_R = U.clamp(tonumber(barColor.r) or C.BAR_FG_R, 0, 1)
	L.BAR_FG_G = U.clamp(tonumber(barColor.g) or C.BAR_FG_G, 0, 1)
	L.BAR_FG_B = U.clamp(tonumber(barColor.b) or C.BAR_FG_B, 0, 1)
	L.BAR_FG_A = U.clamp(tonumber(barColor.a) or C.BAR_FG_A, 0, 1)

	local barBg = bc.bgColor or {}
	L.BAR_BG_R = U.clamp(tonumber(barBg.r) or C.BAR_BG_R, 0, 1)
	L.BAR_BG_G = U.clamp(tonumber(barBg.g) or C.BAR_BG_G, 0, 1)
	L.BAR_BG_B = U.clamp(tonumber(barBg.b) or C.BAR_BG_B, 0, 1)
	L.BAR_BG_A = U.clamp(tonumber(barBg.a) or C.BAR_BG_A, 0, 1)

	L.ICON_INDICATOR_SIZE = tonumber(inc.iconSize) or 0
	L.BAR_INDICATOR_SIZE = tonumber(inc.barSize) or 0

	L.PRIVATE_AURA_SIZE = U.clamp(U.round(tonumber(pc.size) or M.Defaults.cfg.privateAuras.size), 16, 128)
	L.PRIVATE_AURA_GAP = U.clamp(U.round(tonumber(pc.gap) or 0), 0, 50)
	do
		local dir = pc.growDirection
		if type(dir) ~= "string" then
			dir = M.Defaults.cfg.privateAuras.growDirection
		end
		dir = dir:upper()
		if dir ~= "LEFT" and dir ~= "RIGHT" and dir ~= "UP" and dir ~= "DOWN" then
			dir = M.Defaults.cfg.privateAuras.growDirection
		end
		L.PRIVATE_AURA_GROW = dir
	end
	L.PRIVATE_AURA_X = tonumber(pc.x) or 0
	L.PRIVATE_AURA_Y = tonumber(pc.y) or 0
	L.PRIVATE_AURA_SOUND_KIT = tonumber(pc.soundKitID) or 0
end

local function isSecretValue(value)
	return type(issecretvalue) == "function" and issecretvalue(value)
end

local function formatClockTime(secs)
	if secs >= 3600 then
		local h = math.floor(secs / 3600)
		local m = math.floor((secs % 3600) / 60)
		local s = secs % 60
		return string.format("%d:%02d:%02d", h, m, s)
	end
	local m = math.floor(secs / 60)
	local s = secs % 60
	return string.format("%d:%02d", m, s)
end

function U.formatTimeIcon(rem)
	if isSecretValue(rem) then return "" end
	if rem <= 0 then return "" end
	local secs = math.max(0, math.floor(rem + 0.5))
	if secs >= 60 then
		return formatClockTime(secs)
	end
	return tostring(secs)
end

function U.formatTimeBar(rem)
	if isSecretValue(rem) then return "" end
	if rem >= 60 then
		local secs = math.max(0, math.floor(rem + 0.5))
		return formatClockTime(secs)
	end
	if rem >= 10 then
		return tostring(math.floor(rem + 0.5))
	end
	return string.format("%.1f", rem)
end

function M:GetManualTimerIcon(kind)
	local function normalizeIcon(icon)
		if type(icon) == "number" or type(icon) == "string" then
			return icon
		end
		return nil
	end

	if kind == "pull" then
		return C.PULL_ICON
	end
	if kind == "break" then
		local dbm = _G.DBM
		if type(dbm) == "table" then
			local icon = normalizeIcon(dbm.BreakIcon)
			if not icon and type(dbm.Options) == "table" then
				icon = normalizeIcon(dbm.Options.BreakTimerIcon or dbm.Options.BreakIcon)
			end
			if not icon and type(dbm.BreakTimer) == "table" then
				icon = normalizeIcon(dbm.BreakTimer.icon or dbm.BreakTimer.iconID or dbm.BreakTimer.iconTexture)
			end
			if icon then return icon end
		end
		return C.BREAK_ICON
	end
	return nil
end

function U.safeGetIconFileID(eventInfo)
	if type(eventInfo) ~= "table" then return nil end
	local icon = eventInfo.iconFileID or eventInfo.icon
	if icon then return icon end
	if type(eventInfo.spellID) == "number" then
		local ok, iconFileID = pcall(function()
			if C_Spell and C_Spell.GetSpellInfo then
				local info = C_Spell.GetSpellInfo(eventInfo.spellID)
				return info and info.iconID or nil
			end
			if GetSpellInfo then
				local _, _, iconTex = GetSpellInfo(eventInfo.spellID)
				return iconTex
			end
			return nil
		end)
		if ok then return iconFileID end
	end
	return nil
end

function U.safeGetLabel(eventInfo)
	if type(eventInfo) ~= "table" then return "" end
	local label = eventInfo.name or eventInfo.text or eventInfo.title or eventInfo.label
		or eventInfo.spellName or eventInfo.overrideName or ""

	if isSecretValue(label) then
		return label
	end

	if label == "" and type(eventInfo.spellID) == "number" then
		local ok, spellName = pcall(function()
			if C_Spell and C_Spell.GetSpellName then
				return C_Spell.GetSpellName(eventInfo.spellID)
			end
			if GetSpellInfo then
				return GetSpellInfo(eventInfo.spellID)
			end
			return nil
		end)
		if ok and type(spellName) == "string" then
			label = spellName
		end
	end

	return label
end

function M:CanUseTimelineScriptEvents()
	return C_EncounterTimeline and type(C_EncounterTimeline.AddScriptEvent) == "function"
end

function M:SafeAddScriptEvent(payload)
	if not (C_EncounterTimeline and type(C_EncounterTimeline.AddScriptEvent) == "function") then
		return nil
	end
	local ok, id = pcall(C_EncounterTimeline.AddScriptEvent, payload)
	if ok then return id end
	ok, id = pcall(C_EncounterTimeline.AddScriptEvent, C_EncounterTimeline, payload)
	if ok then return id end
	return nil
end

function U.barIndicatorSize()
	if L.BAR_INDICATOR_SIZE and L.BAR_INDICATOR_SIZE > 0 then
		return U.clamp(U.round(L.BAR_INDICATOR_SIZE), 8, 32)
	end
	return U.clamp(math.floor(L.BAR_HEIGHT * 0.55 + 0.5), 10, 22)
end

function U.iconIndicatorSize()
	-- inside icon, bottom-right; tiny bit smaller
	if L.ICON_INDICATOR_SIZE and L.ICON_INDICATOR_SIZE > 0 then
		return U.clamp(U.round(L.ICON_INDICATOR_SIZE), 8, 24)
	end
	return U.clamp(math.floor(L.ICON_SIZE * 0.22 + 0.5), 10, 18)
end

M:EnsureDefaults()
M.SyncLiveConfig()

-- =========================
-- State
-- =========================
M.enabled = true
M.events = M.events or {}
M._settingsCategoryName = "SimpleBossMods"
M._settingsCategoryID = nil
M._testTicker = nil
M._testTimelineEventIDs = nil
M._testTimelineEventIDSet = nil
M._testEditModeEventTimer = nil
M._privateAuraAnchorIDs = nil
M._privateAuraLastCount = nil
