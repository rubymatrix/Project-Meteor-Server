require("Global")
require("Quest")

--[[
Secrets Unearthed (Wld0u3, 110756). Level 17, any class.
--]]

-- Sequence Numbers
local SEQ_000	= 0  -- Talk to Mumukiya.
local SEQ_001	= 1  -- Talk to Abelard.

-- Actor Class Ids
local MUMUKIYA 		= 1001165
local ABELARD		 	= 1001596

-- Quest Markers
local MRKR_ABELARD	= 11130201
local MRKR_MUMUKIYA	= 11130202

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(MUMUKIYA, QFLAG_TALK)
	end

	if sequence == SEQ_000 then
		quest:SetENpc(MUMUKIYA)
		quest:SetENpc(ABELARD, QFLAG_TALK)
	elseif sequence == SEQ_001 then
		quest:SetENpc(ABELARD)
		quest:SetENpc(MUMUKIYA, QFLAG_REWARD)
	end
end

local talk = {
	[SEQ_000] = {
		[MUMUKIYA] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_000")
		end,
		[ABELARD] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010")
			quest:StartSequence(SEQ_001)
		end,
	},
	[SEQ_001] = {
		[MUMUKIYA] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_020")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end,
		[ABELARD] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_1")
			quest:StartSequence(SEQ_001)
		end,
	},
}

function onTalk(player, quest, npc, eventName)
	if npc:GetActorClassId() == MUMUKIYA and not player:HasQuest(quest) then
		local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventMUMUKIYAStart")
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

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_ABELARD
	elseif sequence == SEQ_001 then
		return MRKR_MUMUKIYA
	end
end