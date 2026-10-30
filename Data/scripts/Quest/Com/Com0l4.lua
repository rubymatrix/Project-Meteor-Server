require("Global")
require("Quest")
require("QuestDuty")

--[[
Engineering Victory (Com0l4, 111404). After Com0l1. Level 22.

 - Offer, Guincum: processEventGUINCUMStart (1 = accepted). Guincum repeats processEvent_000_1.
 - SEQ_000 push in the canyon between upper and eastern La Noscea: join ask, the imperials
   (QuestDirectorCom0l401). Win: a corpse yields the transceiver (int2), SEQ_001, back to the spot.
 - SEQ_001 Guincum: processEvent_010 -> SEQ_002. Repeat processEvent_010_1.
 - SEQ_002 Millers' Glade, Coerthas: the engineer Ebrelnaux takes the transceiver (processEvent_015)
   -> SEQ_003. Nymiene (processEventNymiene(a3), a3 picks one of two lines) and Aergfloh stand there.
 - SEQ_003 Guincum: processEvent_020(0) (1 would skip the cutscene), rewards.
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

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if classId == GUINCUM then
		if sequence == SEQ_ACCEPT then
			local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventGUINCUMStart")
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
		elseif sequence == SEQ_001 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010")
			quest:StartSequence(SEQ_002)
		elseif sequence == SEQ_002 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_1")
		elseif sequence == SEQ_003 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_020", 0)
			local rewarded = showQuestRewards(player, quest)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest) end
			return
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_000_1")
		end
	elseif classId == EBRELNAUX and sequence == SEQ_002 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_015")
		quest:StartSequence(SEQ_003)
	elseif classId == NYMIENE then
		if sequence == SEQ_002 then
			callClientFunction(player, "delegateEvent", player, quest, "processEventNymiene", 0)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEventNymiene_01")
		end
	elseif classId == AERGFLOH then
		if sequence == SEQ_002 then
			callClientFunction(player, "delegateEvent", player, quest, "processEventAergfloh")
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEventAergfloh_01")
		end
	end

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
