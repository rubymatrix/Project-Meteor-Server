require("Global")
require("Quest")

--[[
The Ink Thief (Etc5l0, 110838). Prereq: the second MSQ quest (Man0l1, Man0g1 or Man0u1); any class, level 1.
--]]

local SEQ_000 = 0  -- Talk to Sweetnix.
local SEQ_001 = 1  -- Return to Mytesyn.

local MYTESYN                 = 1000167
local SWEETNIX                = 1001573

local ITEM_INKWELL            = 11000223

local MRKR_SWEETNIX           = 11072001
local MRKR_MYTESYN            = 11072002


function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(MYTESYN, QFLAG_TALK)
	end

	if sequence == SEQ_000 then
		quest:SetENpc(MYTESYN)
		quest:SetENpc(SWEETNIX, QFLAG_TALK)
	elseif sequence == SEQ_001 then
		quest:SetENpc(MYTESYN, QFLAG_REWARD)
		quest:SetENpc(SWEETNIX)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		other = function(player, quest)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventMYTESYNStart")
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	[SEQ_000] = {
		[MYTESYN] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_000_1")
		end,
		[SWEETNIX] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010")
			attentionMessage(player, 25246, ITEM_INKWELL, 1)
			attentionMessage(player, 25225, quest:GetQuestId())
			quest:StartSequence(SEQ_001)
		end,
	},
	[SEQ_001] = {
		[MYTESYN] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_020")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200,1 ,1)
			player:CompleteQuest(quest)
		end,
		[SWEETNIX] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_1")
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

function getJournalInformation(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_001 then
		return ITEM_INKWELL
	end
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_SWEETNIX
	elseif sequence == SEQ_001 then
		return MRKR_MYTESYN
	end
end



