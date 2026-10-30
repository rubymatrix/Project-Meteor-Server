require("Global")
require("Quest")
require("QuestFlow")

--[[
A Piece of History (Min200, 110460). Miner level 20, offered by Linette. Only finds gained after
Z'ssapa's briefing count: the ones already held are counted then. Journal (Seq 7): int2..int4 =
each find held, int6 = the number of finds.
--]]

local SEQ_000 = 0
local SEQ_005 = 5
local SEQ_007 = 7
local SEQ_025 = 25

local ZSSAPA  = 1000887
local LINETTE = 1000861

local MRKR_ZSSAPA     = 11046001
local MRKR_ZSSAPA2    = 11046003
local MRKR_LINETTE    = 11046005
local MRKR_FINDS_EAST = 11046006
local MRKR_FINDS_WEST = 11046007
local MRKR_FINDS_CENT = 11046008

-- Each find and the counter holding how many were owned at the briefing.
local FINDS = {
	{ item = 11000012, counter = 0 },
	{ item = 11000013, counter = 1 },
	{ item = 11000014, counter = 2 },
}
local FIND_COUNT_CAP = 99

-- The client reward sheet has no class-quest rows.
local COMPLETION_REWARDS = { exp = 1760, gil = 20000 }

local function heldCount(player, itemId)
	-- The phase-table test's stand-in player has no inventory.
	local pkg = player.GetItemPackage and player:GetItemPackage(INVENTORY_NORMAL)
	local n = 0
	if pkg == nil then
		return 0
	end
	while n < FIND_COUNT_CAP and pkg:HasItem(itemId, n + 1) do
		n = n + 1
	end
	return n
end

-- The journal and icons read the live count, never a stored copy.
local function isFindHeld(player, quest, find)
	return heldCount(player, find.item) > getQuestCounter(quest, find.counter)
end

local function areAllFindsHeld(player, quest)
	for _, find in ipairs(FINDS) do
		if not isFindHeld(player, quest, find) then
			return false
		end
	end
	return true
end

local function areFindsMissing(player, quest)
	return not areAllFindsHeld(player, quest)
end

local PHASES = {
	[SEQ_000] = { enpcs = { { ZSSAPA, QFLAG_TALK } }, markers = { MRKR_ZSSAPA } },
	[SEQ_005] = { enpcs = { { ZSSAPA, QFLAG_TALK } }, markers = { MRKR_ZSSAPA } },
	[SEQ_007] = {
		enpcs = function(player, quest)
			return { { ZSSAPA, areAllFindsHeld(player, quest) and QFLAG_REWARD or QFLAG_TALK } };
		end,
		markers = {
			{ MRKR_FINDS_EAST, when = areFindsMissing },
			{ MRKR_FINDS_WEST, when = areFindsMissing },
			{ MRKR_FINDS_CENT, when = areFindsMissing },
			{ MRKR_ZSSAPA2, when = areAllFindsHeld },
		},
	},
	[SEQ_025] = { enpcs = { { LINETTE, QFLAG_REWARD } }, markers = { MRKR_LINETTE } },
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(LINETTE, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

local talk = {
	[SEQ_ACCEPT] = {
		[LINETTE] = function(player, quest, npc)
			local accepted = delegateEvent(player, quest, "processEventLinetteStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return true
		end,
	},
	[SEQ_000] = {
		[ZSSAPA] = function(player, quest, npc)
			delegateEvent(player, quest, "processEvent010")
			for _, find in ipairs(FINDS) do
				setQuestCounter(quest, find.counter, heldCount(player, find.item))
			end
			quest:StartSequence(SEQ_005)
		end,
	},
	[SEQ_005] = {
		[ZSSAPA] = function(player, quest, npc)
			delegateEvent(player, quest, "processEvent015_1")
			delegateEvent(player, quest, "processEvent015_2")
			quest:StartSequence(SEQ_007)
		end,
	},
	[SEQ_007] = {
		[ZSSAPA] = function(player, quest, npc)
			delegateEvent(player, quest, "processEvent020")
			if areAllFindsHeld(player, quest) then
				for _, find in ipairs(FINDS) do
					player:GetItemPackage(INVENTORY_NORMAL):RemoveItem(find.item, 1)
				end
				quest:StartSequence(SEQ_025)
			end
		end,
	},
	[SEQ_025] = {
		[LINETTE] = function(player, quest, npc)
			turnInQuest(player, quest, "processEvent050", COMPLETION_REWARDS)
			return true
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end

	player:EndEvent()
	quest:UpdateENPCs()
end

-- Called by Player.OnHarvest when a node is worked out. Every Thanalan mining pool also yields
-- the three finds at Seq 7. Returns an item id or nil.
function onHarvest(player, quest, harvestType, zoneId)
	if quest:GetSequence() ~= SEQ_007 or zoneId < 170 or zoneId > 174 then
		return nil
	end
	for _, find in ipairs(FINDS) do
		if not isFindHeld(player, quest, find) then
			return find.item
		end
	end
	return nil
end

function getJournalInformation(player, quest)
	if quest:GetSequence() ~= SEQ_007 then
		return 0, 0, 0, 0, 0
	end
	return isFindHeld(player, quest, FINDS[1]) and 1 or 0,
		isFindHeld(player, quest, FINDS[2]) and 1 or 0,
		isFindHeld(player, quest, FINDS[3]) and 1 or 0,
		0,
		#FINDS
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
