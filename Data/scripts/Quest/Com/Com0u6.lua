require("Global")
require("Quest")
require("QuestDuty")

--[[
Know Your Enemy (Com0u6, 111806). After Com0u5. Level 25.

 - Offer, Aubrey: processEventAUBREYStart (1 = accepted). Repeat processEvent_000.
 - SEQ_000 the airship landing, the Ironworks staff: E'bolaff processEvent_005 ("who told you that
   name?") -> SEQ_001.
 - SEQ_001 push SW of Camp Horizon: join ask, the fight with Charledore (QuestDirectorCom0u601). Win:
   processEvent_005_03(0) (the cliff scene), SEQ_002, back to the spot.
 - SEQ_002 Cid at the landing: processEvent_010(0) (the main path), rewards.
Not wired: processEvent_hint, the other engineers processEvent_005_01/_02, the landing staff
_005_05.._07 and _010_01.._07, and the lift scenes processEvent_elevator_nq1F/2F/3F (the Wellhead
Lift's own actors carry the player).
--]]

local SEQ_000	= 0
local SEQ_001	= 1
local SEQ_002	= 2

local AUBREY					= 1500198
local EBOLAFF					= 1001731
local CID						= 1001572
local CHARLEDORE_TRIGGER		= 1090339

local MRKR_EBOLAFF			= 11170501
local MRKR_LANDING			= 11170502
local MRKR_CHARLEDORE			= 11170504
local MRKR_CID				= 11170505
local MRKR_LANDING_LIFT		= 11170506

local DUTY_ZONE				= 172	-- Western Thanalan
local DUTY_AREA				= "SimpleContentCom0u601"
local DUTY_DIRECTOR			= "Quest/QuestDirectorCom0u601"
local DUTY_ANCHOR				= {-1592.0, 55.72, 246.0, 0.8}
local TRIGGER_RETURN			= {-1590.0, 56.30, 244.0, 0.8}	-- outside the push circle

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(AUBREY, QFLAG_TALK)
		return
	end

	quest:SetENpc(AUBREY)
	if sequence == SEQ_001 then
		quest:SetENpc(CHARLEDORE_TRIGGER, QFLAG_PUSH, false, true, false, true)
	end
	-- isSpawned: these story actors exist only for players on this quest.
	quest:SetENpc(EBOLAFF, sequence == SEQ_000 and QFLAG_TALK or QFLAG_OFF, true, false, false, true)
	quest:SetENpc(CID, sequence == SEQ_002 and QFLAG_REWARD or QFLAG_OFF, true, false, false, true)
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	local function talk(fn, ...)
		callClientFunction(player, "delegateEvent", player, quest, fn, ...)
	end

	if classId == AUBREY then
		if sequence == SEQ_ACCEPT then
			if callClientFunction(player, "delegateEvent", player, quest, "processEventAUBREYStart") == 1 then
				player:AcceptQuest(quest)
			end
		else
			talk("processEvent_000")
		end
	elseif classId == EBOLAFF and sequence == SEQ_000 then
		talk("processEvent_005")
		quest:StartSequence(SEQ_001)
	elseif classId == CID and sequence == SEQ_002 then
		talk("processEvent_010", 0)
		local rewarded = showQuestRewards(player, quest)
		player:EndEvent()
		if rewarded then player:CompleteQuest(quest) end
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	if quest:GetSequence() == SEQ_001 and npc:GetActorClassId() == CHARLEDORE_TRIGGER then
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

-- Called by QuestDirectorCom0u601 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_001 then
		return
	end

	if success then
		wait(2)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_03", 0)
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
		return MRKR_EBOLAFF, MRKR_LANDING
	elseif sequence == SEQ_001 then
		return MRKR_CHARLEDORE
	elseif sequence == SEQ_002 then
		return MRKR_CID, MRKR_LANDING_LIFT
	end
end
