require("Global")
require("Quest")

--[[

Quest Script

Name: 	Spores on the Brain
Code: 	Wld0g4
Id: 	110765
Prereq: Level 11, Any Class, Requires "In the Name of Science"

]]

-- Sequence Numbers
local SEQ_000	= 0  -- Kill Mature Funguars.
local SEQ_001	= 1  -- Talk to Marcette.

-- Actor Class Ids
local ENPC_MARCETTE 		= 1001583
local BNPC_MATURE_FUNGUAR	= 2105916

-- Quest Markers
local MRKR_MARCETTE		= 11120302
local MRKR_FUNGUAR_AREA	= 11120301

-- Counters
local COUNTER_QUESTITEM	= 0

-- Quest Details
local OBJECTIVE_ITEMID	= 11000301
local OBJECTIVE_AMOUNT	= 8

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(ENPC_MARCETTE, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ENPC_MARCETTE)
		quest:SetENpc(BNPC_MATURE_FUNGUAR)
	elseif sequence == SEQ_001 then
		quest:SetENpc(ENPC_MARCETTE, QFLAG_REWARD)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		-- Offer the quest
		[ENPC_MARCETTE] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventMarcetteStart")
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	-- Quest Progress
	[SEQ_000] = {
		[ENPC_MARCETTE] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2")
		end,
	},
	--Quest Complete
	[SEQ_001] = {
		[ENPC_MARCETTE] = function(player, quest, npc, eventName)
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
	if quest:GetSequence() == SEQ_000 and bnpc == BNPC_MATURE_FUNGUAR then
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
		return MRKR_FUNGUAR_AREA
	elseif sequence == SEQ_001 then
		return MRKR_MARCETTE
	end
end