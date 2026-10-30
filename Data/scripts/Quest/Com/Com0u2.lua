require("Global")
require("Quest")

--[[
Kindling a Flame (Com0u2, 111802). Prereq: Com0u1; level 22. The seal tutorial, Ul'dah twin of Com0g2.
One talk with Flame Lieutenant Aubrey accepts and turns it in: processEventAUBREYStart returns the
ask (1 = accepted); processEventAUBREYFinal only counts the company widget up to 250. The seals are
the completion reward. Recruit status has no server state.
--]]

local SEQ_000	= 0	-- Accepted; only the turn-in is left (when the rewards did not fit).

local AUBREY					= 1500198

function onStart(player, quest)
	quest:StartSequenceForNpcLs(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(AUBREY, QFLAG_TALK)
	else
		quest:SetENpc(AUBREY, QFLAG_REWARD)
	end
end

local function turnIn(player, quest)
	local rewarded = showQuestRewards(player, quest)
	player:EndEvent()
	if rewarded then player:CompleteQuest(quest) end
end

function onTalk(player, quest, npc)
	if npc:GetActorClassId() ~= AUBREY then
		player:EndEvent()
		return
	end

	if quest:GetSequence() == SEQ_ACCEPT then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventAUBREYStart")
		if accepted == 1 and player:AcceptQuest(quest, true) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventAUBREYFinal")
			turnIn(player, quest)
			return
		end
		player:EndEvent()
		return
	end

	-- Accepted but the rewards did not fit last time: pay out now.
	turnIn(player, quest)
end

function getJournalInformation(player, quest)
	return 0
end

function getJournalMapMarkerList(player, quest)
end
