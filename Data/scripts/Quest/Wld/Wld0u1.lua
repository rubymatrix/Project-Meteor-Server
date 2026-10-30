require("Global")
require("Quest")

--[[
Of Archons and Muses (Wld0u1, 110753). Prereq: Level 10, Any Class.
--]]

-- Sequence Numbers
local SEQ_000	= 0  -- Talk to Lyngwaek.
local SEQ_001	= 1  -- Talk to Tyago Moui.

-- Actor Class Ids
local TYAGO_MOUI	 	= 1001203
local LYNGWAEK 		= 1000647

-- Quest Markers
local MRKR_LYNGWAEK	= 11130001
local MRKR_TYAGO_MOUI	= 11130002

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(TYAGO_MOUI, QFLAG_TALK)
	end

	if sequence == SEQ_000 then
		quest:SetENpc(TYAGO_MOUI)
		quest:SetENpc(LYNGWAEK, QFLAG_TALK)
	elseif sequence == SEQ_001 then
		quest:SetENpc(LYNGWAEK)
		quest:SetENpc(TYAGO_MOUI, QFLAG_REWARD)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[TYAGO_MOUI] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventTyagomouiStart")
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	[SEQ_000] = {
		[TYAGO_MOUI] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "followEvent005")
		end,
		[LYNGWAEK] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010")
			quest:StartSequence(SEQ_001)
		end,
	},
	[SEQ_001] = {
		[TYAGO_MOUI] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end,
		[LYNGWAEK] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "followEvent015")
			quest:StartSequence(SEQ_001)
		end,
	},
}

function onTalk(player, quest, npc, eventName)
	if runQuestHandler(talk, player, quest, npc, eventName) then return end
	quest:UpdateENPCs()
	player:EndEvent()
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_LYNGWAEK
	elseif sequence == SEQ_001 then
		return MRKR_TYAGO_MOUI
	end
end