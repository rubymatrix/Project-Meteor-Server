require("Global")
require("Quest")

--[[

Quest Script

Name: 	Till Sea Swallows All
Code: 	Com0l7
Id: 	111407
Prereq: Com0l6 (seed_msq_limsa_20_com0l.sql). Level 25.

The official enlistment in the Maelstrom, twin of Com0g7. No journal text, no steps.
processEventGuincamStart shows the company widget, the join ask, the join and the company Q&A; anything
but 0 or nil returned counts as joined. On joining: rank 11 (Storm Private Third Class), rewards (1000 Storm
Seals), complete. GuincamStart already closes the widget, so processEventGuincamEnd is not called.

--]]

local SEQ_000	= 0	-- Enlisted; only the turn-in is left (when the seals did not fit).

local GUINCUM					= 1500199
local GC_MAELSTROM			= 1
local RANK_PRIVATE_THIRD		= 11

-- No journal text: set the step without the "journal updated" message.
function onStart(player, quest)
	quest:StartSequenceForNpcLs(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	quest:SetENpc(GUINCUM, sequence == SEQ_ACCEPT and QFLAG_TALK or QFLAG_REWARD)
end

local function payOut(player, quest)
	local rewarded = showQuestRewards(player, quest)
	player:EndEvent()
	-- The enlistment stands even when the seals don't fit; the turn-in waits for room.
	if rewarded then player:CompleteQuest(quest) end
end

function onTalk(player, quest, npc)
	if npc:GetActorClassId() ~= GUINCUM then
		player:EndEvent()
		return
	end

	if quest:GetSequence() == SEQ_ACCEPT then
		local joined = callClientFunction(player, "delegateEvent", player, quest, "processEventGuincamStart")
		if joined ~= nil and joined ~= 0 and joined ~= false then
			if player:AcceptQuest(quest, true) then
				player:SetGrandCompany(GC_MAELSTROM, RANK_PRIVATE_THIRD)
				payOut(player, quest)
				return
			end
		end
		player:EndEvent()
		return
	end
	-- Accepted but the rewards did not fit last time: pay out now.
	payOut(player, quest)
end

function getJournalInformation(player, quest)
	return 0
end

function getJournalMapMarkerList(player, quest)
end
