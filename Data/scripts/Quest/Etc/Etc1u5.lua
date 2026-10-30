require("Global")
require("Quest")

--[[

Quest Script

Name: 	An Inconvenient Dodo
Code: 	Etc1u5
Id: 	110680
Prereq: Level 15, Any DoW/DoM

]]

-- Sequence Numbers
local SEQ_000	= 0  -- Kill Stuffed Dodos.
local SEQ_001	= 1  -- Talk to U'Bokhn.

-- Actor Class Ids
local ENPC_UBOKHN 		= 1000668
local BNPC_STUFFED_DODO	= 2102009

-- Quest Markers
local MRKR_DODO_AREA		= 11068001
local MRKR_UBOKHN			= 11068002

-- Counters
local COUNTER_KILLS	= 0

-- Quest Details
local OBJECTIVE_AMOUNT	= 8

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(ENPC_UBOKHN, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ENPC_UBOKHN)
		quest:SetENpc(BNPC_STUFFED_DODO)
	elseif sequence == SEQ_001 then
		quest:SetENpc(ENPC_UBOKHN, QFLAG_REWARD)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		-- Offer the quest
		[ENPC_UBOKHN] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventUbokhnStart", 0, OBJECTIVE_AMOUNT)
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	-- Quest Progress
	[SEQ_000] = {
		[ENPC_UBOKHN] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEventUbokhnAfterOffer", 5, OBJECTIVE_AMOUNT) -- Need to send 5 or it shows a placeholder.
		end,
	},
	--Quest Complete
	[SEQ_001] = {
		[ENPC_UBOKHN] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010", 5)
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
	if quest:GetSequence() == SEQ_000 and bnpc == BNPC_STUFFED_DODO then
		local counterAmount = quest:GetData():IncCounter(COUNTER_KILLS)
		attentionMessage(player, 50041, 3102011, counterAmount, OBJECTIVE_AMOUNT) -- The <dispName> has been defeated. (X of Y)
		if counterAmount >= OBJECTIVE_AMOUNT then
			attentionMessage(player, 25225, quest:GetQuestId()) -- Objectives complete!
			quest:StartSequence(SEQ_001)
		end
	end
end

function getJournalInformation(player, quest)
	return quest:GetData():GetCounter(COUNTER_KILLS), 0, 0, 0, OBJECTIVE_AMOUNT
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_DODO_AREA
	elseif sequence == SEQ_001 then
		return MRKR_UBOKHN
	end
end