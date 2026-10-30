require("Global")
require("Quest")

--[[

Quest Script

Name: 	Say it with Wolf Tails
Code: 	Etc1g8
Id: 	110662
Prereq: Level 30, Any DoW/DoM, Etc1l7 complete

]]

-- Sequence Numbers
local SEQ_000	= 0  -- Kill Gnawing Gnats.
local SEQ_001	= 1  -- Talk to Francis.
local SEQ_002	= 2  -- Talk to Imania.

-- Actor Class Ids
local ENPC_FRANCIS 		= 1000566
local ENPC_IMANIA 		= 1001567
local BNPC_GNAWING_GNATS	= 2100609

-- Quest Markers
local MRKR_FRANCIS		= 11066201
local MRKR_IMANIA			= 11066202
local MRKR_GNAT_AREA		= 11066203

-- Counters
local COUNTER_KILLS		= 0

-- Quest Details
local QUESTITEM_WOLFTAIL	= 11000152
local OBJECTIVE_AMOUNT	= 8

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(ENPC_FRANCIS, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ENPC_FRANCIS)
		quest:SetENpc(BNPC_GNAWING_GNATS)
	elseif sequence == SEQ_001 then
		quest:SetENpc(ENPC_FRANCIS, QFLAG_TALK)
	elseif sequence == SEQ_002 then
		quest:SetENpc(ENPC_IMANIA, QFLAG_REWARD)
		quest:SetENpc(ENPC_FRANCIS)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		-- Offer the quest
		[ENPC_FRANCIS] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventFrancisStart1g8", OBJECTIVE_AMOUNT)
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	-- Quest Progress
	[SEQ_000] = {
		[ENPC_FRANCIS] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEventFrancisFree", 0, OBJECTIVE_AMOUNT)
		end,
	},
	[SEQ_001] = {
		[ENPC_FRANCIS] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEventFrancisAfter", 0, OBJECTIVE_AMOUNT)
			attentionMessage(player, 25246, QUESTITEM_WOLFTAIL, 1) -- You obtain <item>
			quest:StartSequence(SEQ_002)
		end,
	},
	--Quest Complete
	[SEQ_002] = {
		[ENPC_IMANIA] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEventImania")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end,
		[ENPC_FRANCIS] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEventFrancisAfterFree", 0, OBJECTIVE_AMOUNT)
		end,
	},
}

function onTalk(player, quest, npc, eventName)
	if runQuestHandler(talk, player, quest, npc, eventName) then return end

	quest:UpdateENPCs()
	player:EndEvent()
end

function onKillBNpc(player, quest, bnpc)
	if quest:GetSequence() == SEQ_000 and bnpc == BNPC_GNAWING_GNATS then
		local counterAmount = quest:GetData():IncCounter(COUNTER_KILLS)
		attentionMessage(player, 50041, 3100611, counterAmount, OBJECTIVE_AMOUNT) -- The <dispName> has been defeated. (X of Y)
		if counterAmount >= OBJECTIVE_AMOUNT then
			attentionMessage(player, 25225, quest:GetQuestId()) -- Objectives complete!
			quest:StartSequence(SEQ_001)
		end
	end
end

function getJournalInformation(player, quest)
	return quest:GetSequence() == SEQ_002 and 1 or 0, 0, 0, 0, OBJECTIVE_AMOUNT
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_GNAT_AREA
	elseif sequence == SEQ_001 then
		return MRKR_FRANCIS
	elseif sequence == SEQ_002 then
		return MRKR_IMANIA
	end
end