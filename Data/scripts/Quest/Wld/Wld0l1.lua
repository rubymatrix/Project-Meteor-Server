require("Global")
require("Quest")

--[[
Trading Tongueflaps (Wld0l1, 110771). Level 5, any class; offered by Sweetnix Rosycheeks.
--]]

local SEQ_000	= 0  -- Talk to Ryssfloh.
local SEQ_001	= 1  -- Talk to Sweetnix Rosycheeks.

local SWEETNIX 		= 1001573
local RYSSFLOH	 	= 1000359

local MRKR_RYSSFLOH	= 11110001
local MRKR_SWEETNIX	= 11110002

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(SWEETNIX, QFLAG_TALK)
	end

	if sequence == SEQ_000 then
		quest:SetENpc(SWEETNIX)
		quest:SetENpc(RYSSFLOH, QFLAG_TALK)
	elseif sequence == SEQ_001 then
		quest:SetENpc(RYSSFLOH)
		quest:SetENpc(SWEETNIX, QFLAG_REWARD)
	end
end

local function offer(player, quest)
	if player:HasQuest(quest) then
		return false
	end
	local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventSweetnixStart")
	if questAccepted == 1 then
		player:AcceptQuest(quest)
	end
	player:EndEvent()
	return true
end

local talk = {
	[SEQ_000] = {
		[SWEETNIX] = function(player, quest)
			if offer(player, quest) then
				return true
			end
			callClientFunction(player, "delegateEvent", player, quest, "followEvent005")
		end,
		[RYSSFLOH] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010")
			quest:StartSequence(SEQ_001)
		end,
	},
	[SEQ_001] = {
		[SWEETNIX] = function(player, quest)
			if offer(player, quest) then
				return true
			end
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end,
		[RYSSFLOH] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "followEvent015")
			quest:StartSequence(SEQ_001)
		end,
	},
	always = {
		[SWEETNIX] = offer,
	},
}

function onTalk(player, quest, npc, eventName)
	if runQuestHandler(talk, player, quest, npc) then return end
	quest:UpdateENPCs()
	player:EndEvent()
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_RYSSFLOH
	elseif sequence == SEQ_001 then
		return MRKR_SWEETNIX
	end
end