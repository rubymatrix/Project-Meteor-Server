require("Global")
require("Quest")

--[[

Quest Script

Name: 	Seals for the Whorl
Code: 	Com0l3
Id: 	111403
Prereq: Com0l2 (seed_msq_limsa_20_com0l.sql). Level 22.

One talk with the Maelstrom seal sutler, Storm Sergeant Grizzly Gnat (PopulaceCompanyShop, which hands
the talk to the quest first). processEventFHILAHCTStart asks; 1 explains the seal shop, anything else
declines. EXP-only rewards, no journal steps.

--]]

local SEQ_000	= 0	-- Accepted; only the turn-in is left (when the rewards did not fit).

local GRIZZLY_GNAT			= 1500202

function onStart(player, quest)
	quest:StartSequenceForNpcLs(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	quest:SetENpc(GRIZZLY_GNAT, sequence == SEQ_ACCEPT and QFLAG_TALK or QFLAG_REWARD)
end

local function payOut(player, quest)
	local rewarded = showQuestRewards(player, quest)
	player:EndEvent()
	if rewarded then player:CompleteQuest(quest) end
end

function onTalk(player, quest, npc)
	if npc:GetActorClassId() ~= GRIZZLY_GNAT then
		player:EndEvent()
		return
	end

	if quest:GetSequence() == SEQ_ACCEPT then
		local answer = callClientFunction(player, "delegateEvent", player, quest, "processEventFHILAHCTStart")
		if answer == 1 and player:AcceptQuest(quest, true) then
			payOut(player, quest)
			return
		end
		player:EndEvent()
		return
	end
	payOut(player, quest)
end

function getJournalInformation(player, quest)
	return 0
end

function getJournalMapMarkerList(player, quest)
end
