require("Global")
require("Quest")

--[[

Quest Script

Name: 	Testing the Waters
Code: 	Com0l2
Id: 	111402
Prereq: Com0l1 (seed_msq_limsa_20_com0l.sql). Level 22.

The seal tutorial: one talk with Storm Lieutenant Guincum. processEventGUINCUMStart asks; 1 runs the
tutorial, anything else declines. processEventGUINCUMEnd only shows the 250 Storm Seals the rewards pay.
No recruit status is set: the server has one company slot, and SetGrandCompany would drop the other
companies' offers. No journal steps.

--]]

local SEQ_000	= 0	-- Accepted; only the turn-in is left (when the seals did not fit).

local GUINCUM					= 1500199

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
	if rewarded then
		callClientFunction(player, "delegateEvent", player, quest, "processEventGUINCUMEnd")
	end
	player:EndEvent()
	if rewarded then player:CompleteQuest(quest) end
end

function onTalk(player, quest, npc)
	if npc:GetActorClassId() ~= GUINCUM then
		player:EndEvent()
		return
	end

	if quest:GetSequence() == SEQ_ACCEPT then
		local answer = callClientFunction(player, "delegateEvent", player, quest, "processEventGUINCUMStart")
		if answer == 1 and player:AcceptQuest(quest, true) then
			payOut(player, quest)
			return
		end
		player:EndEvent()
		return
	end
	-- Accepted but the seals did not fit last time.
	payOut(player, quest)
end

function getJournalInformation(player, quest)
	return 0
end

function getJournalMapMarkerList(player, quest)
end
