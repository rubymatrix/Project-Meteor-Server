require("Global")
require("Quest")
require("QuestDuty")

--[[
Engineering Victory (Com0l4, 111404). Prereq: Com0l1; level 22.
A fight with the imperials in the canyon wins a transceiver for the engineer at Millers' Glade.
Walkthrough: Data/Docs/Scripts/Quest/Com/Com0l4.md.
--]]

local SEQ_000	= 0
local SEQ_001	= 1
local SEQ_002	= 2
local SEQ_003	= 3

local GUINCUM					= 1500199
local EBRELNAUX				= 1060011
local NYMIENE					= 1001578
local AERGFLOH				= 1001579
local IMPERIAL_TRIGGER		= 1090345

local MRKR_CANYON				= 11150301
local MRKR_GUINCUM			= 11150302
local MRKR_EBRELNAUX			= 11150303	-- placeholder position; MRKR_MILLERS_GLADE is used
local MRKR_MILLERS_GLADE		= 11150304

local DUTY_ZONE				= 130	-- Eastern La Noscea
local DUTY_AREA				= "SimpleContentCom0l401"
local DUTY_DIRECTOR			= "Quest/QuestDirectorCom0l401"
local DUTY_ANCHOR				= {979.9, 64.83, -1562.7, 2.36}
local TRIGGER_RETURN			= {977.9, 65.08, -1560.7, 2.36}	-- outside the push circle

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(GUINCUM, QFLAG_TALK)
		return
	end

	local guincumFlag = QFLAG_OFF
	if sequence == SEQ_001 then
		guincumFlag = QFLAG_TALK
	elseif sequence == SEQ_003 then
		guincumFlag = QFLAG_REWARD
	end
	quest:SetENpc(GUINCUM, guincumFlag)
	-- isSpawned: these story actors exist only for players on this quest.
	quest:SetENpc(EBRELNAUX, sequence == SEQ_002 and QFLAG_TALK or QFLAG_OFF, true, false, false, true)
	quest:SetENpc(NYMIENE, QFLAG_OFF, true, false, false, true)
	quest:SetENpc(AERGFLOH, QFLAG_OFF, true, false, false, true)
	if sequence == SEQ_000 then
		quest:SetENpc(IMPERIAL_TRIGGER, QFLAG_PUSH, false, true, false, true)
	end
end

local function playEvent(name, ...)
	local args = { ... }
	return function(player, quest)
		callClientFunction(player, "delegateEvent", player, quest, name, unpack(args))
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[GUINCUM] = function(player, quest)
			local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventGUINCUMStart")
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
		end,
	},
	[SEQ_001] = {
		[GUINCUM] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010")
			quest:StartSequence(SEQ_002)
		end,
	},
	[SEQ_002] = {
		[GUINCUM] = playEvent("processEvent_010_1"),
		[EBRELNAUX] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_015")
			quest:StartSequence(SEQ_003)
		end,
		[NYMIENE] = playEvent("processEventNymiene", 0),
		[AERGFLOH] = playEvent("processEventAergfloh"),
	},
	[SEQ_003] = {
		[GUINCUM] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_020", 0)
			local rewarded = showQuestRewards(player, quest)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest) end
			return true
		end,
	},
	always = {
		[GUINCUM] = playEvent("processEvent_000_1"),
		[NYMIENE] = playEvent("processEventNymiene_01"),
		[AERGFLOH] = playEvent("processEventAergfloh_01"),
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	if quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == IMPERIAL_TRIGGER then
		if callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass") == 1 then
			startQuestDuty(player, quest, {
				zone = DUTY_ZONE, area = DUTY_AREA, director = DUTY_DIRECTOR,
				anchor = DUTY_ANCHOR
			})
			return
		end
	end
	player:EndEvent()
end

-- Called by QuestDirectorCom0l401 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_000 then
		return
	end

	if success then
		wait(2)
		quest:StartSequence(SEQ_001)
	elseif reason == "left" then
		endQuestDuty(player, duty)
		return
	else
		wait(3)
	end
	player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
	endQuestDuty(player, duty, DUTY_ZONE, TRIGGER_RETURN)
end

function getJournalInformation(player, quest)
	local sequence = quest:GetSequence()
	return (sequence == SEQ_001 or sequence == SEQ_002) and 1 or 0
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_000 then
		return MRKR_CANYON
	elseif sequence == SEQ_001 or sequence == SEQ_003 then
		return MRKR_GUINCUM
	elseif sequence == SEQ_002 then
		return MRKR_MILLERS_GLADE
	end
end
