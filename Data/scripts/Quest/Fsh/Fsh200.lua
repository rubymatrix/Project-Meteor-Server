require("Global")
require("Quest")
require("QuestFlow")

--[[
To Fight a Fishback (Fsh200, quest 110500). Fisher level 20, offered by N'nmulika at the
Fishermen's Guild in Limsa Lominsa.

Seq 0: Maisie's briefing.
Seq 1: Net five Pixie Remora for Maisie; her reward.

The client reads the remaining count from counter 0 to pick Maisie's thanks or her reminder, so it is
rewritten before each delivery scene. Counter 1 holds the Remora owned at the briefing: only fish netted
afterwards count. No seed: Maisie and N'nmulika are already placed.
--]]

local SEQ_000 = 0
local SEQ_001 = 1

local NNMULIKA = 1000153
local MAISIE   = 1000173

local MRKR_MAISIE   = 11050001
local MRKR_MAISIE2  = 11050003
local MRKR_WATERS_1 = 11050004
local MRKR_WATERS_2 = 11050005
local MRKR_WATERS_3 = 11050006
local MRKR_WATERS_4 = 11050007
local MRKR_WATERS_5 = 11050008

local ITEM_PIXIE_REMORA = 11000127
local REQUIRED_REMORA   = 5

local CNTR_REMAINING = 0
local CNTR_BASELINE  = 1

-- The client reward sheet has no row for this quest.
local COMPLETION_REWARDS = { exp = 1760, gil = 20000, items = { { 7030011, 1 } } }

-- The phase-table test runs with a stand-in player that has no inventory.
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

local function removeCount(player, itemId, count)
	local bag = player:GetItemPackage(INVENTORY_NORMAL)
	for quality = 1, 2 do
		while count > 0 and bag:HasItem(itemId, 1, quality) do
			bag:RemoveItem(itemId, 1, quality)
			count = count - 1
		end
	end
end


local function nettedRemora(player, data)
	return math.max(0, ownedCount(player, ITEM_PIXIE_REMORA) - data:GetCounter(CNTR_BASELINE))
end

local function isDeliveryReady(player, quest, data)
	return nettedRemora(player, data) >= REQUIRED_REMORA
end

local function isDeliveryPending(player, quest, data)
	return not isDeliveryReady(player, quest, data)
end

local function maisieEntry(player, quest, data)
	return { { MAISIE, isDeliveryReady(player, quest, data) and QFLAG_REWARD or QFLAG_TALK } }
end

local PHASES = {
	[SEQ_000] = {
		enpcs = { { MAISIE, QFLAG_TALK } },
		markers = { MRKR_MAISIE },
	},
	[SEQ_001] = {
		enpcs = maisieEntry,
		markers = {
			{ MRKR_WATERS_1, when = isDeliveryPending },
			{ MRKR_WATERS_2, when = isDeliveryPending },
			{ MRKR_WATERS_3, when = isDeliveryPending },
			{ MRKR_WATERS_4, when = isDeliveryPending },
			{ MRKR_WATERS_5, when = isDeliveryPending },
			{ MRKR_MAISIE2, when = isDeliveryReady },
		},
	},
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(NNMULIKA, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if sequence == SEQ_ACCEPT then
		if classId == NNMULIKA and not inPrivateArea(player) then
			local accepted = delegateEvent(player, quest, "processEventNnmulikaStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return
		end
	elseif sequence == SEQ_000 and classId == MAISIE then
		delegateEvent(player, quest, "processEvent010")
		local data = quest:GetData()
		data:SetCounter(CNTR_REMAINING, REQUIRED_REMORA)
		data:SetCounter(CNTR_BASELINE, ownedCount(player, ITEM_PIXIE_REMORA))
		quest:StartSequence(SEQ_001)
	elseif sequence == SEQ_001 and classId == MAISIE then
		-- A short catch replays the same scene as a reminder and keeps the step.
		local data = quest:GetData()
		setQuestCounter(quest, CNTR_REMAINING, math.max(0, REQUIRED_REMORA - nettedRemora(player, data)))
		delegateEvent(player, quest, "processEvent020")
		if isDeliveryReady(player, quest, data) then
			if turnInQuest(player, quest, nil, COMPLETION_REWARDS) then
				removeCount(player, ITEM_PIXIE_REMORA, REQUIRED_REMORA)
			end
			return
		end
	end

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

-- Refreshes icons and markers on a catch. Talks and pushes still read the inventory,
-- so a missed call changes nothing.
function onItemGained(player, quest, itemId, quantity, quality)
	for _, watched in ipairs({ ITEM_PIXIE_REMORA }) do
		if itemId == watched then
			quest:UpdateENPCs()
			return
		end
	end
end

function getJournalInformation(player, quest)
	if quest:GetSequence() ~= SEQ_001 then
		return 0, 0, 0, 0, 0
	end
	return math.min(nettedRemora(player, quest:GetData()), REQUIRED_REMORA), 0, 0, 0, REQUIRED_REMORA
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
