require("Global")
require("Quest")

--[[

Quest Script

Name: 	Serenity, Purity, Sanctity
Code: 	Com0g7
Id: 	111607
Prereq: Com0g6 (seed_msq_gridania_03_chain.sql). Level 25.

The official enlistment in the Order of the Twin Adder. No journal text, no steps.
processEventFulkeStart drops recruit status in the other companies, asks to enlist, plays the join and
then the company Q&A. It returns the last Q&A choice after joining and 0 or nil when declined. On joining:
rank 11 (Serpent Private Third Class), rewards, complete. FulkeStart already closes the company widget,
so processEventFulkeEnd is not called.

--]]

local SEQ_000	= 0	-- Enlisted; only the turn-in is left (when the seals did not fit).

local FULKE					= 1500200
local GC_TWIN_ADDER			= 2
local RANK_PRIVATE_THIRD		= 11

-- No journal text: set the step without the "journal updated" message.
function onStart(player, quest)
	quest:StartSequenceForNpcLs(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(FULKE, QFLAG_TALK)
	else
		quest:SetENpc(FULKE, QFLAG_REWARD)
	end
end

function onTalk(player, quest, npc)
	if quest:GetSequence() == SEQ_ACCEPT and npc:GetActorClassId() == FULKE then
		local joined = callClientFunction(player, "delegateEvent", player, quest, "processEventFulkeStart")
		if joined ~= nil and joined ~= 0 and joined ~= false then
			if player:AcceptQuest(quest, true) then
				player:SetGrandCompany(GC_TWIN_ADDER, RANK_PRIVATE_THIRD)
				local rewarded = showQuestRewards(player, quest)
				player:EndEvent()
				-- The enlistment stands even when the seals don't fit; the turn-in waits for room.
				if rewarded then player:CompleteQuest(quest) end
				return
			end
		end
	elseif quest:GetSequence() ~= SEQ_ACCEPT and npc:GetActorClassId() == FULKE then
		-- Accepted but the rewards did not fit last time: pay out now.
		local rewarded = showQuestRewards(player, quest)
		player:EndEvent()
		if rewarded then player:CompleteQuest(quest) end
		return
	end
	player:EndEvent()
end

function getJournalInformation(player, quest)
	return 0
end

function getJournalMapMarkerList(player, quest)
end
