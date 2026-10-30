require("Global")
require("Quest")

--[[
Have You Seen My Son (Etc1l7, 110640). Prereq: level 30, any DoW/DoM.
--]]

-- Sequence Numbers
local SEQ_000	= 0  -- Talk to Yuyubesu.
local SEQ_001	= 1  -- Kill Bomb Embers.
local SEQ_002	= 2  -- Return to Yuyubesu.
local SEQ_003	= 3  -- Talk to Hildie.

-- Actor Class Ids
local ENPC_IMANIA 		= 1001567
local ENPC_YUYUBESU 		= 1001166
local ENPC_HILDIE 		= 1000787
local BNPC_BOMB_EMBER		= 2101609

-- Quest Markers
local MRKR_YUYUBESU		= 11064001
local MRKR_HILDIE			= 11064002
local MRKR_BOMB_AREA		= 11064003

-- Counters
local COUNTER_QUESTITEM	= 0

-- Quest Details
local OBJECTIVE_ITEMID	= 11000151
local OBJECTIVE_AMOUNT	= 8

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(ENPC_IMANIA, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ENPC_IMANIA)
		quest:SetENpc(ENPC_YUYUBESU, QFLAG_TALK)
	elseif sequence == SEQ_001 then
		quest:SetENpc(ENPC_YUYUBESU)
		quest:SetENpc(BNPC_BOMB_EMBER)
	elseif sequence == SEQ_002 then
		quest:SetENpc(ENPC_YUYUBESU, QFLAG_TALK)
	elseif sequence == SEQ_003 then
		quest:SetENpc(ENPC_YUYUBESU)
		quest:SetENpc(ENPC_HILDIE, QFLAG_REWARD)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		-- Offer the quest
		[ENPC_IMANIA] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventImaniaStart")
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	-- Quest Progress
	[SEQ_000] = {
		[ENPC_IMANIA] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEventImaniaFree")
		end,
		[ENPC_YUYUBESU] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEventYuyubesuStart", 0, OBJECTIVE_AMOUNT)
			quest:StartSequence(SEQ_001)
		end,
	},
	--Quest Complete
	[SEQ_001] = {
		[ENPC_YUYUBESU] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEventYuyubesuFree", 0, OBJECTIVE_AMOUNT)
		end,
	},
	[SEQ_002] = {
		[ENPC_YUYUBESU] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEventYuyubesuAfter", 0, OBJECTIVE_AMOUNT)
			quest:StartSequence(SEQ_003)
		end,
	},
	[SEQ_003] = {
		[ENPC_YUYUBESU] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEventYuyubesuAfterFree")
		end,
		[ENPC_HILDIE] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEventHildie")
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
	if quest:GetSequence() == SEQ_001 and bnpc == BNPC_BOMB_EMBER then
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
		return MRKR_YUYUBESU
	elseif sequence == SEQ_001 then
		return MRKR_BOMB_AREA
	elseif sequence == SEQ_002 then
		return MRKR_YUYUBESU
	elseif sequence == SEQ_003 then
		return MRKR_HILDIE
	end
end