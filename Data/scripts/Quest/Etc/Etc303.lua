require("Global")
require("Quest")

--[[
Call of Booty (Etc303, 110810). Prereq: Etc3l3, Etc3g3 or Etc3u3; level 15, any class.
--]]

local SEQ_000	= 0  -- Talk to F'ongho.

local HASTHWAB	= 1001064
local FONGHO		= 1000367

local MRKR_FONGHO	= 11213201

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(HASTHWAB, QFLAG_TALK)
	end

	if sequence == SEQ_000 then
		quest:SetENpc(FONGHO, QFLAG_REWARD)
		quest:SetENpc(HASTHWAB)
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc:GetActorClassId()
	local seq = quest:GetSequence()

	if npcClassId == HASTHWAB and not player:HasQuest(quest) then
		local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventHASTHWABStart")
		if questAccepted == 1 then
			player:AcceptQuest(quest)
		end
		player:EndEvent()
		return
	end

	if seq == SEQ_000 then
		if npcClassId == FONGHO then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_005")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		elseif npcClassId == HASTHWAB then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_000")
		end
	end

	quest:UpdateENPCs()
	player:EndEvent()
end

function getJournalMapMarkerList(player, quest)
	return MRKR_FONGHO
end