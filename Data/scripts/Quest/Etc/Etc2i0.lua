require("Global")
require("Quest")

--[[

Quest Script

Name: 	Counting Sheep
Code: 	Etc2i0
Id: 	110706
Prereq: Level 25, Any DoW/DoM

]]

-- Sequence Numbers
local SEQ_000	= 0  -- Kill Dreadwolves.
local SEQ_001	= 1  -- Talk to Patrick.

-- Actor Class Ids
local ENPC_PATRICK 		= 1001358
local BNPC_DREADWOLVES	= 2101403

-- Quest Markers
local MRKR_WOLF_AREA		= 11101901
local MRKR_PATRICK		= 11101902

-- Counters
local COUNTER_KILLS		= 0

-- Quest Details
local OBJECTIVE_AMOUNT	= 4

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(ENPC_PATRICK, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ENPC_PATRICK)
		quest:SetENpc(BNPC_DREADWOLVES)
	elseif sequence == SEQ_001 then
		quest:SetENpc(ENPC_PATRICK, QFLAG_REWARD)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		-- Offer the quest
		[ENPC_PATRICK] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventPatrickStart")
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	-- Quest Progress
	[SEQ_000] = {
		[ENPC_PATRICK] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000")
		end,
	},
	--Quest Complete
	[SEQ_001] = {
		[ENPC_PATRICK] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end,
	},
}

function onTalk(player, quest, npc, eventName)
	if runQuestHandler(talk, player, quest, npc, eventName) then return end

	quest:UpdateENPCs()
	player:EndEvent()
end

function onKillBNpc(player, quest, bnpc)
	if quest:GetSequence() == SEQ_000 and bnpc == BNPC_DREADWOLVES then
		local counterAmount = quest:GetData():IncCounter(COUNTER_KILLS)
		attentionMessage(player, 50041, 3101403, counterAmount, OBJECTIVE_AMOUNT) -- The <dispName> has been defeated. (X of Y)
		if counterAmount >= OBJECTIVE_AMOUNT then
			attentionMessage(player, 25225, quest:GetQuestId()) -- Objectives complete!
			quest:StartSequence(SEQ_001)
		end
	end
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_WOLF_AREA
	elseif sequence == SEQ_001 then
		return MRKR_PATRICK
	end
end