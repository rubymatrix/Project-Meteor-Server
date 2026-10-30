require("Global")
require("Quest")

--[[

Quest Script

Name: 	The Ultimate Prank
Code: 	Etc1g6
Id: 	110660
Prereq: Level 35, Any DoW/DoM, Etc1g4 complete

]]

-- Sequence Numbers
local SEQ_000	= 0  -- Talk to Sylbyrt.
local SEQ_001	= 1  -- Kill Wandering Wights.
local SEQ_002 = 2  -- Talk to Sylbyrt.
local SEQ_003 = 3  -- Talk to Nicoliaux.

-- Actor Class Ids
local ENPC_SYLBYRT 			= 1000428
local ENPC_NICOLIAUX 			= 1000409
local BNPC_WANDERING_WIGHT	= 2101908

-- Quest Markers
local MRKR_WIGHT_AREA		= 11066001
local MRKR_SYLBYRT		= 11066002
local MRKR_NICOLIAUX		= 11066004

-- Counters
local COUNTER_QUESTITEM	= 0
local COUNTER_QUESTITEM2	= 1

-- Quest Details
local ITEM_CEDAR_MARIONETTE 	= 11000146
local OBJECTIVE_ITEMID		= 11000145
local OBJECTIVE_AMOUNT		= 3

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(ENPC_NICOLIAUX, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ENPC_SYLBYRT, QFLAG_TALK)
		quest:SetENpc(ENPC_NICOLIAUX)
	elseif sequence == SEQ_001 then
		quest:SetENpc(ENPC_SYLBYRT)
		quest:SetENpc(BNPC_WANDERING_WIGHT)
	elseif sequence == SEQ_002 then
		quest:SetENpc(ENPC_SYLBYRT, QFLAG_TALK)
	elseif sequence == SEQ_003 then
		quest:SetENpc(ENPC_SYLBYRT)
		quest:SetENpc(ENPC_NICOLIAUX, QFLAG_REWARD)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		-- Offer the quest
		[ENPC_NICOLIAUX] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventNicoliauxStart")
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	-- Quest Progress
	[SEQ_000] = {
		[ENPC_SYLBYRT] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000", 2, OBJECTIVE_AMOUNT)
			quest:StartSequence(SEQ_001)
		end,
		[ENPC_NICOLIAUX] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "followEvent000")
		end,
	},
	[SEQ_001] = {
		[ENPC_SYLBYRT] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "followEvent010", 2, OBJECTIVE_AMOUNT)
		end,
	},
	[SEQ_002] = {
		[ENPC_SYLBYRT] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010", 2, OBJECTIVE_AMOUNT)
			quest:GetData():IncCounter(COUNTER_QUESTITEM2)
			quest:StartSequence(SEQ_003)
		end,
	},
	--Quest Complete
	[SEQ_003] = {
		[ENPC_NICOLIAUX] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end,
		[ENPC_SYLBYRT] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "followEvent020")
		end,
	},
}

function onTalk(player, quest, npc, eventName)
	if runQuestHandler(talk, player, quest, npc, eventName) then return end

	quest:UpdateENPCs()
	player:EndEvent()
end

function onKillBNpc(player, quest, bnpc)
	if quest:GetSequence() == SEQ_001 and bnpc == BNPC_WANDERING_WIGHT then
		local counterAmount = quest:GetData():IncCounter(COUNTER_QUESTITEM)
		attentionMessage(player, 25226, OBJECTIVE_ITEMID, 1, counterAmount, OBJECTIVE_AMOUNT) -- You obtain <item> (X of Y)
		if counterAmount >= OBJECTIVE_AMOUNT then
			attentionMessage(player, 25225, quest:GetQuestId()) -- Objectives complete!
			quest:StartSequence(SEQ_002)
		end
	end
end

function getJournalInformation(player, quest)
	return quest:GetData():GetCounter(COUNTER_QUESTITEM), quest:GetData():GetCounter(COUNTER_QUESTITEM2), 0, 0, OBJECTIVE_AMOUNT
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_SYLBYRT
	elseif sequence == SEQ_001 then
		return MRKR_WIGHT_AREA
	elseif sequence == SEQ_002 then
		return MRKR_SYLBYRT
	elseif sequence == SEQ_003 then
		return MRKR_NICOLIAUX
	end
end