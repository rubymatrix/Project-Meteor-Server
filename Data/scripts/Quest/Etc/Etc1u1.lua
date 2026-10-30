require("Global")
require("Quest")

--[[

Quest Script

Name: 	Sleepless in Eorzea
Code: 	Etc1u1
Id: 	110676
Prereq: Level 10, Any Class

]]

-- Sequence Numbers
local SEQ_000	= 0  -- Kill Nutgrabber Marmots.
local SEQ_001	= 1  -- Talk to Kukusi.

-- Actor Class Ids
local ENPC_KUKUSI 			= 1001463
local BNPC_NUTGRABBER_MARMOT	= 2104021

-- Quest Markers
local MRKR_NUTGRABBER_AREA	= 11067601
local MRKR_KUKUSI				= 11067602

-- Counters
local COUNTER_QUESTITEM	= 0

-- Quest Details
local OBJECTIVE_ITEMID	= 11000154
local OBJECTIVE_AMOUNT	= 8

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(ENPC_KUKUSI, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ENPC_KUKUSI)
		quest:SetENpc(BNPC_NUTGRABBER_MARMOT)
	elseif sequence == SEQ_001 then
		quest:SetENpc(ENPC_KUKUSI, QFLAG_REWARD)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		-- Offer the quest
		[ENPC_KUKUSI] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventKukusiStart", 0, OBJECTIVE_AMOUNT)
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	-- Quest Progress
	[SEQ_000] = {
		[ENPC_KUKUSI] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_3", 0, OBJECTIVE_AMOUNT)
		end,
	},
	--Quest Complete
	[SEQ_001] = {
		[ENPC_KUKUSI] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2", 1)
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
	if quest:GetSequence() == SEQ_000 and bnpc == BNPC_NUTGRABBER_MARMOT then
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
		return MRKR_NUTGRABBER_AREA
	elseif sequence == SEQ_001 then
		return MRKR_KUKUSI
	end
end