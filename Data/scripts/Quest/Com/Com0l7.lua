require("Global")
require("Quest")

--[[
Till Sea Swallows All (Com0l7, 111407). Prereq: Com0l6; level 25.
Maelstrom enlistment, twin of Com0g7. processEventGuincamStart closes the company widget itself,
so processEventGuincamEnd is never called. Walkthrough: Data/Docs/Scripts/Quest/Com/Com0l7.md.
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
