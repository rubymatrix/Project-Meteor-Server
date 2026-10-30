require("Global")
require("Quest")

--[[
What a Pirate Wants (Etc3l3, 110746). Level 15, any class; offered by Baderon.
--]]

local SEQ_000	= 0  -- Talk to Tefh Moshroca.
local SEQ_001 = 1  -- Talk to Hasthwab.

local BADERON			= 1000137
local TEFH_MOSHROCA	= 1000131
local HASTHWAB		= 1001064

local MRKR_MOSHROCA	= 11070301
local MRKR_HATHWAB	= 11070302

local RUM_ITEMID		= 11000207

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(BADERON, QFLAG_TALK)
	end

	if sequence == SEQ_000 then
		quest:SetENpc(TEFH_MOSHROCA, QFLAG_TALK)
		quest:SetENpc(BADERON)
	elseif sequence == SEQ_001 then
		quest:SetENpc(HASTHWAB, QFLAG_REWARD)
		quest:SetENpc(TEFH_MOSHROCA)
	end
end

local function offer(player, quest)
	if player:HasQuest(quest) then
		return false
	end
	local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventBADERONStart")
	if questAccepted == 1 then
		player:AcceptQuest(quest)
	end
	player:EndEvent()
	return true
end

local talk = {
	[SEQ_000] = {
		[TEFH_MOSHROCA] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_005")
			player:SendGameMessage(GetWorldMaster(), 25117, 0x20, RUM_ITEMID) -- You obtain a bottle of Radz-at-Han Reserve.
			quest:StartSequence(SEQ_001)
		end,
		[BADERON] = function(player, quest)
			if offer(player, quest) then
				return true
			end
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_000")
		end,
	},
	[SEQ_001] = {
		[HASTHWAB] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end,
		[TEFH_MOSHROCA] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_01")
		end,
	},
	always = {
		[BADERON] = offer,
	},
}

function onTalk(player, quest, npc, eventName)
	if runQuestHandler(talk, player, quest, npc) then return end
	quest:UpdateENPCs()
	player:EndEvent()
end

function getJournalInformation(player, quest)
	return quest:GetSequence() == SEQ_001 and 1 or 0
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_MOSHROCA
	elseif sequence == SEQ_001 then
		return MRKR_HATHWAB
	end
end