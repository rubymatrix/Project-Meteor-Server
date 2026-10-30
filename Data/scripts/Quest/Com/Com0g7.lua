require("Global")
require("Quest")

--[[
Serenity, Purity, Sanctity (Com0g7, 111607). Prereq: Com0g6; level 25.
Enlistment in the Order of the Twin Adder: no journal text, no steps. processEventFulkeStart asks,
plays the join and the company Q&A, and closes the company widget itself (no processEventFulkeEnd).
It returns the last Q&A choice on joining, 0 or nil when declined.
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

-- Accepted but the rewards did not fit last time: pay out now.
local function payOut(player, quest)
	local rewarded = showQuestRewards(player, quest)
	player:EndEvent()
	if rewarded then player:CompleteQuest(quest) end
	return true
end

local talk = {
	[SEQ_ACCEPT] = {
		[FULKE] = function(player, quest)
			local joined = callClientFunction(player, "delegateEvent", player, quest, "processEventFulkeStart")
			if joined ~= nil and joined ~= 0 and joined ~= false then
				if player:AcceptQuest(quest, true) then
					player:SetGrandCompany(GC_TWIN_ADDER, RANK_PRIVATE_THIRD)
					local rewarded = showQuestRewards(player, quest)
					player:EndEvent()
					-- The enlistment stands even when the seals don't fit; the turn-in waits for room.
					if rewarded then player:CompleteQuest(quest) end
					return true
				end
			end
		end,
	},
	always = {
		[FULKE] = payOut,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
end

function getJournalInformation(player, quest)
	return 0
end

function getJournalMapMarkerList(player, quest)
end
