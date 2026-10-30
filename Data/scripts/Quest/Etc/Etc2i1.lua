require("Global")
require("Quest")

--[[

Quest Script

Name: 	A Hypocritical Oath
Code: 	Etc2i1
Id: 	110707
Prereq: Level 25, Any DoW/DoM

]]

-- Sequence Numbers
local SEQ_000	= 0  -- Kill Antelope Does.
local SEQ_001	= 1  -- Talk to Arscelin.

-- Actor Class Ids
local ENPC_ARSCELIN 		= 1001574
local BNPC_ANTELOPE_DOES	= 2100314

-- Quest Markers
local MRKR_ARSCELIN		= 11102001
local MRKR_ANTELOPE_AREA	= 11102002

-- Counters
local COUNTER_QUESTITEM	= 0

-- Quest Details
local OBJECTIVE_ITEMID	= 11000177
local OBJECTIVE_AMOUNT	= 5

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(ENPC_ARSCELIN, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ENPC_ARSCELIN)
		quest:SetENpc(BNPC_ANTELOPE_DOES)
	elseif sequence == SEQ_001 then
		quest:SetENpc(ENPC_ARSCELIN, QFLAG_REWARD)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		-- Offer the quest
		[ENPC_ARSCELIN] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventArscelinStart")
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	-- Quest Progress
	[SEQ_000] = {
		[ENPC_ARSCELIN] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000")
		end,
	},
	--Quest Complete
	[SEQ_001] = {
		[ENPC_ARSCELIN] = function(player, quest, npc, eventName)
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
	if quest:GetSequence() == SEQ_000 and bnpc == BNPC_ANTELOPE_DOES then
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
		return MRKR_ANTELOPE_AREA
	elseif sequence == SEQ_001 then
		return MRKR_ARSCELIN
	end
end