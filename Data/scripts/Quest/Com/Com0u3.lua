require("Global")
require("Quest")

--[[

Quest Script

Name: 	Burning a Hole in One's Pocket
Code: 	Com0u3
Id: 	111803
Prereq: Com0u2 (seed_msq_uldah_20_com0u.sql). Level 22.

Ul'dah twin of Com0g3: one talk with Flame Sergeant Rahz, the Hall of Flames seal sutler, accepts and
turns in the quest. processEventUSANZIStart explains what recruits may buy; talk only. Rahz is the
company shop actor, whose base script routes talk to quests (PopulaceCompanyShop).

--]]

local SEQ_000	= 0	-- Accepted; only the turn-in is left (when the rewards did not fit).

local RAHZ					= 1500201

function onStart(player, quest)
	quest:StartSequenceForNpcLs(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(RAHZ, QFLAG_TALK)
	else
		quest:SetENpc(RAHZ, QFLAG_REWARD)
	end
end

local function turnIn(player, quest)
	local rewarded = showQuestRewards(player, quest)
	player:EndEvent()
	if rewarded then player:CompleteQuest(quest) end
end

function onTalk(player, quest, npc)
	if npc:GetActorClassId() ~= RAHZ then
		player:EndEvent()
		return
	end

	if quest:GetSequence() == SEQ_ACCEPT then
		-- The ask only picks the reply (more explanation or not); either way the talk is the quest.
		callClientFunction(player, "delegateEvent", player, quest, "processEventUSANZIStart")
		if player:AcceptQuest(quest, true) then
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
