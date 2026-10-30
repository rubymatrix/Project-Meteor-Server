require("Global")
require("Quest")

--[[

Quest Script

Name: 	Adder's Nest Egg
Code: 	Com0g3
Id: 	111603
Prereq: Com0g2 (seed_msq_gridania_21_com0g_side.sql). Level 22.

One talk with Saulette in the Adders' Nest, next to the seal sutler, accepts and turns in the quest.
processEventStart explains what seals buy; the client script has no purchase call or shop widget.
Spawn: seed_msq_gridania_21_com0g_side.sql.

--]]

local SEQ_000	= 0	-- Accepted; only the turn-in is left (when the rewards did not fit).

local SAULETTE				= 1001032

function onStart(player, quest)
	quest:StartSequenceForNpcLs(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	-- c0g3_saulette spawns only for players offered or on this quest.
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(SAULETTE, QFLAG_TALK, true, false, false, true)
	else
		quest:SetENpc(SAULETTE, QFLAG_REWARD, true, false, false, true)
	end
end

local function turnIn(player, quest)
	local rewarded = showQuestRewards(player, quest)
	player:EndEvent()
	if rewarded then player:CompleteQuest(quest) end
end

function onTalk(player, quest, npc)
	if npc:GetActorClassId() ~= SAULETTE then
		player:EndEvent()
		return
	end

	if quest:GetSequence() == SEQ_ACCEPT then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart")
		if accepted == 1 and player:AcceptQuest(quest, true) then
			turnIn(player, quest)
			return
		end
		player:EndEvent()
		return
	end

	turnIn(player, quest)
end

function getJournalInformation(player, quest)
	return 0
end

function getJournalMapMarkerList(player, quest)
end
