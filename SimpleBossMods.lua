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

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
M.LSM = LSM
if LSM then
	LSM:Register("font", "SBM Expressway", "Interface\\AddOns\\SimpleBossMods\\media\\fonts\\Expressway.ttf")
	LSM:Register("statusbar", "SBM Flat", "Interface\\Buttons\\WHITE8X8")
	LSM:Register("statusbar", "SBM Default", "Interface\\TARGETINGFRAME\\UI-StatusBar")
	LSM:Register("sound", "SBM: None", 0)
	LSM:Register("sound", "SBM: Raid Warning", 567397)
end

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

local SOUND_CHANNELS = {
	Master = "Master",
	MASTER = "Master",
	SFX = "SFX",
	Music = "Music",
	MUSIC = "Music",
	Ambience = "Ambience",
	AMBIENCE = "Ambience",
	Dialog = "Dialog",
	DIALOG = "Dialog",
}

function M.NormalizeSoundChannel(channel)
	if type(channel) ~= "string" then return nil end
	return SOUND_CHANNELS[channel]
end

M.Defaults = M.Defaults or {
	cfg = {
		general = {
			gap = 8,
			autoInsertKeystone = false,
			thresholdToBar = C.THRESHOLD_TO_BAR,
			font = "SBM Expressway",
		},
		icons = {
			enabled = true,
			size = 64,
			fontSize = 32,
			borderThickness = 2,
			font = "SBM Expressway",
			gap = 8,
			perRow = C.ICONS_PER_ROW,
			limit = 0,
			anchorFrom = "TOPLEFT",
			anchorTo = "CENTER",
			anchorParent = "NONE",
			customParent = "",
			x = 300,
			y = 0,
			growDirection = "RIGHT_DOWN",
		},
		bars = {
			width = 352,
			height = 36,
			fontSize = 16,
			borderThickness = 2,
			swapIconSide = false,
			swapIndicatorSide = false,
			hideIcon = false,
			texture = "SBM Flat",
			anchorFrom = "BOTTOMLEFT",
			anchorTo = "TOPLEFT",
			anchorParent = "SimpleBossMods_Icons",
			customParent = "",
			x = 0,
			y = 8,
			growDirection = "UP",
			sortAscending = true,
			fillDirection = "LEFT",
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
			enabled = true,
			size = 48,
			gap = 6,
			growDirection = "RIGHT",
			x = 0,
			y = -8,
			anchorFrom = "TOPLEFT",
			anchorTo = "BOTTOMLEFT",
			anchorParent = "SimpleBossMods_Icons",
			customParent = "",
			sound = "SBM: Raid Warning",
			soundChannel = "Master",
		},
		combatTimer = {
			enabled = false,
			x = 0,
			y = 0,
			anchorFrom = "TOPLEFT",
			anchorTo = "BOTTOMLEFT",
			anchorParent = "SimpleBossMods_PrivateAuras",
			customParent = "",
			font = "SBM Expressway",
			fontSize = 18,
			color = { r = 1, g = 1, b = 1, a = 1 },
			borderColor = { r = 0, g = 0, b = 0, a = 1 },
			bgColor = { r = 0, g = 0, b = 0, a = 0.8 },
		},
	},
}

function M:EnsureDefaults()
	SimpleBossModsDB = SimpleBossModsDB or {}
	SimpleBossModsDB.cfg = SimpleBossModsDB.cfg or {}
	SimpleBossModsDB.manualTimers = SimpleBossModsDB.manualTimers or {}

	local cfg = SimpleBossModsDB.cfg
	cfg.general = cfg.general or {
		gap = M.Defaults.cfg.general.gap,
		autoInsertKeystone = M.Defaults.cfg.general.autoInsertKeystone,
		thresholdToBar = M.Defaults.cfg.general.thresholdToBar,
	}
	if cfg.general.autoInsertKeystone == nil then
		cfg.general.autoInsertKeystone = M.Defaults.cfg.general.autoInsertKeystone
	end
	if cfg.general.thresholdToBar == nil then
		cfg.general.thresholdToBar = M.Defaults.cfg.general.thresholdToBar
	end
	if cfg.general.font == nil then
		cfg.general.font = M.Defaults.cfg.general.font
	end
	cfg.icons = cfg.icons or {
		size = M.Defaults.cfg.icons.size,
		fontSize = M.Defaults.cfg.icons.fontSize,
		borderThickness = M.Defaults.cfg.icons.borderThickness,
		enabled = M.Defaults.cfg.icons.enabled,
		gap = M.Defaults.cfg.icons.gap,
		perRow = M.Defaults.cfg.icons.perRow,
		limit = M.Defaults.cfg.icons.limit,
		anchorFrom = M.Defaults.cfg.icons.anchorFrom,
		anchorTo = M.Defaults.cfg.icons.anchorTo,
		anchorParent = M.Defaults.cfg.icons.anchorParent,
		customParent = M.Defaults.cfg.icons.customParent,
		x = M.Defaults.cfg.icons.x,
		y = M.Defaults.cfg.icons.y,
		growDirection = M.Defaults.cfg.icons.growDirection,
	}
	if cfg.icons.enabled == nil then
		cfg.icons.enabled = M.Defaults.cfg.icons.enabled
	end
	if cfg.icons.gap == nil then
		cfg.icons.gap = M.Defaults.cfg.icons.gap
	end
	if cfg.icons.perRow == nil then
		cfg.icons.perRow = M.Defaults.cfg.icons.perRow
	end
	if cfg.icons.limit == nil then
		cfg.icons.limit = M.Defaults.cfg.icons.limit
	end
	if cfg.icons.anchorFrom == nil then
		cfg.icons.anchorFrom = M.Defaults.cfg.icons.anchorFrom
	end
	if cfg.icons.anchorTo == nil then
		cfg.icons.anchorTo = M.Defaults.cfg.icons.anchorTo
	end
	if cfg.icons.anchorParent == nil then
		cfg.icons.anchorParent = M.Defaults.cfg.icons.anchorParent
	end
	if cfg.icons.customParent == nil then
		cfg.icons.customParent = M.Defaults.cfg.icons.customParent
	end
	if cfg.icons.x == nil then
		cfg.icons.x = M.Defaults.cfg.icons.x
	end
	if cfg.icons.y == nil then
		cfg.icons.y = M.Defaults.cfg.icons.y
	end
	if cfg.icons.growDirection == nil then
		cfg.icons.growDirection = M.Defaults.cfg.icons.growDirection
	end
	if cfg.icons.font == nil then
		cfg.icons.font = cfg.general.font or M.Defaults.cfg.icons.font
	end
	do
		local dir = cfg.icons.growDirection
		if type(dir) ~= "string" then
			dir = M.Defaults.cfg.icons.growDirection
		end
		dir = dir:upper():gsub("%s+", "_")
		if dir == "BOTTOM_DOWN" then
			dir = "LEFT_DOWN"
		elseif dir == "BOTTOM_UP" then
			dir = "LEFT_UP"
		end
		if dir ~= "LEFT_DOWN" and dir ~= "LEFT_UP" and dir ~= "RIGHT_DOWN" and dir ~= "RIGHT_UP" then
			dir = M.Defaults.cfg.icons.growDirection
		end
		cfg.icons.growDirection = dir
	end
	cfg.bars = cfg.bars or {
		width = M.Defaults.cfg.bars.width,
		height = M.Defaults.cfg.bars.height,
		fontSize = M.Defaults.cfg.bars.fontSize,
		borderThickness = M.Defaults.cfg.bars.borderThickness,
		swapIconSide = M.Defaults.cfg.bars.swapIconSide,
		swapIndicatorSide = M.Defaults.cfg.bars.swapIndicatorSide,
		hideIcon = M.Defaults.cfg.bars.hideIcon,
		anchorFrom = M.Defaults.cfg.bars.anchorFrom,
		anchorTo = M.Defaults.cfg.bars.anchorTo,
		anchorParent = M.Defaults.cfg.bars.anchorParent,
		customParent = M.Defaults.cfg.bars.customParent,
		x = M.Defaults.cfg.bars.x,
		y = M.Defaults.cfg.bars.y,
		growDirection = M.Defaults.cfg.bars.growDirection,
		sortAscending = M.Defaults.cfg.bars.sortAscending,
		fillDirection = M.Defaults.cfg.bars.fillDirection,
	}
	if cfg.bars.swapIconSide == nil then
		cfg.bars.swapIconSide = M.Defaults.cfg.bars.swapIconSide
	end
	if cfg.bars.swapIndicatorSide == nil then
		cfg.bars.swapIndicatorSide = M.Defaults.cfg.bars.swapIndicatorSide
	end
	if cfg.bars.hideIcon == nil then
		cfg.bars.hideIcon = M.Defaults.cfg.bars.hideIcon
	end
	if cfg.bars.anchorFrom == nil then
		cfg.bars.anchorFrom = M.Defaults.cfg.bars.anchorFrom
	end
	if cfg.bars.anchorTo == nil then
		cfg.bars.anchorTo = M.Defaults.cfg.bars.anchorTo
	end
	if cfg.bars.anchorParent == nil then
		cfg.bars.anchorParent = M.Defaults.cfg.bars.anchorParent
	end
	if cfg.bars.customParent == nil then
		cfg.bars.customParent = M.Defaults.cfg.bars.customParent
	end
	if cfg.bars.x == nil then
		cfg.bars.x = M.Defaults.cfg.bars.x
	end
	if cfg.bars.y == nil then
		cfg.bars.y = M.Defaults.cfg.bars.y
	end
	if cfg.bars.growDirection == nil then
		cfg.bars.growDirection = M.Defaults.cfg.bars.growDirection
	end
	if cfg.bars.sortAscending == nil then
		cfg.bars.sortAscending = M.Defaults.cfg.bars.sortAscending
	end
	if cfg.bars.fillDirection == nil then
		cfg.bars.fillDirection = M.Defaults.cfg.bars.fillDirection
	end
	if cfg.bars.texture == nil then
		cfg.bars.texture = M.Defaults.cfg.bars.texture
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
		enabled = M.Defaults.cfg.privateAuras.enabled,
		size = M.Defaults.cfg.privateAuras.size,
		gap = M.Defaults.cfg.privateAuras.gap,
		growDirection = M.Defaults.cfg.privateAuras.growDirection,
		x = M.Defaults.cfg.privateAuras.x,
		y = M.Defaults.cfg.privateAuras.y,
		anchorFrom = M.Defaults.cfg.privateAuras.anchorFrom,
		anchorTo = M.Defaults.cfg.privateAuras.anchorTo,
		anchorParent = M.Defaults.cfg.privateAuras.anchorParent,
		customParent = M.Defaults.cfg.privateAuras.customParent,
		sound = M.Defaults.cfg.privateAuras.sound,
	}
	if cfg.privateAuras.size == nil then
		cfg.privateAuras.size = M.Defaults.cfg.privateAuras.size
	end
	if cfg.privateAuras.enabled == nil then
		cfg.privateAuras.enabled = M.Defaults.cfg.privateAuras.enabled
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
	if cfg.privateAuras.anchorFrom == nil then
		cfg.privateAuras.anchorFrom = M.Defaults.cfg.privateAuras.anchorFrom
	end
	if cfg.privateAuras.anchorTo == nil then
		cfg.privateAuras.anchorTo = M.Defaults.cfg.privateAuras.anchorTo
	end
	if cfg.privateAuras.anchorParent == nil then
		cfg.privateAuras.anchorParent = M.Defaults.cfg.privateAuras.anchorParent
	end
	if cfg.privateAuras.customParent == nil then
		cfg.privateAuras.customParent = M.Defaults.cfg.privateAuras.customParent
	end
	if cfg.privateAuras.sound == nil then
		if type(cfg.privateAuras.soundKitID) == "number" then
			local legacyKey = "SBM: Legacy " .. tostring(cfg.privateAuras.soundKitID)
			if LSM and LSM.IsValid and not LSM:IsValid("sound", legacyKey) then
				LSM:Register("sound", legacyKey, cfg.privateAuras.soundKitID)
			end
			cfg.privateAuras.sound = legacyKey
		else
			cfg.privateAuras.sound = M.Defaults.cfg.privateAuras.sound
		end
	end
	if cfg.privateAuras.soundChannel == nil then
		cfg.privateAuras.soundChannel = M.Defaults.cfg.privateAuras.soundChannel
	end
	do
		local channel = M.NormalizeSoundChannel(cfg.privateAuras.soundChannel) or M.Defaults.cfg.privateAuras.soundChannel
		cfg.privateAuras.soundChannel = channel
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

	cfg.combatTimer = cfg.combatTimer or {
		enabled = M.Defaults.cfg.combatTimer.enabled,
		x = M.Defaults.cfg.combatTimer.x,
		y = M.Defaults.cfg.combatTimer.y,
		font = M.Defaults.cfg.combatTimer.font,
		fontSize = M.Defaults.cfg.combatTimer.fontSize,
	}
	if cfg.combatTimer.enabled == nil then
		cfg.combatTimer.enabled = M.Defaults.cfg.combatTimer.enabled
	end
	if cfg.combatTimer.anchorFrom == nil then
		cfg.combatTimer.anchorFrom = M.Defaults.cfg.combatTimer.anchorFrom
	end
	if cfg.combatTimer.anchorTo == nil then
		cfg.combatTimer.anchorTo = M.Defaults.cfg.combatTimer.anchorTo
	end
	if cfg.combatTimer.anchorParent == nil then
		cfg.combatTimer.anchorParent = M.Defaults.cfg.combatTimer.anchorParent
	end
	if cfg.combatTimer.customParent == nil then
		cfg.combatTimer.customParent = M.Defaults.cfg.combatTimer.customParent
	end
	if cfg.combatTimer.font == nil then
		cfg.combatTimer.font = cfg.general.font or M.Defaults.cfg.combatTimer.font
	end
	if cfg.combatTimer.fontSize == nil then
		cfg.combatTimer.fontSize = M.Defaults.cfg.combatTimer.fontSize
	end
	if cfg.combatTimer.x == nil then
		cfg.combatTimer.x = M.Defaults.cfg.combatTimer.x
	end
	if cfg.combatTimer.y == nil then
		cfg.combatTimer.y = M.Defaults.cfg.combatTimer.y
	end
	if cfg.combatTimer.anchorParent == "SimpleBossMods_Anchor"
		and cfg.combatTimer.anchorFrom == "LEFT"
		and cfg.combatTimer.anchorTo == "RIGHT"
		and cfg.combatTimer.x == -80
		and cfg.combatTimer.y == 0 then
		cfg.combatTimer.anchorParent = "SimpleBossMods_PrivateAuras"
		cfg.combatTimer.anchorFrom = "TOPLEFT"
		cfg.combatTimer.anchorTo = "BOTTOMLEFT"
		cfg.combatTimer.x = 0
		cfg.combatTimer.y = 0
	end
	cfg.combatTimer.color = cfg.combatTimer.color or {
		r = M.Defaults.cfg.combatTimer.color.r,
		g = M.Defaults.cfg.combatTimer.color.g,
		b = M.Defaults.cfg.combatTimer.color.b,
		a = M.Defaults.cfg.combatTimer.color.a,
	}
	cfg.combatTimer.borderColor = cfg.combatTimer.borderColor or {
		r = M.Defaults.cfg.combatTimer.borderColor.r,
		g = M.Defaults.cfg.combatTimer.borderColor.g,
		b = M.Defaults.cfg.combatTimer.borderColor.b,
		a = M.Defaults.cfg.combatTimer.borderColor.a,
	}
	cfg.combatTimer.bgColor = cfg.combatTimer.bgColor or {
		r = M.Defaults.cfg.combatTimer.bgColor.r,
		g = M.Defaults.cfg.combatTimer.bgColor.g,
		b = M.Defaults.cfg.combatTimer.bgColor.b,
		a = M.Defaults.cfg.combatTimer.bgColor.a,
	}
	repairColor(cfg.combatTimer.color, M.Defaults.cfg.combatTimer.color.r, M.Defaults.cfg.combatTimer.color.g, M.Defaults.cfg.combatTimer.color.b, M.Defaults.cfg.combatTimer.color.a)
	repairColor(cfg.combatTimer.borderColor, M.Defaults.cfg.combatTimer.borderColor.r, M.Defaults.cfg.combatTimer.borderColor.g, M.Defaults.cfg.combatTimer.borderColor.b, M.Defaults.cfg.combatTimer.borderColor.a)
	repairColor(cfg.combatTimer.bgColor, M.Defaults.cfg.combatTimer.bgColor.r, M.Defaults.cfg.combatTimer.bgColor.g, M.Defaults.cfg.combatTimer.bgColor.b, M.Defaults.cfg.combatTimer.bgColor.a)
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

local function normalizeAnchorPoint(point)
	if type(point) ~= "string" then return "CENTER" end
	point = point:upper()
	if point == "TOPLEFT" or point == "TOP" or point == "TOPRIGHT"
		or point == "LEFT" or point == "CENTER" or point == "RIGHT"
		or point == "BOTTOMLEFT" or point == "BOTTOM" or point == "BOTTOMRIGHT" then
		return point
	end
	return "CENTER"
end

function M.SyncLiveConfig()
	local gc = SimpleBossModsDB.cfg.general
	local ic = SimpleBossModsDB.cfg.icons
	local bc = SimpleBossModsDB.cfg.bars
	local inc = SimpleBossModsDB.cfg.indicators
	local pc = SimpleBossModsDB.cfg.privateAuras or M.Defaults.cfg.privateAuras
	local ct = SimpleBossModsDB.cfg.combatTimer or M.Defaults.cfg.combatTimer
	L.PRIVATE_AURA_ENABLED = pc.enabled ~= false

	L.GAP = tonumber(gc.gap) or 6
	L.AUTO_INSERT_KEYSTONE = gc.autoInsertKeystone and true or false
	L.THRESHOLD_TO_BAR = U.clamp(tonumber(gc.thresholdToBar) or C.THRESHOLD_TO_BAR, 0.1, 600)

	L.ICONS_ENABLED = ic.enabled ~= false
	L.ICON_SIZE = ic.size
	L.ICON_FONT_SIZE = ic.fontSize
	L.ICON_BORDER_THICKNESS = ic.borderThickness
	L.ICON_GAP = U.clamp(U.round(tonumber(ic.gap) or M.Defaults.cfg.icons.gap), -50, 50)
	L.ICONS_PER_ROW = U.clamp(U.round(tonumber(ic.perRow) or C.ICONS_PER_ROW), 1, 20)
	L.ICONS_LIMIT = U.clamp(U.round(tonumber(ic.limit) or 0), 0, 200)
	do
		local dir = ic.growDirection
		if type(dir) ~= "string" then
			dir = M.Defaults.cfg.icons.growDirection
		end
		dir = dir:upper():gsub("%s+", "_")
		if dir == "BOTTOM_DOWN" then
			dir = "LEFT_DOWN"
		elseif dir == "BOTTOM_UP" then
			dir = "LEFT_UP"
		end
		if dir ~= "LEFT_DOWN" and dir ~= "LEFT_UP" and dir ~= "RIGHT_DOWN" and dir ~= "RIGHT_UP" then
			dir = M.Defaults.cfg.icons.growDirection
		end
		L.ICON_GROW_DIR = dir
	end
	L.ICON_ANCHOR_FROM = normalizeAnchorPoint(ic.anchorFrom)
	L.ICON_ANCHOR_TO = normalizeAnchorPoint(ic.anchorTo)
	L.ICON_ANCHOR_PARENT = (type(ic.anchorParent) == "string" and ic.anchorParent ~= "") and ic.anchorParent or "NONE"
	do
		local customParent = nil
		if type(ic.customParent) == "string" then
			customParent = ic.customParent:gsub("^%s+", ""):gsub("%s+$", "")
			if customParent == "" then
				customParent = nil
			end
		end
		L.ICON_ANCHOR_CUSTOM_PARENT = customParent
		if customParent then
			L.ICON_PARENT_NAME = customParent
		elseif L.ICON_ANCHOR_PARENT ~= "NONE" then
			L.ICON_PARENT_NAME = L.ICON_ANCHOR_PARENT
		else
			L.ICON_PARENT_NAME = nil
		end
	end
	L.ICON_ANCHOR_X = tonumber(ic.x) or 0
	L.ICON_ANCHOR_Y = tonumber(ic.y) or 0
	L.ICON_FONT_KEY = ic.font or M.Defaults.cfg.icons.font
	L.ICON_FONT_PATH = C.FONT_PATH
	if LSM then
		L.ICON_FONT_PATH = LSM:Fetch("font", L.ICON_FONT_KEY) or C.FONT_PATH
	end

	L.BAR_WIDTH = bc.width
	L.BAR_HEIGHT = bc.height
	L.BAR_FONT_SIZE = bc.fontSize
	L.BAR_BORDER_THICKNESS = bc.borderThickness
	L.BAR_ICON_SWAP = bc.swapIconSide and true or false
	L.BAR_INDICATOR_SWAP = bc.swapIndicatorSide and true or false
	L.BAR_ICON_HIDDEN = bc.hideIcon and true or false
	do
		local dir = bc.growDirection
		if type(dir) ~= "string" then
			dir = M.Defaults.cfg.bars.growDirection
		end
		dir = dir:upper()
		if dir ~= "UP" and dir ~= "DOWN" then
			dir = M.Defaults.cfg.bars.growDirection
		end
		L.BAR_GROW_DIR = dir
	end
	L.BAR_SORT_ASC = bc.sortAscending and true or false
	do
		local fill = bc.fillDirection
		if type(fill) ~= "string" then
			fill = M.Defaults.cfg.bars.fillDirection
		end
		fill = fill:upper()
		if fill ~= "LEFT" and fill ~= "RIGHT" then
			fill = M.Defaults.cfg.bars.fillDirection
		end
		L.BAR_FILL_DIR = fill
	end
	L.BAR_FILL_REVERSE = (L.BAR_FILL_DIR == "RIGHT")
	do
		local indicatorOnLeft = L.BAR_FILL_REVERSE
		if L.BAR_INDICATOR_SWAP then
			indicatorOnLeft = not indicatorOnLeft
		end
		L.BAR_INDICATOR_ON_LEFT = indicatorOnLeft
	end
	L.FONT_KEY = gc.font or M.Defaults.cfg.general.font
	L.FONT_PATH = C.FONT_PATH
	if LSM then
		L.FONT_PATH = LSM:Fetch("font", L.FONT_KEY) or C.FONT_PATH
	end
	L.BAR_ANCHOR_FROM = normalizeAnchorPoint(bc.anchorFrom)
	L.BAR_ANCHOR_TO = normalizeAnchorPoint(bc.anchorTo)
	L.BAR_ANCHOR_PARENT = (type(bc.anchorParent) == "string" and bc.anchorParent ~= "") and bc.anchorParent or "NONE"
	do
		local customParent = nil
		if type(bc.customParent) == "string" then
			customParent = bc.customParent:gsub("^%s+", ""):gsub("%s+$", "")
			if customParent == "" then
				customParent = nil
			end
		end
		L.BAR_ANCHOR_CUSTOM_PARENT = customParent
		if customParent then
			L.BAR_PARENT_NAME = customParent
		elseif L.BAR_ANCHOR_PARENT ~= "NONE" then
			L.BAR_PARENT_NAME = L.BAR_ANCHOR_PARENT
		else
			L.BAR_PARENT_NAME = nil
		end
	end
	L.BAR_ANCHOR_X = tonumber(bc.x) or 0
	L.BAR_ANCHOR_Y = tonumber(bc.y) or 0
	L.BAR_TEX_KEY = bc.texture or M.Defaults.cfg.bars.texture
	L.BAR_TEX = C.BAR_TEX_DEFAULT
	if LSM then
		L.BAR_TEX = LSM:Fetch("statusbar", L.BAR_TEX_KEY) or C.BAR_TEX_DEFAULT
	end
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
	L.PRIVATE_AURA_ANCHOR_FROM = normalizeAnchorPoint(pc.anchorFrom)
	L.PRIVATE_AURA_ANCHOR_TO = normalizeAnchorPoint(pc.anchorTo)
	L.PRIVATE_AURA_ANCHOR_PARENT = (type(pc.anchorParent) == "string" and pc.anchorParent ~= "") and pc.anchorParent or "NONE"
	do
		local customParent = nil
		if type(pc.customParent) == "string" then
			customParent = pc.customParent:gsub("^%s+", ""):gsub("%s+$", "")
			if customParent == "" then
				customParent = nil
			end
		end
		L.PRIVATE_AURA_ANCHOR_CUSTOM_PARENT = customParent
		if customParent then
			L.PRIVATE_AURA_PARENT_NAME = customParent
		elseif L.PRIVATE_AURA_ANCHOR_PARENT ~= "NONE" then
			L.PRIVATE_AURA_PARENT_NAME = L.PRIVATE_AURA_ANCHOR_PARENT
		else
			L.PRIVATE_AURA_PARENT_NAME = nil
		end
	end
	L.PRIVATE_AURA_X = tonumber(pc.x) or 0
	L.PRIVATE_AURA_Y = tonumber(pc.y) or 0
	local soundKey = pc.sound or M.Defaults.cfg.privateAuras.sound
	L.PRIVATE_AURA_SOUND_KEY = soundKey
	local soundValue = nil
	if type(soundKey) == "number" then
		soundValue = soundKey
	elseif type(soundKey) == "string" then
		if LSM then
			soundValue = LSM:Fetch("sound", soundKey)
		end
		if not soundValue then
			local numeric = tonumber(soundKey)
			if numeric then
				soundValue = numeric
			end
		end
	end
	if soundValue == nil and type(pc.soundKitID) == "number" then
		soundValue = pc.soundKitID
	end
	L.PRIVATE_AURA_SOUND = soundValue
	L.PRIVATE_AURA_SOUND_CHANNEL = M.NormalizeSoundChannel(pc.soundChannel) or M.Defaults.cfg.privateAuras.soundChannel

	L.COMBAT_TIMER_ENABLED = ct.enabled and true or false
	L.COMBAT_TIMER_X = tonumber(ct.x) or 0
	L.COMBAT_TIMER_Y = tonumber(ct.y) or 0

	L.COMBAT_TIMER_ANCHOR_FROM = normalizeAnchorPoint(ct.anchorFrom)
	L.COMBAT_TIMER_ANCHOR_TO = normalizeAnchorPoint(ct.anchorTo)
	L.COMBAT_TIMER_ANCHOR_PARENT = (type(ct.anchorParent) == "string" and ct.anchorParent ~= "") and ct.anchorParent or "NONE"
	local customParent = nil
	if type(ct.customParent) == "string" then
		customParent = ct.customParent:gsub("^%s+", ""):gsub("%s+$", "")
		if customParent == "" then
			customParent = nil
		end
	end
	L.COMBAT_TIMER_ANCHOR_CUSTOM_PARENT = customParent
	if customParent then
		L.COMBAT_TIMER_PARENT_NAME = customParent
	elseif L.COMBAT_TIMER_ANCHOR_PARENT ~= "NONE" then
		L.COMBAT_TIMER_PARENT_NAME = L.COMBAT_TIMER_ANCHOR_PARENT
	else
		L.COMBAT_TIMER_PARENT_NAME = nil
	end

	L.COMBAT_TIMER_FONT_KEY = ct.font or L.FONT_KEY or M.Defaults.cfg.combatTimer.font
	L.COMBAT_TIMER_FONT_PATH = C.FONT_PATH
	if LSM then
		L.COMBAT_TIMER_FONT_PATH = LSM:Fetch("font", L.COMBAT_TIMER_FONT_KEY) or C.FONT_PATH
	end
	L.COMBAT_TIMER_FONT_SIZE = U.clamp(U.round(tonumber(ct.fontSize) or M.Defaults.cfg.combatTimer.fontSize), 8, 72)

	local ctColor = ct.color or {}
	L.COMBAT_TIMER_COLOR_R = U.clamp(tonumber(ctColor.r) or M.Defaults.cfg.combatTimer.color.r, 0, 1)
	L.COMBAT_TIMER_COLOR_G = U.clamp(tonumber(ctColor.g) or M.Defaults.cfg.combatTimer.color.g, 0, 1)
	L.COMBAT_TIMER_COLOR_B = U.clamp(tonumber(ctColor.b) or M.Defaults.cfg.combatTimer.color.b, 0, 1)
	L.COMBAT_TIMER_COLOR_A = U.clamp(tonumber(ctColor.a) or M.Defaults.cfg.combatTimer.color.a, 0, 1)

	local ctBorder = ct.borderColor or {}
	L.COMBAT_TIMER_BORDER_R = U.clamp(tonumber(ctBorder.r) or M.Defaults.cfg.combatTimer.borderColor.r, 0, 1)
	L.COMBAT_TIMER_BORDER_G = U.clamp(tonumber(ctBorder.g) or M.Defaults.cfg.combatTimer.borderColor.g, 0, 1)
	L.COMBAT_TIMER_BORDER_B = U.clamp(tonumber(ctBorder.b) or M.Defaults.cfg.combatTimer.borderColor.b, 0, 1)
	L.COMBAT_TIMER_BORDER_A = U.clamp(tonumber(ctBorder.a) or M.Defaults.cfg.combatTimer.borderColor.a, 0, 1)

	local ctBg = ct.bgColor or {}
	L.COMBAT_TIMER_BG_R = U.clamp(tonumber(ctBg.r) or M.Defaults.cfg.combatTimer.bgColor.r, 0, 1)
	L.COMBAT_TIMER_BG_G = U.clamp(tonumber(ctBg.g) or M.Defaults.cfg.combatTimer.bgColor.g, 0, 1)
	L.COMBAT_TIMER_BG_B = U.clamp(tonumber(ctBg.b) or M.Defaults.cfg.combatTimer.bgColor.b, 0, 1)
	L.COMBAT_TIMER_BG_A = U.clamp(tonumber(ctBg.a) or M.Defaults.cfg.combatTimer.bgColor.a, 0, 1)
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
