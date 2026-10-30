require("Global")
require("Quest")

--[[

Quest Script

Name: 	Stone Deaf
Code: 	Etc2g2
Id: 	110666
Prereq: Level 18, Any DoW/DoM

]]

-- Sequence Numbers
local SEQ_000	= 0  -- Kill Canopy Galagos.
local SEQ_001	= 1  -- Talk to Kinborow.

-- Actor Class Ids
local ENPC_KINBOROW 		= 1000509
local BNPC_CANOPY_GALAGOS	= 2100502

-- Quest Markers
local MRKR_GALAGOS_AREA	= 11066602
local MRKR_KINBOROW		= 11066601

-- Counters
local COUNTER_QUESTITEM	= 0

-- Quest Details
local OBJECTIVE_ITEMID	= 11000163
local OBJECTIVE_AMOUNT	= 5

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(ENPC_KINBOROW, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ENPC_KINBOROW)
		quest:SetENpc(BNPC_CANOPY_GALAGOS)
	elseif sequence == SEQ_001 then
		quest:SetENpc(ENPC_KINBOROW, QFLAG_REWARD)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		-- Offer the quest
		[ENPC_KINBOROW] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart")
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	-- Quest Progress
	[SEQ_000] = {
		[ENPC_KINBOROW] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEventFree")
		end,
	},
	--Quest Complete
	[SEQ_001] = {
		[ENPC_KINBOROW] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear")
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
	if quest:GetSequence() == SEQ_000 and bnpc == BNPC_CANOPY_GALAGOS then
		local counterAmount = quest:GetData():IncCounter(COUNTER_QUESTITEM)
		attentionMessage(player, 25226, OBJECTIVE_ITEMID, 1, counterAmount, OBJECTIVE_AMOUNT) -- You obtain <item> (X of Y)
		if counterAmount >= OBJECTIVE_AMOUNT then
			attentionMessage(player, 25225, quest:GetQuestId()) -- Objectives complete!
			quest:StartSequence(SEQ_001)
		end
	end
end

function getJournalInformation(player, quest)
	return quest:GetData():GetCounter(COUNTER_QUESTITEM)
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_GALAGOS_AREA
	elseif sequence == SEQ_001 then
		return MRKR_KINBOROW
	end
end