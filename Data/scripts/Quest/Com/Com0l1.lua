require("Global")
require("Quest")
require("QuestDuty")

--[[
The Price of Integrity (Com0l1, 111401). Maelstrom, first quest; the Limsa twin of Com0g1. Level 22.

 - Offer, Storm Lieutenant Guincum (Maelstrom Command): processEventGUINCUMStart (1 = accepted).
   Guincum repeats processEvent_000.
 - SEQ_000 Walcher at Wineport: processEvent_010 -> SEQ_001. Repeat processEvent_010_1.
 - SEQ_001 Urianger east of Wineport: join ask, processEvent_020(false), then the fight with his
   familiar (QuestDirectorCom0l101). Win: processEvent_030(0), SEQ_002.
 - SEQ_002 Walcher: processEvent_040 (the signed agreement) -> SEQ_003. Repeat processEvent_040_1.
 - SEQ_003 Guincum: processEvent_050, rewards, complete.
Who runs which function, and the step order, follow the function names and Com0g1.
Journal: int2 = the agreement (SEQ_003), int3 = familiar beaten (SEQ_002+). Markers use the 111500nn
block; the 1114nn ones are filler.
--]]

local SEQ_000	= 0
local SEQ_001	= 1
local SEQ_002	= 2
local SEQ_003	= 3

local GUINCUM					= 1500199
local WALCHER					= 1001629
local URIANGER				= 1500204

local MRKR_WALCHER			= 11150001
local MRKR_URIANGER			= 11150002
local MRKR_GUINCUM			= 11150003

local DUTY_ZONE				= 130	-- Eastern La Noscea
local DUTY_AREA				= "SimpleContentCom0l101"
local DUTY_DIRECTOR			= "Quest/QuestDirectorCom0l101"
local DUTY_ANCHOR				= {1526.7, 60.6, -1255.9, 2.47}	-- behind Urianger, facing past him
local URIANGER_RETURN			= {1526.7, 60.6, -1255.9, 2.47}

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

	quest:SetENpc(GUINCUM, sequence == SEQ_003 and QFLAG_REWARD or QFLAG_OFF)
	quest:SetENpc(WALCHER, (sequence == SEQ_000 or sequence == SEQ_002) and QFLAG_TALK or QFLAG_OFF)
	-- isSpawned: this Urianger exists only for players on this step.
	quest:SetENpc(URIANGER, sequence == SEQ_001 and QFLAG_TALK or QFLAG_OFF, true, false, false, sequence == SEQ_001)
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
		elseif sequence == SEQ_003 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_050")
			local rewarded = showQuestRewards(player, quest)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest) end
			return
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_000")
		end
	elseif classId == WALCHER then
		if sequence == SEQ_000 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010")
			quest:StartSequence(SEQ_001)
		elseif sequence == SEQ_001 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_1")
		elseif sequence == SEQ_002 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_040")
			quest:StartSequence(SEQ_003)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_040_1")
		end
	elseif classId == URIANGER and sequence == SEQ_001 then
		if callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass") == 1 then
			-- false: the cutscene fades in after the warp into the fight.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_020", false)
			startQuestDuty(player, quest, {
				zone = DUTY_ZONE, area = DUTY_AREA, director = DUTY_DIRECTOR,
				anchor = DUTY_ANCHOR
			})
			return
		end
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

-- Called by QuestDirectorCom0l101 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_001 then
		return
	end

	if success then
		wait(2)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		-- 0 plays the main path.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_030", 0)
		quest:StartSequence(SEQ_002)
		player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
		player:EndEvent()
		endQuestDuty(player, duty, DUTY_ZONE, URIANGER_RETURN)
		return
	end

	-- KO or everyone left: SEQ_001 kept, Urianger starts it again.
	if reason == "left" then
		endQuestDuty(player, duty)
		return
	end
	wait(3)
	player:SendGameMessage(GetWorldMaster(), 50012, 0x20)
	endQuestDuty(player, duty, DUTY_ZONE, URIANGER_RETURN)
end

function getJournalInformation(player, quest)
	local sequence = quest:GetSequence()
	return (sequence == SEQ_003) and 1 or 0, (sequence >= SEQ_002) and 1 or 0
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_000 or sequence == SEQ_002 then
		return MRKR_WALCHER
	elseif sequence == SEQ_001 then
		return MRKR_URIANGER
	elseif sequence == SEQ_003 then
		return MRKR_GUINCUM
	end
end
