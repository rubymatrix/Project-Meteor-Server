require("Global")
require("Quest")

--[[

Quest Script

Name: 	Last Respects
Code: 	Etc1g1
Id: 	110665
Prereq: Level 40, Any DoW/DoM

]]

-- Sequence Numbers
local SEQ_000	= 0  -- Kill Lemurs.
local SEQ_001	= 1  -- Talk to Eadbert.

-- Actor Class Ids
local ENPC_EADBERT 		= 1001345
local BNPC_LEMURS			= 2100512

-- Quest Markers
local MRKR_LEMUR_AREA		= 11066501
local MRKR_EADBERT		= 11066502

-- Counters
local COUNTER_QUESTITEM	= 0

-- Quest Details
local OBJECTIVE_ITEMID	= 11000162
local OBJECTIVE_AMOUNT	= 4

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(ENPC_EADBERT, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ENPC_EADBERT)
		quest:SetENpc(BNPC_LEMURS)
	elseif sequence == SEQ_001 then
		quest:SetENpc(ENPC_EADBERT, QFLAG_REWARD)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		-- Offer the quest
		[ENPC_EADBERT] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventEadbertStart")
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	-- Quest Progress
	[SEQ_000] = {
		[ENPC_EADBERT] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000")
		end,
	},
	--Quest Complete
	[SEQ_001] = {
		[ENPC_EADBERT] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005")
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
	if quest:GetSequence() == SEQ_000 and bnpc == BNPC_LEMURS then
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
		return MRKR_LEMUR_AREA
	elseif sequence == SEQ_001 then
		return MRKR_EADBERT
	end
end