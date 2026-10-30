require("Global")
require("Quest")

--[[

Quest Script

Name: 	Ore for an Ore
Code: 	Etc2u2
Id: 	110687
Prereq: Level 28, Any DoW/DoM

]]

-- Sequence Numbers
local SEQ_000	= 0  -- Kill Iron Coblyns.
local SEQ_005	= 5  -- Talk to Pahja Zhwan.

-- Actor Class Ids
local ENPC_PAHJA_ZHWAN 	= 1001840
local BNPC_IRON_COBLYN	= 2102105

-- Quest Markers
local MRKR_COBLYN_AREA	= 11068701
local MRKR_PAHJA_ZHWAN	= 11068702

-- Counters
local COUNTER_QUESTITEM	= 0

-- Quest Details
local OBJECTIVE_ITEMID	= 11000226
local OBJECTIVE_AMOUNT	= 10

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(ENPC_PAHJA_ZHWAN, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ENPC_PAHJA_ZHWAN)
		quest:SetENpc(BNPC_IRON_COBLYN)
	elseif sequence == SEQ_005 then
		quest:SetENpc(ENPC_PAHJA_ZHWAN, QFLAG_REWARD)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		-- Offer the quest
		[ENPC_PAHJA_ZHWAN] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventPAHJAZHWANStart")
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	-- Quest Progress
	[SEQ_000] = {
		[ENPC_PAHJA_ZHWAN] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000")
		end,
	},
	--Quest Complete
	[SEQ_005] = {
		[ENPC_PAHJA_ZHWAN] = function(player, quest, npc, eventName)
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
	if quest:GetSequence() == SEQ_000 and bnpc == BNPC_IRON_COBLYN then
		local counterAmount = quest:GetData():IncCounter(COUNTER_QUESTITEM)
		attentionMessage(player, 25226, OBJECTIVE_ITEMID, 1, counterAmount, OBJECTIVE_AMOUNT) -- You obtain <item> (X of Y)
		if counterAmount >= OBJECTIVE_AMOUNT then
			attentionMessage(player, 25225, quest:GetQuestId()) -- Objectives complete!
			quest:StartSequence(SEQ_005)
		end
	end
end

function getJournalInformation(player, quest)
	return quest:GetData():GetCounter(COUNTER_QUESTITEM)
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_COBLYN_AREA
	elseif sequence == SEQ_005 then
		return MRKR_PAHJA_ZHWAN
	end
end