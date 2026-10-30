require("Global")
require("Quest")
require("QuestDuty")

--[[
Appetite for Destruction (Com0g6, 111606). After Com0g5. Level 25.

 - Offer, Fulke: processEventStart (1 = accepted); repeat processEventStartAfter.
 - SEQ_000 Lewin at Stillglade Fane: processEventLewin(0, 0) (the named greeting) -> SEQ_001.
 - SEQ_001 push in the clearing west of Nine Ivies (East Shroud): join ask, the beasts
   (QuestDirectorCom0g601). Win: processEventNq (Cid finishes the beasts), SEQ_002, back to the clearing.
 - SEQ_002 Cid at the Fane: processEventClear(2), rewards.
 - Ambient at the Fane: Lewin (LewinAfter from SEQ_001), Concessa, Kinborow (their After versions at
   SEQ_002). O-App-Pesi, Swethyna, Norbertillon and Suzari Sorezari are not spawned for this quest.
Fulke's hint (processEventHint) is not wired.
--]]

local SEQ_000	= 0
local SEQ_001	= 1
local SEQ_002	= 2

local FULKE					= 1500200
local LEWIN					= 1000020
local CID						= 1001572
local CONCESSA				= 1000511
local KINBOROW				= 1000509
local CLEARING_TRIGGER		= 1090334

local MRKR_FANE				= 11160501
local MRKR_LEWIN				= 11160502
local MRKR_CLEARING			= 11160503
local MRKR_CID				= 11160505

local DUTY_ZONE				= 151	-- East Shroud
local DUTY_AREA				= "SimpleContentCom0g601"
local DUTY_DIRECTOR			= "Quest/QuestDirectorCom0g601"
local DUTY_ANCHOR				= {1495.0, 21.3, -772.0, 2.29}
local TRIGGER_RETURN			= {1491.0, 21.5, -768.0, 2.29}		-- outside the push circle

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(FULKE, QFLAG_TALK)
		return
	end

	quest:SetENpc(FULKE)
	-- isSpawned: Lewin and Cid exist only for players on this quest.
	quest:SetENpc(LEWIN, sequence == SEQ_000 and QFLAG_TALK or QFLAG_OFF, true, false, false, true)
	quest:SetENpc(CID, sequence == SEQ_002 and QFLAG_REWARD or QFLAG_OFF, true, false, false, true)
	quest:SetENpc(CONCESSA)
	quest:SetENpc(KINBOROW)
	if sequence == SEQ_001 then
		quest:SetENpc(CLEARING_TRIGGER, QFLAG_PUSH, false, true, false, true)
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	local after = (sequence == SEQ_002)

	if classId == FULKE then
		if sequence == SEQ_ACCEPT then
			local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart")
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter")
		end
	elseif classId == LEWIN then
		if sequence == SEQ_000 then
			callClientFunction(player, "delegateEvent", player, quest, "processEventLewin", 0, 0)
			quest:StartSequence(SEQ_001)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEventLewinAfter")
		end
	elseif classId == CID then
		if sequence == SEQ_002 then
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear", 2)
			local rewarded = showQuestRewards(player, quest)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest) end
			return
		end
	elseif classId == CONCESSA then
		callClientFunction(player, "delegateEvent", player, quest, after and "processEventConcessaAfter" or "processEventConcessa")
	elseif classId == KINBOROW then
		callClientFunction(player, "delegateEvent", player, quest, after and "processEventKinborowAfter" or "processEventKinborow")
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	if quest:GetSequence() == SEQ_001 and npc:GetActorClassId() == CLEARING_TRIGGER then
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

-- Called by QuestDirectorCom0g601 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_001 then
		return
	end

	if success then
		wait(2)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		callClientFunction(player, "delegateEvent", player, quest, "processEventNq")
		quest:StartSequence(SEQ_002)
		player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
		player:EndEvent()
		endQuestDuty(player, duty, DUTY_ZONE, TRIGGER_RETURN)
		return
	end
	if reason == "left" then
		endQuestDuty(player, duty)
		return
	end
	wait(3)
	player:SendGameMessage(GetWorldMaster(), 50012, 0x20)
	endQuestDuty(player, duty, DUTY_ZONE, TRIGGER_RETURN)
end

function getJournalInformation(player, quest)
	return 0
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_000 then
		return MRKR_LEWIN
	elseif sequence == SEQ_001 then
		return MRKR_CLEARING
	elseif sequence == SEQ_002 then
		return MRKR_CID
	end
end
