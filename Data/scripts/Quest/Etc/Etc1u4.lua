require("Global")
require("Quest")

--[[
The Customer Comes First (Etc1u4, 110679). Level 30, any DoW/DoM.
--]]

-- Sequence Numbers
local SEQ_000	= 0  -- Kill Stormcry monsters.
local SEQ_001	= 1  -- Talk to Cahernaut.
local SEQ_002 = 2  -- Talk to Cahernaut.

-- Actor Class Ids
local ENPC_CAHERNAUT 		= 1000915
local ENPC_HALDBERK 		= 1000160
local BNPC_STORMCRY_QUARTERMASTER	= 2180210
local BNPC_STORMCRY_BOATSWAIN		= 2180211
local BNPC_STORMCRY_POWDER_MONKEY	= 2180212

-- Quest Markers
local MRKR_HALDBERK	= 11067901
local MRKR_STORMCRY	= 11067902
local MRKR_HALDBERK2	= 11067903

-- Counters
local COUNTER_QUESTITEM	= 0

-- Quest Details
local OBJECTIVE_ITEMID	= 11000156
local OBJECTIVE_AMOUNT	= 8

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(ENPC_CAHERNAUT, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ENPC_HALDBERK, QFLAG_TALK)
		quest:SetENpc(ENPC_CAHERNAUT)
	elseif sequence == SEQ_001 then
		quest:SetENpc(BNPC_STORMCRY_QUARTERMASTER)
		quest:SetENpc(BNPC_STORMCRY_BOATSWAIN)
		quest:SetENpc(BNPC_STORMCRY_POWDER_MONKEY)
		quest:SetENpc(ENPC_HALDBERK)
		quest:SetENpc(ENPC_CAHERNAUT)
	elseif sequence == SEQ_002 then
		quest:SetENpc(ENPC_HALDBERK, QFLAG_REWARD)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		-- Offer the quest
		[ENPC_CAHERNAUT] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventCahernautStart")
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	-- Quest Progress
	[SEQ_000] = {
		[ENPC_CAHERNAUT] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEventCahernautFollow")
		end,
		[ENPC_HALDBERK] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_1", OBJECTIVE_AMOUNT)
			quest:StartSequence(SEQ_001)
		end,
	},
	[SEQ_001] = {
		[ENPC_HALDBERK] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_1Follow")
		end,
		[ENPC_CAHERNAUT] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005Cahernaut")
		end,
	},
	--Quest Complete
	[SEQ_002] = {
		[ENPC_HALDBERK] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_1")
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
	if quest:GetSequence() == SEQ_001 and (bnpc == BNPC_STORMCRY_BOATSWAIN or bnpc == BNPC_STORMCRY_POWDER_MONKEY or bnpc == BNPC_STORMCRY_QUARTERMASTER) then
		local counterAmount = quest:GetData():IncCounter(COUNTER_QUESTITEM)
		attentionMessage(player, 25226, OBJECTIVE_ITEMID, 1, counterAmount, OBJECTIVE_AMOUNT) -- You obtain <item> (X of Y)
		if counterAmount >= OBJECTIVE_AMOUNT then
			attentionMessage(player, 25225, quest:GetQuestId()) -- Objectives complete!
			quest:StartSequence(SEQ_002)
		end
	end
end

function getJournalInformation(player, quest)
	return quest:GetData():GetCounter(COUNTER_QUESTITEM)
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_HALDBERK
	elseif sequence == SEQ_001 then
		return MRKR_STORMCRY
	elseif sequence == SEQ_002 then
		return MRKR_HALDBERK2
	end
end