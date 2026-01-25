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
function M:ApplyGeneralConfig(x, y, gap, mirror, barsBelow, autoInsertKeystone)
	SimpleBossModsDB.pos.x = tonumber(x) or (SimpleBossModsDB.pos.x or 0)
	SimpleBossModsDB.pos.y = tonumber(y) or (SimpleBossModsDB.pos.y or 0)
	SimpleBossModsDB.cfg.general.gap = tonumber(gap) or (SimpleBossModsDB.cfg.general.gap or 6)
	if mirror == nil then
		SimpleBossModsDB.cfg.general.mirror = SimpleBossModsDB.cfg.general.mirror and true or false
	else
		SimpleBossModsDB.cfg.general.mirror = mirror and true or false
	end
	if barsBelow == nil then
		SimpleBossModsDB.cfg.general.barsBelow = SimpleBossModsDB.cfg.general.barsBelow and true or false
	else
		SimpleBossModsDB.cfg.general.barsBelow = barsBelow and true or false
	end
	if autoInsertKeystone == nil then
		SimpleBossModsDB.cfg.general.autoInsertKeystone = SimpleBossModsDB.cfg.general.autoInsertKeystone and true or false
	else
		SimpleBossModsDB.cfg.general.autoInsertKeystone = autoInsertKeystone and true or false
	end

	M.SyncLiveConfig()
	if M.SetupKeystoneAutoInsert then
		M:SetupKeystoneAutoInsert()
	end
	M:SetPosition(SimpleBossModsDB.pos.x, SimpleBossModsDB.pos.y)
	M:LayoutAll()
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

	for _, rec in pairs(self.events) do
		if rec.barFrame then
			M.setBarFillFlat(rec.barFrame, L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A)
		end
	end
	for _, f in ipairs(M.pools.bar) do
		M.setBarFillFlat(f, L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A)
	end
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

	for _, rec in pairs(self.events) do
		if rec.barFrame then
			M.setBarFillFlat(rec.barFrame, L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A)
		end
	end
	for _, f in ipairs(M.pools.bar) do
		M.setBarFillFlat(f, L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A)
	end
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

function M:ApplyPrivateAuraConfig(size, gap, growDirection, x, y, soundKey)
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
	local soundChanged = false
	if soundKey ~= nil and soundKey ~= pc.sound then
		pc.sound = soundKey
		soundChanged = true
	end

	M.SyncLiveConfig()
	if soundChanged and M.ResetPrivateAuraSoundRegistrations then
		M:ResetPrivateAuraSoundRegistrations()
	end
	if M.SetPrivateAuraPosition then
		M:SetPrivateAuraPosition(pc.x, pc.y)
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
		if M.ResetPrivateAuraSoundRegistrations then
			M:ResetPrivateAuraSoundRegistrations()
		end
		if M.ShowTestPrivateAura then
			M:ShowTestPrivateAura(false)
		end
	end
	if M.UpdatePrivateAuraAnchor then
		M:UpdatePrivateAuraAnchor()
	end
	if pc.enabled and M.SetupPrivateAuraSoundWatcher then
		M:SetupPrivateAuraSoundWatcher()
	end
	if M.UpdatePrivateAuraFrames then
		M:UpdatePrivateAuraFrames(false)
	end
end

function M:ApplyPrivateAuraSoundChannel(channel)
	local pc = SimpleBossModsDB.cfg.privateAuras
	local normalized = M.NormalizeSoundChannel and M.NormalizeSoundChannel(channel)
	if normalized then
		pc.soundChannel = normalized
	end
	M.SyncLiveConfig()
	if M.ResetPrivateAuraSoundRegistrations then
		M:ResetPrivateAuraSoundRegistrations()
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

	local function buildPrivateAuraSoundOptions()
		if not LSM then return nil end
		local list = {}
		for key in pairs(LSM:HashTable("sound")) do
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

	local function AddSoundDropdownRow(section, label, groups, get, set, tooltip)
		local row = CreateRow(section, ROW_H * 2 + 8)
		local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		fs:SetPoint("TOPLEFT", row, "TOPLEFT", LABEL_X, -2)
		fs:SetText(label)

		local dd = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
		dd:SetPoint("TOPLEFT", row, "TOPLEFT", LABEL_X - 16, -ROW_H - 2)
		UIDropDownMenu_SetWidth(dd, 220)
		dd.listFrameStrata = "FULLSCREEN_DIALOG"

		local function labelFor(id)
			if not id or id == 0 then return "None" end
			return privateAuraSoundIndex[id] or ("Custom (" .. tostring(id) .. ")")
		end

		local function refresh()
			local val = get()
			UIDropDownMenu_SetSelectedValue(dd, val)
			UIDropDownMenu_SetText(dd, labelFor(val))
		end

		local function setSoundValue(value)
			set(value)
			UIDropDownMenu_SetSelectedValue(dd, value)
			UIDropDownMenu_SetText(dd, labelFor(value))
			if CloseDropDownMenus then
				CloseDropDownMenus()
			end
		end

		UIDropDownMenu_Initialize(dd, function(_, level, menuList)
			if not level or level == 1 then
				local noneInfo = UIDropDownMenu_CreateInfo()
				noneInfo.text = "None"
				noneInfo.arg1 = 0
				noneInfo.func = function(_, arg1) setSoundValue(arg1) end
				noneInfo.checked = (get() == 0)
				UIDropDownMenu_AddButton(noneInfo, level)

				for _, group in ipairs(groups) do
					if group.items and #group.items > 0 and group.label ~= "None" then
						local cat = UIDropDownMenu_CreateInfo()
						cat.text = group.label
						cat.hasArrow = true
						cat.notCheckable = true
						cat.menuList = group
						UIDropDownMenu_AddButton(cat, level)
					end
				end
				return
			end

			if level == 2 and menuList and menuList.items then
				for _, opt in ipairs(menuList.items) do
					local info = UIDropDownMenu_CreateInfo()
					info.text = opt.label
					info.arg1 = opt.id
					info.func = function(_, arg1) setSoundValue(arg1) end
					info.checked = (get() == opt.id)
					UIDropDownMenu_AddButton(info, level)
				end
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

	local function AddSpacer(section, pixels)
		return CreateRow(section, pixels or 10)
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

	local generalTab = CreateTab(1, "General")
	local displayTab = CreateTab(2, "Display")
	local privateTab = CreateTab(3, "Private Auras")

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

	local generalPosition = CreateSection(generalTab, "Position")
	AddNumberRow(generalPosition, "X Offset",
		function() return SimpleBossModsDB.pos.x or 0 end,
		function(v) M:ApplyGeneralConfig(v, SimpleBossModsDB.pos.y or 0, SimpleBossModsDB.cfg.general.gap or 6, SimpleBossModsDB.cfg.general.mirror, SimpleBossModsDB.cfg.general.barsBelow, SimpleBossModsDB.cfg.general.autoInsertKeystone) end,
		nil, true
	)

	AddNumberRow(generalPosition, "Y Offset",
		function() return SimpleBossModsDB.pos.y or 0 end,
		function(v) M:ApplyGeneralConfig(SimpleBossModsDB.pos.x or 0, v, SimpleBossModsDB.cfg.general.gap or 6, SimpleBossModsDB.cfg.general.mirror, SimpleBossModsDB.cfg.general.barsBelow, SimpleBossModsDB.cfg.general.autoInsertKeystone) end,
		nil, true
	)

	AddNumberRow(generalPosition, "Gap",
		function() return SimpleBossModsDB.cfg.general.gap or 6 end,
		function(v) M:ApplyGeneralConfig(SimpleBossModsDB.pos.x or 0, SimpleBossModsDB.pos.y or 0, U.clamp(U.round(v), -30, 30), SimpleBossModsDB.cfg.general.mirror, SimpleBossModsDB.cfg.general.barsBelow, SimpleBossModsDB.cfg.general.autoInsertKeystone) end,
		"Used for icon gap and bars-to-icons gap.", false, true
	)

	local generalBehavior = CreateSection(generalTab, "Behavior")
	AddCheckRow(generalBehavior, "Mirror Horizontally",
		function() return SimpleBossModsDB.cfg.general.mirror end,
		function(v) M:ApplyGeneralConfig(SimpleBossModsDB.pos.x or 0, SimpleBossModsDB.pos.y or 0, SimpleBossModsDB.cfg.general.gap or 6, v, SimpleBossModsDB.cfg.general.barsBelow, SimpleBossModsDB.cfg.general.autoInsertKeystone) end,
		"Flip layout horizontally for right-side placement."
	)
	AddCheckRow(generalBehavior, "Mirror Vertically",
		function() return SimpleBossModsDB.cfg.general.barsBelow end,
		function(v) M:ApplyGeneralConfig(SimpleBossModsDB.pos.x or 0, SimpleBossModsDB.pos.y or 0, SimpleBossModsDB.cfg.general.gap or 6, SimpleBossModsDB.cfg.general.mirror, v, SimpleBossModsDB.cfg.general.autoInsertKeystone) end,
		"Swap vertical order so bars appear below icons."
	)
	AddCheckRow(generalBehavior, "Auto Insert Keystone",
		function() return SimpleBossModsDB.cfg.general.autoInsertKeystone end,
		function(v) M:ApplyGeneralConfig(SimpleBossModsDB.pos.x or 0, SimpleBossModsDB.pos.y or 0, SimpleBossModsDB.cfg.general.gap or 6, SimpleBossModsDB.cfg.general.mirror, SimpleBossModsDB.cfg.general.barsBelow, v) end,
		"Automatically inserts your keystone when the Mythic+ socket opens."
	)

	local iconsSection = CreateSection(displayTab, "Icons")
	AddNumberRow(iconsSection, "Icon Size",
		function() return SimpleBossModsDB.cfg.icons.size end,
		function(v) M:ApplyIconConfig(v, SimpleBossModsDB.cfg.icons.fontSize, SimpleBossModsDB.cfg.icons.borderThickness) end
	)
	AddNumberRow(iconsSection, "Icon Font Size",
		function() return SimpleBossModsDB.cfg.icons.fontSize end,
		function(v) M:ApplyIconConfig(SimpleBossModsDB.cfg.icons.size, v, SimpleBossModsDB.cfg.icons.borderThickness) end
	)
	AddNumberRow(iconsSection, "Icon Border Thickness",
		function() return SimpleBossModsDB.cfg.icons.borderThickness end,
		function(v) M:ApplyIconConfig(SimpleBossModsDB.cfg.icons.size, SimpleBossModsDB.cfg.icons.fontSize, v) end,
		"0 disables icon border."
	)

	local barsSection = CreateSection(displayTab, "Bars")
	AddNumberRow(barsSection, "Bar Width",
		function() return SimpleBossModsDB.cfg.bars.width end,
		function(v) M:ApplyBarConfig(v, SimpleBossModsDB.cfg.bars.height, SimpleBossModsDB.cfg.bars.fontSize, SimpleBossModsDB.cfg.bars.borderThickness) end
	)
	AddNumberRow(barsSection, "Bar Height",
		function() return SimpleBossModsDB.cfg.bars.height end,
		function(v) M:ApplyBarConfig(SimpleBossModsDB.cfg.bars.width, v, SimpleBossModsDB.cfg.bars.fontSize, SimpleBossModsDB.cfg.bars.borderThickness) end
	)
	AddNumberRow(barsSection, "Bar Font Size",
		function() return SimpleBossModsDB.cfg.bars.fontSize end,
		function(v) M:ApplyBarConfig(SimpleBossModsDB.cfg.bars.width, SimpleBossModsDB.cfg.bars.height, v, SimpleBossModsDB.cfg.bars.borderThickness) end
	)
	AddNumberRow(barsSection, "Bar Border Thickness",
		function() return SimpleBossModsDB.cfg.bars.borderThickness end,
		function(v) M:ApplyBarConfig(SimpleBossModsDB.cfg.bars.width, SimpleBossModsDB.cfg.bars.height, SimpleBossModsDB.cfg.bars.fontSize, v) end
	)
	AddNumberRow(barsSection, "Icon -> Bar Threshold (sec)",
		function() return SimpleBossModsDB.cfg.general.thresholdToBar end,
		function(v) M:ApplyBarThresholdConfig(v) end,
		"Switch to bars when remaining time is at or below this value.", true
	)
	AddCheckRow(barsSection, "Swap Bar Icon Side",
		function() return SimpleBossModsDB.cfg.bars.swapIconSide end,
		function(v) M:ApplyBarIconSideConfig(v) end,
		"Move the bar icon to the opposite side (respects mirror horizontally)."
	)
	AddCheckRow(barsSection, "Hide Bar Icon",
		function() return SimpleBossModsDB.cfg.bars.hideIcon end,
		function(v) M:ApplyBarIconVisibilityConfig(v) end,
		"Hide the bar icon without changing text alignment or fill direction."
	)

	local indicatorsSection = CreateSection(displayTab, "Indicators")
	AddNumberRow(indicatorsSection, "Icon Indicator Size",
		function() return SimpleBossModsDB.cfg.indicators.iconSize or 0 end,
		function(v) M:ApplyIndicatorConfig(v, SimpleBossModsDB.cfg.indicators.barSize or 0) end,
		"0 uses auto size."
	)
	AddNumberRow(indicatorsSection, "Bar Indicator Size",
		function() return SimpleBossModsDB.cfg.indicators.barSize or 0 end,
		function(v) M:ApplyIndicatorConfig(SimpleBossModsDB.cfg.indicators.iconSize or 0, v) end,
		"0 uses auto size."
	)

	local colorsSection = CreateSection(displayTab, "Colors")
	AddColorRow(colorsSection, "Bar Foreground Color",
		function() return L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A end,
		function(r, g, b, a) M:ApplyBarColor(r, g, b, a) end
	)
	AddColorRow(colorsSection, "Bar Background Color",
		function() return L.BAR_BG_R, L.BAR_BG_G, L.BAR_BG_B, L.BAR_BG_A end,
		function(r, g, b, a) M:ApplyBarBgColor(r, g, b, a) end
	)

	local privateAuraDirections = {
		{ label = "Right", value = "RIGHT" },
		{ label = "Left", value = "LEFT" },
		{ label = "Up", value = "UP" },
		{ label = "Down", value = "DOWN" },
	}

	local privateEnable = CreateSection(privateTab, "Private Auras")
	AddCheckRow(privateEnable, "Enable Private Aura Tracking",
		function() return SimpleBossModsDB.cfg.privateAuras.enabled ~= false end,
		function(v) M:ApplyPrivateAuraEnabled(v) end,
		"Toggle private aura icons and sound tracking."
	)

	local privateLayout = CreateSection(privateTab, "Layout")
	AddNumberRow(privateLayout, "Private Aura X Offset",
		function() return SimpleBossModsDB.cfg.privateAuras.x or 0 end,
		function(v)
			M:ApplyPrivateAuraConfig(
				SimpleBossModsDB.cfg.privateAuras.size,
				SimpleBossModsDB.cfg.privateAuras.gap,
				SimpleBossModsDB.cfg.privateAuras.growDirection,
				v,
				SimpleBossModsDB.cfg.privateAuras.y,
				SimpleBossModsDB.cfg.privateAuras.sound
			)
		end,
		nil, true
	)

	AddNumberRow(privateLayout, "Private Aura Y Offset",
		function() return SimpleBossModsDB.cfg.privateAuras.y or 0 end,
		function(v)
			M:ApplyPrivateAuraConfig(
				SimpleBossModsDB.cfg.privateAuras.size,
				SimpleBossModsDB.cfg.privateAuras.gap,
				SimpleBossModsDB.cfg.privateAuras.growDirection,
				SimpleBossModsDB.cfg.privateAuras.x,
				v,
				SimpleBossModsDB.cfg.privateAuras.sound
			)
		end,
		nil, true
	)

	AddNumberRow(privateLayout, "Private Aura Icon Size",
		function() return SimpleBossModsDB.cfg.privateAuras.size end,
		function(v)
			M:ApplyPrivateAuraConfig(
				v,
				SimpleBossModsDB.cfg.privateAuras.gap,
				SimpleBossModsDB.cfg.privateAuras.growDirection,
				SimpleBossModsDB.cfg.privateAuras.x,
				SimpleBossModsDB.cfg.privateAuras.y,
				SimpleBossModsDB.cfg.privateAuras.sound
			)
		end
	)

	AddNumberRow(privateLayout, "Private Aura Gap",
		function() return SimpleBossModsDB.cfg.privateAuras.gap end,
		function(v)
			M:ApplyPrivateAuraConfig(
				SimpleBossModsDB.cfg.privateAuras.size,
				v,
				SimpleBossModsDB.cfg.privateAuras.growDirection,
				SimpleBossModsDB.cfg.privateAuras.x,
				SimpleBossModsDB.cfg.privateAuras.y,
				SimpleBossModsDB.cfg.privateAuras.sound
			)
		end
	)

	AddDropdownRow(privateLayout, "Private Aura Grow Direction",
		privateAuraDirections,
		function() return SimpleBossModsDB.cfg.privateAuras.growDirection end,
		function(v)
			M:ApplyPrivateAuraConfig(
				SimpleBossModsDB.cfg.privateAuras.size,
				SimpleBossModsDB.cfg.privateAuras.gap,
				v,
				SimpleBossModsDB.cfg.privateAuras.x,
				SimpleBossModsDB.cfg.privateAuras.y,
				SimpleBossModsDB.cfg.privateAuras.sound
			)
		end,
		"Icon growth direction from the private aura anchor."
	)

	local privateSound = CreateSection(privateTab, "Sound")
	local legacySoundOptions = buildPrivateAuraSoundOptions()
	if legacySoundOptions then
		AddDropdownRow(privateSound, "Private Aura Sound",
			legacySoundOptions,
			function() return SimpleBossModsDB.cfg.privateAuras.sound end,
			function(v)
				M:ApplyPrivateAuraConfig(
					SimpleBossModsDB.cfg.privateAuras.size,
					SimpleBossModsDB.cfg.privateAuras.gap,
					SimpleBossModsDB.cfg.privateAuras.growDirection,
					SimpleBossModsDB.cfg.privateAuras.x,
					SimpleBossModsDB.cfg.privateAuras.y,
					v
				)
			end,
			"Plays when a new private aura appears."
		)
	else
		local row = CreateRow(privateSound, ROW_H)
		local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		fs:SetPoint("LEFT", row, "LEFT", LABEL_X, 0)
		fs:SetText("LibSharedMedia is not available.")
	end

	AddButton(privateSound, "Test Private Aura Sound", function()
		if M.PlayPrivateAuraSound then
			M:PlayPrivateAuraSound()
		end
	end)

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

	local function addDropdown(container, label, list, getValue, setValue, width)
		local dd = AG:Create("Dropdown")
		dd:SetLabel(label)
		dd:SetList(list)
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

	local function getPrivateAuraSoundList()
		if not LSM then return nil end
		return LSM:HashTable("sound")
	end

	local function buildGeneralTab(container)
		local position = AG:Create("InlineGroup")
		position:SetTitle("Position")
		position:SetLayout("Flow")
		position:SetFullWidth(true)
		container:AddChild(position)

		addNumberInput(position, "X Offset",
			function() return SimpleBossModsDB.pos.x or 0 end,
			function(v)
				addon:ApplyGeneralConfig(
					v,
					SimpleBossModsDB.pos.y or 0,
					SimpleBossModsDB.cfg.general.gap or 6,
					SimpleBossModsDB.cfg.general.mirror,
					SimpleBossModsDB.cfg.general.barsBelow,
					SimpleBossModsDB.cfg.general.autoInsertKeystone
				)
			end,
			0.33
		)

		addNumberInput(position, "Y Offset",
			function() return SimpleBossModsDB.pos.y or 0 end,
			function(v)
				addon:ApplyGeneralConfig(
					SimpleBossModsDB.pos.x or 0,
					v,
					SimpleBossModsDB.cfg.general.gap or 6,
					SimpleBossModsDB.cfg.general.mirror,
					SimpleBossModsDB.cfg.general.barsBelow,
					SimpleBossModsDB.cfg.general.autoInsertKeystone
				)
			end,
			0.33
		)

		addNumberInput(position, "Gap",
			function() return SimpleBossModsDB.cfg.general.gap or 6 end,
			function(v)
				addon:ApplyGeneralConfig(
					SimpleBossModsDB.pos.x or 0,
					SimpleBossModsDB.pos.y or 0,
					v,
					SimpleBossModsDB.cfg.general.mirror,
					SimpleBossModsDB.cfg.general.barsBelow,
					SimpleBossModsDB.cfg.general.autoInsertKeystone
				)
			end,
			0.33
		)

		local behavior = AG:Create("InlineGroup")
		behavior:SetTitle("Behavior")
		behavior:SetLayout("Flow")
		behavior:SetFullWidth(true)
		container:AddChild(behavior)

		addCheckBox(behavior, "Mirror Horizontally",
			function() return SimpleBossModsDB.cfg.general.mirror end,
			function(v)
				addon:ApplyGeneralConfig(
					SimpleBossModsDB.pos.x or 0,
					SimpleBossModsDB.pos.y or 0,
					SimpleBossModsDB.cfg.general.gap or 6,
					v,
					SimpleBossModsDB.cfg.general.barsBelow,
					SimpleBossModsDB.cfg.general.autoInsertKeystone
				)
			end,
			0.5
		)

		addCheckBox(behavior, "Mirror Vertically",
			function() return SimpleBossModsDB.cfg.general.barsBelow end,
			function(v)
				addon:ApplyGeneralConfig(
					SimpleBossModsDB.pos.x or 0,
					SimpleBossModsDB.pos.y or 0,
					SimpleBossModsDB.cfg.general.gap or 6,
					SimpleBossModsDB.cfg.general.mirror,
					v,
					SimpleBossModsDB.cfg.general.autoInsertKeystone
				)
			end,
			0.5
		)

		addCheckBox(behavior, "Auto Insert Keystone",
			function() return SimpleBossModsDB.cfg.general.autoInsertKeystone end,
			function(v)
				addon:ApplyGeneralConfig(
					SimpleBossModsDB.pos.x or 0,
					SimpleBossModsDB.pos.y or 0,
					SimpleBossModsDB.cfg.general.gap or 6,
					SimpleBossModsDB.cfg.general.mirror,
					SimpleBossModsDB.cfg.general.barsBelow,
					v
				)
			end,
			1
		)
	end

	local function buildIconsTab(container)
		local icons = AG:Create("InlineGroup")
		icons:SetTitle("Icons")
		icons:SetLayout("Flow")
		icons:SetFullWidth(true)
		container:AddChild(icons)

		addNumberInput(icons, "Icon Size",
			function() return SimpleBossModsDB.cfg.icons.size end,
			function(v) addon:ApplyIconConfig(v, SimpleBossModsDB.cfg.icons.fontSize, SimpleBossModsDB.cfg.icons.borderThickness) end,
			0.33
		)

		addNumberInput(icons, "Icon Font Size",
			function() return SimpleBossModsDB.cfg.icons.fontSize end,
			function(v) addon:ApplyIconConfig(SimpleBossModsDB.cfg.icons.size, v, SimpleBossModsDB.cfg.icons.borderThickness) end,
			0.33
		)

		addNumberInput(icons, "Icon Border Thickness",
			function() return SimpleBossModsDB.cfg.icons.borderThickness end,
			function(v) addon:ApplyIconConfig(SimpleBossModsDB.cfg.icons.size, SimpleBossModsDB.cfg.icons.fontSize, v) end,
			0.33
		)

		if LSM then
			local iconFontDropdown = AG:Create("LSM30_Font")
			iconFontDropdown:SetLabel("Icon Font")
			iconFontDropdown:SetList(LSM:HashTable("font"))
			iconFontDropdown:SetValue(SimpleBossModsDB.cfg.icons.font)
			iconFontDropdown:SetFullWidth(true)
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
		local bars = AG:Create("InlineGroup")
		bars:SetTitle("Bars")
		bars:SetLayout("Flow")
		bars:SetFullWidth(true)
		container:AddChild(bars)

		addNumberInput(bars, "Bar Width",
			function() return SimpleBossModsDB.cfg.bars.width end,
			function(v) addon:ApplyBarConfig(v, SimpleBossModsDB.cfg.bars.height, SimpleBossModsDB.cfg.bars.fontSize, SimpleBossModsDB.cfg.bars.borderThickness) end,
			0.25
		)

		addNumberInput(bars, "Bar Height",
			function() return SimpleBossModsDB.cfg.bars.height end,
			function(v) addon:ApplyBarConfig(SimpleBossModsDB.cfg.bars.width, v, SimpleBossModsDB.cfg.bars.fontSize, SimpleBossModsDB.cfg.bars.borderThickness) end,
			0.25
		)

		addNumberInput(bars, "Bar Font Size",
			function() return SimpleBossModsDB.cfg.bars.fontSize end,
			function(v) addon:ApplyBarConfig(SimpleBossModsDB.cfg.bars.width, SimpleBossModsDB.cfg.bars.height, v, SimpleBossModsDB.cfg.bars.borderThickness) end,
			0.25
		)

		addNumberInput(bars, "Bar Border Thickness",
			function() return SimpleBossModsDB.cfg.bars.borderThickness end,
			function(v) addon:ApplyBarConfig(SimpleBossModsDB.cfg.bars.width, SimpleBossModsDB.cfg.bars.height, SimpleBossModsDB.cfg.bars.fontSize, v) end,
			0.25
		)

		addNumberInput(bars, "Icon -> Bar Threshold (sec)",
			function() return SimpleBossModsDB.cfg.general.thresholdToBar end,
			function(v) addon:ApplyBarThresholdConfig(v) end,
			1
		)

		addCheckBox(bars, "Swap Bar Icon Side",
			function() return SimpleBossModsDB.cfg.bars.swapIconSide end,
			function(v) addon:ApplyBarIconSideConfig(v) end,
			0.5
		)

		addCheckBox(bars, "Hide Bar Icon",
			function() return SimpleBossModsDB.cfg.bars.hideIcon end,
			function(v) addon:ApplyBarIconVisibilityConfig(v) end,
			0.5
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
			barTextureDropdown:SetLabel("Bar Texture")
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

		local indicators = AG:Create("InlineGroup")
		indicators:SetTitle("Indicators")
		indicators:SetLayout("Flow")
		indicators:SetFullWidth(true)
		container:AddChild(indicators)

		addNumberInput(indicators, "Icon Indicator Size",
			function() return SimpleBossModsDB.cfg.indicators.iconSize or 0 end,
			function(v) addon:ApplyIndicatorConfig(v, SimpleBossModsDB.cfg.indicators.barSize or 0) end,
			0.5
		)

		addNumberInput(indicators, "Bar Indicator Size",
			function() return SimpleBossModsDB.cfg.indicators.barSize or 0 end,
			function(v) addon:ApplyIndicatorConfig(SimpleBossModsDB.cfg.indicators.iconSize or 0, v) end,
			0.5
		)

		local colors = AG:Create("InlineGroup")
		colors:SetTitle("Colors")
		colors:SetLayout("Flow")
		colors:SetFullWidth(true)
		container:AddChild(colors)

		addColorPicker(colors, "Bar Foreground Color",
			function() return L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A end,
			function(r, g, b, a) addon:ApplyBarColor(r, g, b, a) end,
			0.5
		)

		addColorPicker(colors, "Bar Background Color",
			function() return L.BAR_BG_R, L.BAR_BG_G, L.BAR_BG_B, L.BAR_BG_A end,
			function(r, g, b, a) addon:ApplyBarBgColor(r, g, b, a) end,
			0.5
		)
	end

	local function buildPrivateTab(container)
		local enabled = SimpleBossModsDB.cfg.privateAuras.enabled ~= false
		local toggle = AG:Create("CheckBox")
		toggle:SetLabel("Enable Private Aura Tracking")
		toggle:SetValue(enabled)
		toggle:SetFullWidth(true)
		toggle:SetCallback("OnValueChanged", function(_, _, value)
			addon:ApplyPrivateAuraEnabled(value)
			container:ReleaseChildren()
			buildPrivateTab(container)
		end)
		container:AddChild(toggle)

		if not enabled then
			local note = AG:Create("Label")
			note:SetText("Private aura tracking is currently disabled.")
			note:SetFullWidth(true)
			container:AddChild(note)
			return
		end

		local layout = AG:Create("InlineGroup")
		layout:SetTitle("Layout")
		layout:SetLayout("Flow")
		layout:SetFullWidth(true)
		container:AddChild(layout)

		addNumberInput(layout, "Private Aura X Offset",
			function() return SimpleBossModsDB.cfg.privateAuras.x or 0 end,
			function(v)
				addon:ApplyPrivateAuraConfig(
					SimpleBossModsDB.cfg.privateAuras.size,
					SimpleBossModsDB.cfg.privateAuras.gap,
					SimpleBossModsDB.cfg.privateAuras.growDirection,
					v,
					SimpleBossModsDB.cfg.privateAuras.y,
					SimpleBossModsDB.cfg.privateAuras.sound
				)
			end,
			0.5
		)

		addNumberInput(layout, "Private Aura Y Offset",
			function() return SimpleBossModsDB.cfg.privateAuras.y or 0 end,
			function(v)
				addon:ApplyPrivateAuraConfig(
					SimpleBossModsDB.cfg.privateAuras.size,
					SimpleBossModsDB.cfg.privateAuras.gap,
					SimpleBossModsDB.cfg.privateAuras.growDirection,
					SimpleBossModsDB.cfg.privateAuras.x,
					v,
					SimpleBossModsDB.cfg.privateAuras.sound
				)
			end,
			0.5
		)

		addNumberInput(layout, "Private Aura Icon Size",
			function() return SimpleBossModsDB.cfg.privateAuras.size end,
			function(v)
				addon:ApplyPrivateAuraConfig(
					v,
					SimpleBossModsDB.cfg.privateAuras.gap,
					SimpleBossModsDB.cfg.privateAuras.growDirection,
					SimpleBossModsDB.cfg.privateAuras.x,
					SimpleBossModsDB.cfg.privateAuras.y,
					SimpleBossModsDB.cfg.privateAuras.sound
				)
			end,
			0.5
		)

		addNumberInput(layout, "Private Aura Gap",
			function() return SimpleBossModsDB.cfg.privateAuras.gap end,
			function(v)
				addon:ApplyPrivateAuraConfig(
					SimpleBossModsDB.cfg.privateAuras.size,
					v,
					SimpleBossModsDB.cfg.privateAuras.growDirection,
					SimpleBossModsDB.cfg.privateAuras.x,
					SimpleBossModsDB.cfg.privateAuras.y,
					SimpleBossModsDB.cfg.privateAuras.sound
				)
			end,
			0.5
		)

		addDropdown(layout, "Private Aura Grow Direction",
			{ RIGHT = "Right", LEFT = "Left", UP = "Up", DOWN = "Down" },
			function() return SimpleBossModsDB.cfg.privateAuras.growDirection end,
			function(v)
				addon:ApplyPrivateAuraConfig(
					SimpleBossModsDB.cfg.privateAuras.size,
					SimpleBossModsDB.cfg.privateAuras.gap,
					v,
					SimpleBossModsDB.cfg.privateAuras.x,
					SimpleBossModsDB.cfg.privateAuras.y,
					SimpleBossModsDB.cfg.privateAuras.sound
				)
			end,
			0.5
		)

		local sound = AG:Create("InlineGroup")
		sound:SetTitle("Sound")
		sound:SetLayout("Flow")
		sound:SetFullWidth(true)
		container:AddChild(sound)

		local channelList = {
			Master = "Master",
			SFX = "SFX",
			Music = "Music",
			Ambience = "Ambience",
			Dialog = "Dialog",
		}

		addDropdown(sound, "Sound Channel",
			channelList,
			function() return SimpleBossModsDB.cfg.privateAuras.soundChannel end,
			function(v)
				addon:ApplyPrivateAuraSoundChannel(v)
			end,
			1
		)

		if LSM then
			local soundDropdown = AG:Create("LSM30_Sound")
			soundDropdown:SetLabel("Private Aura Sound")
			soundDropdown:SetList(getPrivateAuraSoundList())
			soundDropdown:SetValue(SimpleBossModsDB.cfg.privateAuras.sound)
			soundDropdown:SetRelativeWidth(0.7)
			soundDropdown:SetCallback("OnValueChanged", function(widget, _, value)
				addon:ApplyPrivateAuraConfig(
					SimpleBossModsDB.cfg.privateAuras.size,
					SimpleBossModsDB.cfg.privateAuras.gap,
					SimpleBossModsDB.cfg.privateAuras.growDirection,
					SimpleBossModsDB.cfg.privateAuras.x,
					SimpleBossModsDB.cfg.privateAuras.y,
					value
				)
				widget:SetValue(SimpleBossModsDB.cfg.privateAuras.sound)
			end)
			sound:AddChild(soundDropdown)
		else
			local label = AG:Create("Label")
			label:SetText("LibSharedMedia is not available.")
			label:SetFullWidth(true)
			sound:AddChild(label)
		end

		local testBtn = AG:Create("Button")
		testBtn:SetText("Test Sound")
		if LSM then
			testBtn:SetRelativeWidth(0.3)
		else
			testBtn:SetFullWidth(true)
		end
		testBtn:SetCallback("OnClick", function()
			if addon.PlayPrivateAuraSound then
				addon:PlayPrivateAuraSound()
			end
		end)
		sound:AddChild(testBtn)
	end

	local status = { selected = "General" }
	addon._settingsTabStatus = status

	local tabs = AG:Create("TabGroup")
	tabs:SetLayout("Flow")
	tabs:SetFullWidth(true)
	tabs:SetFullHeight(true)
	tabs:SetTabs({
		{ text = "General", value = "General" },
		{ text = "Icons", value = "Icons" },
		{ text = "Bars", value = "Bars" },
		{ text = "Private Auras", value = "Private" },
	})
	tabs:SetStatusTable(status)
	local validTabs = {
		General = true,
		Icons = true,
		Bars = true,
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
		elseif group == "Icons" then
			buildIconsTab(scroll)
		elseif group == "Bars" then
			buildBarsTab(scroll)
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
