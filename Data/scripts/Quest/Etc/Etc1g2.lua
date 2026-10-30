require("Global")
require("Quest")

--[[

Quest Script

Name: 	A Well-Balanced Diet
Code: 	Etc1g2
Id: 	110656
Prereq: Level 25, Any DoW/DoM

]]

-- Sequence Numbers
local SEQ_000	= 0  -- Talk to Mestonnaux.
local SEQ_001	= 1  -- Kill Popoto-optos.
local SEQ_002	= 2  -- Talk to V'nabyano.

-- Actor Class Ids
local ENPC_VNABYANO 		= 1001101
local ENPC_MESTONNAUX		= 1001103
local BNPC_POPOTO_OPTO	= 2100509

-- Quest Markers
local MRKR_MESTONNAUX		= 11065601
local MRKR_OPTO_AREA		= 11065602
local MRKR_VNABYANO		= 11065604

-- Counters
local COUNTER_QUESTITEM	= 0

-- Quest Details
local OBJECTIVE_ITEMID	= 11000142
local OBJECTIVE_AMOUNT	= 8

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(ENPC_VNABYANO, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ENPC_MESTONNAUX, QFLAG_TALK)
		quest:SetENpc(ENPC_VNABYANO)
	elseif sequence == SEQ_001 then
		quest:SetENpc(ENPC_MESTONNAUX)
		quest:SetENpc(ENPC_VNABYANO)
		quest:SetENpc(BNPC_POPOTO_OPTO)
	elseif sequence == SEQ_002 then
		quest:SetENpc(ENPC_VNABYANO, QFLAG_REWARD)
		quest:SetENpc(ENPC_MESTONNAUX)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		-- Offer the quest
		[ENPC_VNABYANO] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventV_NabyanoStart", 1, OBJECTIVE_AMOUNT)
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	-- Quest Progress
	[SEQ_000] = {
		[ENPC_MESTONNAUX] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent00", 0)
			quest:StartSequence(SEQ_001)
		end,
		[ENPC_VNABYANO] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEventV_NabyanoStart00")
		end,
	},
	[SEQ_001] = {
		[ENPC_MESTONNAUX] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005", 0)
		end,
		[ENPC_VNABYANO] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_1")
		end,
	},
	--Quest Complete
	[SEQ_002] = {
		[ENPC_VNABYANO] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent05_3")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end,
		[ENPC_MESTONNAUX] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_2")
		end,
	},
}

function onTalk(player, quest, npc, eventName)
	if runQuestHandler(talk, player, quest, npc, eventName) then return end

	quest:UpdateENPCs()
	player:EndEvent()
end

function onKillBNpc(player, quest, bnpc)
	if quest:GetSequence() == SEQ_001 and bnpc == BNPC_POPOTO_OPTO then
		local counterAmount = quest:GetData():IncCounter(COUNTER_QUESTITEM)
		attentionMessage(player, 25226, OBJECTIVE_ITEMID, 1, counterAmount, OBJECTIVE_AMOUNT) -- You obtain <item> (X of Y)
		if counterAmount >= OBJECTIVE_AMOUNT then
			attentionMessage(player, 25225, quest:GetQuestId()) -- Objectives complete!
			quest:StartSequence(SEQ_002)
		end
	end
end

function getJournalInformation(player, quest)
	return quest:GetData():GetCounter(COUNTER_QUESTITEM), 0, 0, 0, OBJECTIVE_AMOUNT
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_MESTONNAUX
	elseif sequence == SEQ_001 then
		return MRKR_OPTO_AREA
	elseif sequence == SEQ_002 then
		return MRKR_VNABYANO
	end
end