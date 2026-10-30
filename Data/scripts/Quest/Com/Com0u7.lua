require("Global")
require("Quest")

--[[
By Fire Reborn (Com0u7, 111807). Prereq: Com0u6; level 25. Immortal Flames enlistment, Ul'dah
twin of Com0g7; no journal steps. processEventAubreyStart asks, plays the join and the Q&A; anything
but 0 or nil counts as joined (rank 11, rewards, complete). processEventAubreyEnd is not called.
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
