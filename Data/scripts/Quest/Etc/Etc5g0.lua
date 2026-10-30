require("Global")
require("Quest")

--[[
Waste Not Want Not (Etc5g0, 110828). Level 1, any class, after the second main scenario quest
(Man0l1, Man0g1 or Man0u1); offered by V'korolon. Pays 200 gil.
--]]

local SEQ_000 = 0  -- Talk to Pfarahr.
local SEQ_001 = 1  -- Return to V'korolon.

local VKOROLON                = 1000458
local PFARAHR                 = 1001707

local ITEM_WELL_WORN_BAG      = 11000224

local MRKR_PFARAHR            = 11082001
local MRKR_VKOROLON           = 11082002

function onStart(player, quest)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(VKOROLON, QFLAG_TALK)
	end

	if sequence == SEQ_000 then
		quest:SetENpc(VKOROLON)
		quest:SetENpc(PFARAHR, QFLAG_TALK)
	elseif sequence == SEQ_001 then
		quest:SetENpc(VKOROLON, QFLAG_TALK)
		quest:SetENpc(PFARAHR)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		other = function(player, quest)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventVKOROLONStart")
			if questAccepted == 1 then
				player:AcceptQuest(quest)
				quest:StartSequence(SEQ_000)
				wait(2)
				attentionMessage(player, 25246, ITEM_WELL_WORN_BAG, 1)
			end
			player:EndEvent()
			return true
		end,
	},
	[SEQ_000] = {
		[VKOROLON] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_000_1")
		end,
		[PFARAHR] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010")
			quest:StartSequence(SEQ_001)
		end,
	},
	[SEQ_001] = {
		[VKOROLON] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_020")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1)
			player:CompleteQuest(quest)
		end,
		[PFARAHR] = function(player, quest)
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
	if sequence == SEQ_000 then
		return ITEM_WELL_WORN_BAG
	end
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_PFARAHR
	elseif sequence == SEQ_001 then
		return MRKR_VKOROLON
	end
end



