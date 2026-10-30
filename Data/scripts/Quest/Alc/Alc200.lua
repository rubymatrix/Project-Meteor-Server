require("Global")
require("Quest")
require("QuestFlow")

--[[
Sleep, Cousin of Death (Alc200, 110420). No client prereq; class ALC, level 20.
Only a medication made after the Mole is given counts: counter 0 holds how many the player owned
then. Spawns and class fills: Data/sql/seed/seed_quest_alc200_01.sql.
--]]

local SEQ_000 = 0
local SEQ_005 = 5
local SEQ_007 = 7
local SEQ_010 = 10
local SEQ_015 = 15

local NOGELOIX = 1000597
local NOMOMO   = 1001392
local SLYHHIA  = 1000932

local MRKR_NOMOMO    = 11042001
local MRKR_NOGELOIX  = 11042003
local MRKR_SLYHHIA   = 11042004
local MRKR_OBJECTIVE = 11042005
local MRKR_NOGELOIX2 = 11042006

local ITEM_MUMMIFIED_MOLE    = 11000076
local ITEM_POTENT_MEDICATION = 11000077

local CNTR_MEDICATION_BASELINE = 0

-- Completion pay: the client reward sheet has no row for this quest (questflow.lua turnInQuest).
local COMPLETION_REWARDS = { exp = 1760, gil = 20000 }

-- A synthesis result is quality 1 or 2. The phase-table test runs with a stand-in player that has no
-- inventory.
local function ownedCount(player, itemId)
	if player.GetItemPackage == nil then
		return 0
	end
	local bag = player:GetItemPackage(INVENTORY_NORMAL)
	local total = 0
	for quality = 1, 2 do
		local n = 0
		while n < 99 and bag:HasItem(itemId, n + 1, quality) do
			n = n + 1
		end
		total = total + n
	end
	return total
end

local function removeOne(player, itemId)
	local bag = player:GetItemPackage(INVENTORY_NORMAL)
	for quality = 1, 2 do
		if bag:HasItem(itemId, 1, quality) then
			bag:RemoveItem(itemId, 1, quality)
			return
		end
	end
end

local function grantItem(player, itemId)
	player:GetItemPackage(INVENTORY_NORMAL):AddItem(itemId, 1, 1)
	player:SendGameMessage(GetWorldMaster(), TEXT_KEY_ITEM_OBTAINED, 0x20, itemId)
end


local function isMedicationMade(player, quest)
	return ownedCount(player, ITEM_POTENT_MEDICATION) > getQuestCounter(quest, CNTR_MEDICATION_BASELINE)
end

local PHASES = {
	[SEQ_000] = {
		enpcs = { { NOMOMO, QFLAG_TALK } },
		markers = { MRKR_NOMOMO },
	},
	-- Nomomo stays listed so a lost Mole can be fetched again.
	[SEQ_005] = {
		enpcs = { { NOGELOIX, QFLAG_TALK }, NOMOMO },
		markers = { MRKR_NOGELOIX },
	},
	[SEQ_007] = {
		enpcs = { { SLYHHIA, QFLAG_TALK }, NOMOMO },
		markers = { MRKR_SLYHHIA },
	},
	[SEQ_010] = {
		enpcs = { { SLYHHIA, QFLAG_TALK } },
		markers = { MRKR_OBJECTIVE },
	},
	[SEQ_015] = {
		enpcs = { { NOGELOIX, QFLAG_REWARD } },
		markers = { MRKR_NOGELOIX2 },
	},
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(NOGELOIX, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

-- A second Mole only follows a total loss: no Mole and no medication made.
local function nomomoAgain(player, quest)
	delegateEvent(player, quest, "processEvent010")
	if ownedCount(player, ITEM_MUMMIFIED_MOLE) == 0 and not isMedicationMade(player, quest) then
		grantItem(player, ITEM_MUMMIFIED_MOLE)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[NOGELOIX] = function(player, quest)
			local accepted = delegateEvent(player, quest, "processEventNogeloixStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return true
		end,
	},
	[SEQ_000] = {
		[NOMOMO] = function(player, quest)
			delegateEvent(player, quest, "processEvent010")
			setQuestCounter(quest, CNTR_MEDICATION_BASELINE, ownedCount(player, ITEM_POTENT_MEDICATION))
			grantItem(player, ITEM_MUMMIFIED_MOLE)
			quest:StartSequence(SEQ_005)
		end,
	},
	[SEQ_005] = {
		[NOMOMO] = nomomoAgain,
		-- The inspection keeps the medication for S'lyhhia.
		[NOGELOIX] = function(player, quest)
			if isMedicationMade(player, quest) then
				delegateEvent(player, quest, "processEvent015")
				if isMedicationMade(player, quest) then
					quest:StartSequence(SEQ_007)
				end
			end
		end,
	},
	[SEQ_007] = {
		[NOMOMO] = nomomoAgain,
		-- Only a yes to the handoff question gives the medicine away.
		[SLYHHIA] = function(player, quest)
			if ownedCount(player, ITEM_POTENT_MEDICATION) > 0 then
				local answer = delegateEvent(player, quest, "processEvent015_6")
				if answer == 1 and ownedCount(player, ITEM_POTENT_MEDICATION) > 0 then
					removeOne(player, ITEM_POTENT_MEDICATION)
					quest:StartSequence(SEQ_010)
				end
			end
		end,
	},
	[SEQ_010] = {
		[SLYHHIA] = function(player, quest)
			delegateEvent(player, quest, "processEvent020")
			quest:StartSequence(SEQ_015)
		end,
	},
	[SEQ_015] = {
		[NOGELOIX] = function(player, quest)
			turnInQuest(player, quest, "processEvent030", COMPLETION_REWARDS)
			return true
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc, eventName)
	player:EndEvent()
end

function onNotice(player, quest, target)
	player:EndEvent()
	quest:UpdateENPCs()
end

-- The journal counts the live medication, never a stored copy.
-- A craft or a catch shows on the icons and markers at once (the server's inventory hook); the talks and
-- pushes still read the inventory, so a missed call changes nothing.
function onItemGained(player, quest, itemId, quantity, quality)
	for _, watched in ipairs({ ITEM_MUMMIFIED_MOLE, ITEM_POTENT_MEDICATION }) do
		if itemId == watched then
			quest:UpdateENPCs()
			return
		end
	end
end

function getJournalInformation(player, quest)
	if quest:GetSequence() ~= SEQ_005 then
		return 0, 0, 0, 0, 0
	end
	return isMedicationMade(player, quest) and 1 or 0, 0, 0, 0, 1
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
