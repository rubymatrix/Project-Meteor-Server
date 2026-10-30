require("Global")
require("Quest")
require("QuestDuty")

--[[
An Officer and a Wise Man (Com0l5, 111405). Prereq: Com0l4; level 25.
The Bridge is not a server zone: its ceremony is staged in the stateroom private area.
Walkthrough: Data/Docs/Scripts/Quest/Com/Com0l5.md.
--]]

local SEQ_000	= 0
local SEQ_001	= 1
local SEQ_002	= 2
local SEQ_003	= 3

local GUINCUM					= 1500199
local MERLWYB					= 1001568
local URIANGER				= 1500204
local ZANTHAEL				= 1000351
local YSHTOLA					= 1000001
local CLEARING_TRIGGER		= 1090359
local HALL_EXIT				= 1090352

local MRKR_CLEARING			= 11150401
local MRKR_MERLWYB			= 11150402
local MRKR_URIANGER			= 11150403
local MRKR_ZANTHAEL			= 11150404
local MRKR_YSHTOLA			= 11150405

local HALL_ZONE				= 133
local HALL_PA					= "PrivateAreaMasterPast"
local HALL_PA_TYPE			= 61
local HALL_ARRIVAL			= {-440.0, 21.0, 176.0, 1.9}
local LIFT_RETURN				= {-440.5, 21.0, 174.0, -2.6}

local DUTY_ZONE				= 130	-- Eastern La Noscea
local DUTY_AREA				= "SimpleContentCom0l501"
local DUTY_DIRECTOR			= "Quest/QuestDirectorCom0l501"
local DUTY_ANCHOR				= {665.0, 49.70, -602.0, 2.36}
local CLEARING_RETURN			= {663.27, 49.80, -600.46, 2.36}	-- outside the push circle

local FLAG_MERLWYB			= 0
local FLAG_URIANGER			= 1

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

	quest:SetENpc(GUINCUM, QFLAG_OFF)
	if sequence == SEQ_000 then
		quest:SetENpc(CLEARING_TRIGGER, QFLAG_PUSH, false, true, false, true)
	end
	local merlwyb = sequence == SEQ_001 and not questFlag(quest, FLAG_MERLWYB)
	local urianger = sequence == SEQ_001 and not questFlag(quest, FLAG_URIANGER)
	quest:SetENpc(MERLWYB, merlwyb and QFLAG_TALK or QFLAG_OFF, true, false, false, true)
	quest:SetENpc(URIANGER, urianger and QFLAG_TALK or QFLAG_OFF, true, false, false, true)
	quest:SetENpc(ZANTHAEL, sequence == SEQ_002 and QFLAG_TALK or QFLAG_OFF)
	quest:SetENpc(YSHTOLA, sequence == SEQ_003 and QFLAG_REWARD or QFLAG_OFF, true, false, false, true)
	quest:SetENpc(HALL_EXIT, QFLAG_OFF, false, true, false, true)
end

local function councilTalk(player, quest, npc)
	local classId = npc:GetActorClassId()
	local flag = (classId == MERLWYB) and FLAG_MERLWYB or FLAG_URIANGER
	local fn = (classId == MERLWYB) and "processEvent_005_merlwyb" or "processEvent_005_uri"
	if quest:GetSequence() == SEQ_001 and not questFlag(quest, flag) then
		callClientFunction(player, "delegateEvent", player, quest, fn)
		setQuestFlag(quest, flag)
		if questFlag(quest, FLAG_MERLWYB) and questFlag(quest, FLAG_URIANGER) then
			quest:StartSequence(SEQ_002)
		end
	else
		callClientFunction(player, "delegateEvent", player, quest, fn .. "_01")
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
	[SEQ_002] = {
		[ZANTHAEL] = function(player, quest)
			if callClientFunction(player, "delegateEvent", player, quest, "processEvent_elevator_nq1", 0) == 1 then
				quest:StartSequence(SEQ_003)
				player:EndEvent()
				local p = HALL_ARRIVAL
				GetWorldManager():DoZoneChange(player, HALL_ZONE, HALL_PA, HALL_PA_TYPE, 15, p[1], p[2], p[3], p[4])
				return true
			end
		end,
	},
	[SEQ_003] = {
		[YSHTOLA] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_015", 0)
			local rewarded = showQuestRewards(player, quest)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest) end
			return true
		end,
	},
	always = {
		[GUINCUM] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_000")
		end,
		[MERLWYB] = councilTalk,
		[URIANGER] = councilTalk,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if classId == CLEARING_TRIGGER and sequence == SEQ_000 then
		if callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass") == 1 then
			startQuestDuty(player, quest, {
				zone = DUTY_ZONE, area = DUTY_AREA, director = DUTY_DIRECTOR,
				anchor = DUTY_ANCHOR
			})
			return
		end
	elseif classId == HALL_EXIT then
		if callClientFunction(player, "delegateEvent", player, quest, "processEventExit") == 1 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_elevator_nq2")
			player:EndEvent()
			local p = LIFT_RETURN
			GetWorldManager():DoZoneChange(player, HALL_ZONE, nil, 0, 15, p[1], p[2], p[3], p[4])
			return
		end
	end
	player:EndEvent()
end

-- Called by QuestDirectorCom0l501 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_000 then
		return
	end

	if success then
		wait(2)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010")
		quest:StartSequence(SEQ_001)
		player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
		player:EndEvent()
		endQuestDuty(player, duty, DUTY_ZONE, CLEARING_RETURN)
		return
	end
	if reason == "left" then
		endQuestDuty(player, duty)
		return
	end
	wait(3)
	player:SendGameMessage(GetWorldMaster(), 50012, 0x20)
	endQuestDuty(player, duty, DUTY_ZONE, CLEARING_RETURN)
end

function getJournalInformation(player, quest)
	return 0
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_000 then
		return MRKR_CLEARING
	elseif sequence == SEQ_001 then
		return MRKR_MERLWYB, MRKR_URIANGER
	elseif sequence == SEQ_002 then
		return MRKR_ZANTHAEL
	elseif sequence == SEQ_003 then
		return MRKR_YSHTOLA
	end
end
