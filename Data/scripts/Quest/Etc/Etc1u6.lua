require("Global")
require("Quest")

--[[
Besmitten and Besmirched (Etc1u6, 110681). Prereq: Level 15, Any DoW/DoM.
--]]

-- Sequence Numbers
local SEQ_000	= 0  -- Kill Moiling Moles.
local SEQ_001	= 1  -- Talk to Mohtfryd.

-- Actor Class Ids
local ENPC_MOHTFRYD 		= 1001170
local BNPC_MOILING_MOLE	= 2105717

-- Quest Markers
local MRKR_MOLE_AREA		= 11068102
local MRKR_MOHTFRYD		= 11068103

-- Counters
local COUNTER_QUESTITEM	= 0

-- Quest Details
local OBJECTIVE_ITEMID	= 11000157
local OBJECTIVE_AMOUNT	= 8

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(ENPC_MOHTFRYD, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ENPC_MOHTFRYD)
		quest:SetENpc(BNPC_MOILING_MOLE)
	elseif sequence == SEQ_001 then
		quest:SetENpc(ENPC_MOHTFRYD, QFLAG_REWARD)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[ENPC_MOHTFRYD] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventMohtfrydStart", 0, OBJECTIVE_AMOUNT)
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	[SEQ_000] = {
		[ENPC_MOHTFRYD] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEventFree", 0, OBJECTIVE_AMOUNT)
		end,
	},
	[SEQ_001] = {
		[ENPC_MOHTFRYD] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEventAfter", 0)
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
	if quest:GetSequence() == SEQ_000 and bnpc == BNPC_MOILING_MOLE then
		local counterAmount = quest:GetData():IncCounter(COUNTER_QUESTITEM)
		attentionMessage(player, 25226, OBJECTIVE_ITEMID, 1, counterAmount, OBJECTIVE_AMOUNT) -- You obtain <item> (X of Y)
		if counterAmount >= OBJECTIVE_AMOUNT then
			attentionMessage(player, 25225, quest:GetQuestId()) -- Objectives complete!
			quest:StartSequence(SEQ_001)
		end
	end
end

function getJournalInformation(player, quest)
	return quest:GetData():GetCounter(COUNTER_QUESTITEM), 0, 0, 0, OBJECTIVE_AMOUNT
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_MOLE_AREA
	elseif sequence == SEQ_001 then
		return MRKR_MOHTFRYD
	end
end