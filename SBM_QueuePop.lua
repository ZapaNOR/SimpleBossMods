-- Queue pop timers for SimpleBossMods.
-- Displays countdown bars for LFG/LFR, PvP, and Pet Battle queue pops.

local ADDON_NAME = ...
local M = _G[ADDON_NAME]
if not M then return end

local C = M.Const
local L = M.Live

-- Queue timer IDs (high values to avoid collisions with timeline/manual IDs)
local QUEUE_ID_LFG = 9102001
local QUEUE_ID_PVP_BASE = 9102100 -- + battlefield index (1-3)
local QUEUE_ID_PET_BATTLE = 9102201

local QUEUE_ICON = "Interface\\Icons\\Spell_holy_borrowedtime"

-- LFG proposal timer is 40 seconds
local LFG_PROPOSAL_DURATION = 40
-- Pet battle proposal timer (approximate, no API for exact remaining)
local PET_BATTLE_PROPOSAL_DURATION = 15

-- =========================
-- Helpers
-- =========================
local function isQueueTimersEnabled()
	return L.QUEUE_TIMERS ~= false
end

local function startQueueTimer(id, label, icon, duration)
	if not M.enabled then return end
	if not isQueueTimersEnabled() then return end

	M.events = M.events or {}
	local now = GetTime()
	local rec = M.events[id]
	if not rec then
		rec = { id = id }
		M.events[id] = rec
	end

	rec.isManual = true
	rec.forceBar = true
	rec.kind = "queue"
	rec.duration = duration
	rec.startTime = now
	rec.endTime = now + duration
	rec.remaining = duration
	rec.suppressCountdown = true
	rec.eventInfo = {
		name = label,
		icon = icon,
	}

	M:updateRecord(id, rec.eventInfo, duration)
	M:LayoutAll()
end

local function stopQueueTimer(id)
	if not M.events then return end
	if not M.events[id] then return end
	M:removeEvent(id, "queue-done", true)
	M:LayoutAll()
end

-- =========================
-- LFG / LFR Queue Pop
-- =========================
local function getProposalName()
	if not GetLFGProposal then return "Dungeon" end
	local proposalExists, _, _, _, name = GetLFGProposal()
	if proposalExists and type(name) == "string" and name ~= "" then
		return name
	end
	return "Dungeon"
end

local function onLFGProposalShow()
	local label = getProposalName()
	startQueueTimer(QUEUE_ID_LFG, label, QUEUE_ICON, LFG_PROPOSAL_DURATION)
end

local function onLFGProposalEnd()
	stopQueueTimer(QUEUE_ID_LFG)
end

-- =========================
-- PvP Queue Pop
-- =========================
local function updatePvPQueues()
	if not GetMaxBattlefieldID then return end
	if not GetBattlefieldStatus then return end

	local maxID = GetMaxBattlefieldID()
	for i = 1, maxID do
		local queueID = QUEUE_ID_PVP_BASE + i
		local status, mapName = GetBattlefieldStatus(i)
		if status == "confirm" then
			local remaining = nil
			if GetBattlefieldPortExpiration then
				remaining = GetBattlefieldPortExpiration(i)
			end
			if type(remaining) ~= "number" or remaining <= 0 then
				remaining = 120 -- fallback
			end
			local label = (type(mapName) == "string" and mapName ~= "") and mapName or "Battleground"
			-- Only start if not already tracking, or update remaining
			local rec = M.events and M.events[queueID]
			if not rec then
				startQueueTimer(queueID, label, QUEUE_ICON, remaining)
			else
				-- Update remaining from API each tick
				rec.remaining = remaining
				rec.endTime = GetTime() + remaining
			end
		else
			stopQueueTimer(queueID)
		end
	end

	-- Clean up any stale PvP queue timers beyond current maxID
	for i = maxID + 1, 3 do
		stopQueueTimer(QUEUE_ID_PVP_BASE + i)
	end
end

-- =========================
-- Pet Battle Queue Pop
-- =========================
local function onPetBattlePropose()
	startQueueTimer(QUEUE_ID_PET_BATTLE, "Pet Battle", QUEUE_ICON, PET_BATTLE_PROPOSAL_DURATION)
end

local function onPetBattleEnd()
	stopQueueTimer(QUEUE_ID_PET_BATTLE)
end

-- =========================
-- Event Frame
-- =========================
local qf = CreateFrame("Frame")
qf:SetScript("OnEvent", function(_, event, ...)
	if not isQueueTimersEnabled() then return end

	if event == "LFG_PROPOSAL_SHOW" then
		onLFGProposalShow()
	elseif event == "LFG_PROPOSAL_DONE"
		or event == "LFG_PROPOSAL_FAILED"
		or event == "LFG_PROPOSAL_SUCCEEDED" then
		onLFGProposalEnd()
	elseif event == "UPDATE_BATTLEFIELD_STATUS" then
		updatePvPQueues()
	elseif event == "PET_BATTLE_QUEUE_PROPOSE_MATCH" then
		onPetBattlePropose()
	elseif event == "PET_BATTLE_QUEUE_PROPOSAL_DECLINED"
		or event == "PET_BATTLE_QUEUE_PROPOSAL_ACCEPTED" then
		onPetBattleEnd()
	end
end)

qf:RegisterEvent("LFG_PROPOSAL_SHOW")
qf:RegisterEvent("LFG_PROPOSAL_DONE")
qf:RegisterEvent("LFG_PROPOSAL_FAILED")
qf:RegisterEvent("LFG_PROPOSAL_SUCCEEDED")
qf:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
qf:RegisterEvent("PET_BATTLE_QUEUE_PROPOSE_MATCH")
qf:RegisterEvent("PET_BATTLE_QUEUE_PROPOSAL_DECLINED")
qf:RegisterEvent("PET_BATTLE_QUEUE_PROPOSAL_ACCEPTED")
