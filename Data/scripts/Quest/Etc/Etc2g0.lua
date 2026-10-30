require("Global")
require("Quest")

--[[
A Forbidden Love (Etc2g0, 110664). Prereq: Level 30, Any DoW/DoM, Etc1g9 completed.
--]]

-- Sequence Numbers
local SEQ_000	= 0  -- Kill Mirror Roselets.
local SEQ_001	= 1  -- Talk to Lonsygg.
local SEQ_002	= 2  -- Talk to Ethelinda.

-- Actor Class Ids
local ENPC_ETHELINDA 		= 1001352
local ENPC_LONSYGG 		= 1000951
local BNPC_MIRROR_ROSELET	= 2102708

-- Quest Markers
local MRKR_ROSELET_AREA	= 11066401
local MRKR_LONSYGG		= 11066402
local MRKR_ETHELINDA		= 11066403

-- Counters
local COUNTER_QUESTITEM	= 0

-- Quest Details
local OBJECTIVE_ITEMID	= 11000161
local OBJECTIVE_AMOUNT	= 3

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(ENPC_ETHELINDA, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ENPC_ETHELINDA)
		quest:SetENpc(BNPC_MIRROR_ROSELET)
	elseif sequence == SEQ_001 then
		quest:SetENpc(ENPC_LONSYGG, QFLAG_TALK)
		quest:SetENpc(ENPC_ETHELINDA)
	elseif sequence == SEQ_002 then
		quest:SetENpc(ENPC_ETHELINDA, QFLAG_TALK)
		quest:SetENpc(ENPC_LONSYGG)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[ENPC_ETHELINDA] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventEthelindaStart")
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	[SEQ_000] = {
		[ENPC_ETHELINDA] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2")
		end,
	},
	[SEQ_001] = {
		[ENPC_LONSYGG] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000")
			quest:StartSequence(SEQ_002)
		end,
		[ENPC_ETHELINDA] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2")
		end,
	},
	[SEQ_002] = {
		[ENPC_ETHELINDA] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end,
		[ENPC_LONSYGG] = function(player, quest, npc, eventName)
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
	if quest:GetSequence() == SEQ_000 and bnpc == BNPC_MIRROR_ROSELET then
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
		return MRKR_ROSELET_AREA
	elseif sequence == SEQ_001 then
		return MRKR_LONSYGG
	elseif sequence == SEQ_002 then
		return MRKR_ETHELINDA
	end
end