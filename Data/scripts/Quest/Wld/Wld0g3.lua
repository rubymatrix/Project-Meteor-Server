require("Global")
require("Quest")

--[[
A Bitter Oil to Swallow (Wld0g3, 110764). Prereq: Level 17, Any Class.
--]]

local SEQ_000	= 0  -- Kill Oilbugs.
local SEQ_001	= 1  -- Talk to Eugenaire.

local ENPC_EUGENAIRE 		= 1001190
local BNPC_OILBUG			= 2103910

local MRKR_EUGENAIRE		= 11120201
local MRKR_OILBUG_AREA	= 11120202

local COUNTER_QUESTITEM 	= 0

local OBJECTIVE_ITEMID	= 11000302
local OBJECTIVE_AMOUNT	= 8

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(ENPC_EUGENAIRE, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ENPC_EUGENAIRE)
		quest:SetENpc(BNPC_OILBUG)
	elseif sequence == SEQ_001 then
		quest:SetENpc(ENPC_EUGENAIRE, QFLAG_REWARD)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		-- Offer the quest
		[ENPC_EUGENAIRE] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventEugenaireStart")
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	-- Quest Progress
	[SEQ_000] = {
		[ENPC_EUGENAIRE] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_000")
		end,
	},
	--Quest Complete
	[SEQ_001] = {
		[ENPC_EUGENAIRE] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010")
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
	if quest:GetSequence() == SEQ_000 and bnpc == BNPC_OILBUG then
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
		return MRKR_OILBUG_AREA
	elseif sequence == SEQ_001 then
		return MRKR_EUGENAIRE
	end
end