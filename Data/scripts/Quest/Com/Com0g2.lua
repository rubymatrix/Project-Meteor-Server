require("Global")
require("Quest")

--[[
Why Did It Have to Be Snakes (Com0g2, 111602). Prereq: Com0g1; level 22.
The seal tutorial: one talk with Fulke accepts and turns it in. The seals are the completion
reward. Recruit status has no server state: company quests before Com0g7 are offered to the
unaffiliated anyway (QuestStateManager.IsEligible).
--]]

local SEQ_000	= 0	-- Accepted; only the turn-in is left (when the rewards did not fit).

local FULKE					= 1500200

-- One-talk quest: set the step without the "journal updated" message.
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

local function turnIn(player, quest)
	local rewarded = showQuestRewards(player, quest)
	player:EndEvent()
	if rewarded then player:CompleteQuest(quest) end
end

function onTalk(player, quest, npc)
	if npc:GetActorClassId() ~= FULKE then
		player:EndEvent()
		return
	end

	if quest:GetSequence() == SEQ_ACCEPT then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventFulkeStart")
		if accepted == 1 and player:AcceptQuest(quest, true) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventFulkeEnd")
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
