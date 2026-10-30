require("Global")
require("Quest")

--[[

Quest Script

Name: 	By Fire Reborn
Code: 	Com0u7
Id: 	111807
Prereq: Com0u6 (seed_msq_uldah_20_com0u.sql). Level 25.

The official enlistment in the Immortal Flames, Ul'dah twin of Com0g7. No journal steps.
processEventAubreyStart drops recruit status in the other companies, asks, plays the join and the company
Q&A; anything but 0 or nil returned counts as joined. On joining: rank 11 (Flame Private Third Class),
rewards, complete. processEventAubreyEnd is not called. Aubrey's later pointer to Flame Lieutenant Lannis
is his own guide talk, not a quest step.

--]]

local SEQ_000	= 0	-- Enlisted; only the turn-in is left (when the seals did not fit).

local AUBREY					= 1500198
local GC_IMMORTAL_FLAMES		= 3
local RANK_PRIVATE_THIRD		= 11

-- No journal text: set the step without the "journal updated" message.
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
	-- The enlistment stands even when the seals don't fit; the turn-in waits for room.
	if rewarded then player:CompleteQuest(quest) end
end

function onTalk(player, quest, npc)
	if npc:GetActorClassId() ~= AUBREY then
		player:EndEvent()
		return
	end

	if quest:GetSequence() == SEQ_ACCEPT then
		local joined = callClientFunction(player, "delegateEvent", player, quest, "processEventAubreyStart")
		if joined ~= nil and joined ~= 0 and joined ~= false and player:AcceptQuest(quest, true) then
			player:SetGrandCompany(GC_IMMORTAL_FLAMES, RANK_PRIVATE_THIRD)
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
