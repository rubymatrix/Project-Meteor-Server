require("Global")
require("Quest")

--[[
A Slippery Stone (Etc3g3, 110737). Prereq: level 15, any class.
--]]

-- Sequence Numbers
SEQ_000	= 0  -- Talk to Lionnellais.
SEQ_001 = 1  -- Talk to Hasthwab.

-- Actor Class Ids
local MIOUNNE			= 1000230
local LIONNELLAIS		= 1500055
HASTHWAB		= 1001064

-- Quest Markers
local MRKR_LIONNELLAIS	= 11080301
MRKR_HATHWAB		= 11080302

-- Quest Misc
AIRSHIP_PASS_ITEMID	= 11000208

function onStart(player, quest)
	player:SendGameMessage(GetWorldMaster(), 25117, 0x20, AIRSHIP_PASS_ITEMID) -- You obtain a Airship Pass (GRD-LMS).
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(MIOUNNE, QFLAG_TALK)
	end

	if sequence == SEQ_000 then
		quest:SetENpc(LIONNELLAIS, QFLAG_TALK)
		quest:SetENpc(MIOUNNE)
	elseif sequence == SEQ_001 then
		quest:SetENpc(HASTHWAB, QFLAG_REWARD)
		quest:SetENpc(LIONNELLAIS)
	end
end

local talk = {
	[SEQ_000] = {
		[LIONNELLAIS] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_005")
			quest:StartSequence(SEQ_001)
		end,
		[MIOUNNE] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_000")
		end,
	},
	[SEQ_001] = {
		[HASTHWAB] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end,
		[LIONNELLAIS] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_01")
		end,
	},
}

function onTalk(player, quest, npc, eventName)
	if npc:GetActorClassId() == MIOUNNE and not player:HasQuest(quest) then
		local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventMIOUNNEStart")
		if questAccepted == 1 then
			player:AcceptQuest(quest)
		end
		player:EndEvent()
		return
	end

	runQuestHandler(talk, player, quest, npc)
	quest:UpdateENPCs()
	player:EndEvent()
end

function getJournalInformation(player, quest)
	return quest:GetSequence() == SEQ_000 and 1 or 0
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_LIONNELLAIS
	elseif sequence == SEQ_001 then
		return MRKR_HATHWAB
	end
end