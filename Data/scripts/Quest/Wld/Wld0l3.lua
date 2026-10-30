require("Global")
require("Quest")

--[[
Sniffing Out a Profit (Wld0l3, 110773). Prereq: Level 17, Any Class.
--]]

local SEQ_000	= 0  -- Talk to Lolojo.
local SEQ_001	= 1  -- Talk to Syzfrusk.

local SYZFRUSK 	= 1001306
local LOLOJO	 	= 1001603

local MRKR_LOLOJO		= 11110201
local MRKR_SYZFRUSK	= 11110202

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(SYZFRUSK, QFLAG_TALK)
	end

	if sequence == SEQ_000 then
		quest:SetENpc(SYZFRUSK)
		quest:SetENpc(LOLOJO, QFLAG_TALK)
	elseif sequence == SEQ_001 then
		quest:SetENpc(LOLOJO)
		quest:SetENpc(SYZFRUSK, QFLAG_REWARD)
	end
end

local function offer(player, quest)
	if player:HasQuest(quest) then return false end
	local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventOffersStart")
	if questAccepted == 1 then
		player:AcceptQuest(quest)
	end
	player:EndEvent()
	return true
end

local talk = {
	[SEQ_000] = {
		[SYZFRUSK] = function(player, quest)
			if offer(player, quest) then return true end
			callClientFunction(player, "delegateEvent", player, quest, "processEventFree")
		end,
		[LOLOJO] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processlolojoEvent")
			quest:StartSequence(SEQ_001)
		end,
	},
	[SEQ_001] = {
		[SYZFRUSK] = function(player, quest)
			if offer(player, quest) then return true end
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end,
		[LOLOJO] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processlolojoEventFree")
			quest:StartSequence(SEQ_001)
		end,
	},
	always = {
		[SYZFRUSK] = offer,
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
		return MRKR_LOLOJO
	elseif sequence == SEQ_001 then
		return MRKR_SYZFRUSK
	end
end