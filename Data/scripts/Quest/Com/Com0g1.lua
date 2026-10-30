require("Global")
require("Quest")
require("QuestDuty")

--[[
Breaking the Seals (Com0g1, 111601). Order of the Twin Adder, first quest. Level 22.

 - Offer, Fulke (Adders' Nest): processEventStart (1 = accepted); repeat processEventStartAfter.
 - SEQ_000 Ailith at Quarrymill: processEventAilithShiren -> SEQ_001. Repeat processEventAilithShirenFree.
 - SEQ_001 push SW of Quarrymill: join ask, processEventUrianger(false), then the fight with Urianger's
   familiar (QuestDirectorCom0g101). Win: processEventUriangerMore, SEQ_002, back to Ailith.
 - SEQ_002 Ailith: processEventAilith (she hands over her oath) -> SEQ_003. Repeat processEventAilithFree.
 - SEQ_003 Fulke: processEventClear, rewards, complete.
Journal: int2 = Ailith's Oath (SEQ_003), int3 = familiar beaten (SEQ_002+).
--]]

local startFight


local SEQ_000	= 0
local SEQ_001	= 1
local SEQ_002	= 2
local SEQ_003	= 3

local FULKE					= 1500200
local AILITH					= 1001628
local URIANGER_TRIGGER		= 1090330

local MRKR_AILITH				= 11160001
local MRKR_URIANGER			= 11160002
local MRKR_FULKE				= 11160003

local DUTY_ZONE				= 154	-- South Shroud
local DUTY_AREA				= "SimpleContentCom0g101"
local DUTY_DIRECTOR			= "Quest/QuestDirectorCom0g101"
local DUTY_ANCHOR				= {1190.0, 1.0, 1083.0, 0.70}
local TRIGGER_RETURN			= {1186.0, 1.3, 1078.0, 0.70}		-- outside the push circle
local AILITH_RETURN			= {1411.0, -16.6, 933.0, 2.40}

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

	quest:SetENpc(FULKE, sequence == SEQ_003 and QFLAG_REWARD or QFLAG_OFF)
	-- isSpawned: Ailith exists only for players on this quest.
	quest:SetENpc(AILITH, (sequence == SEQ_000 or sequence == SEQ_002) and QFLAG_TALK or QFLAG_OFF, true, false, false, true)
	if sequence == SEQ_001 then
		quest:SetENpc(URIANGER_TRIGGER, QFLAG_PUSH, false, true, false, true)
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if classId == FULKE then
		if sequence == SEQ_ACCEPT then
			local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart")
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
		elseif sequence == SEQ_003 then
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear")
			local rewarded = showQuestRewards(player, quest)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest) end
			return
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter")
		end
	elseif classId == AILITH then
		if sequence == SEQ_000 then
			callClientFunction(player, "delegateEvent", player, quest, "processEventAilithShiren")
			quest:StartSequence(SEQ_001)
		elseif sequence == SEQ_001 then
			callClientFunction(player, "delegateEvent", player, quest, "processEventAilithShirenFree")
		elseif sequence == SEQ_002 then
			callClientFunction(player, "delegateEvent", player, quest, "processEventAilith")
			quest:StartSequence(SEQ_003)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEventAilithFree")
		end
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	if quest:GetSequence() == SEQ_001 and npc:GetActorClassId() == URIANGER_TRIGGER then
		if callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass") == 1 then
			-- false: the cutscene fades in after the warp into the fight.
			callClientFunction(player, "delegateEvent", player, quest, "processEventUrianger", false)
			startFight(player, quest)
			return
		end
	end
	player:EndEvent()
end

function startFight(player, quest)
	startQuestDuty(player, quest, {
		zone = DUTY_ZONE, area = DUTY_AREA, director = DUTY_DIRECTOR,
		anchor = DUTY_ANCHOR
	})
end

-- Called by QuestDirectorCom0g101 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_001 then
		return
	end

	if success then
		wait(2)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		-- Papalymo arrives; 0 plays the main path.
		callClientFunction(player, "delegateEvent", player, quest, "processEventUriangerMore", 0)
		quest:StartSequence(SEQ_002)
		player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
		player:EndEvent()
		endQuestDuty(player, duty, DUTY_ZONE, AILITH_RETURN)
		return
	end

	-- KO or everyone left: SEQ_001 kept, the push starts it again.
	if reason == "left" then
		endQuestDuty(player, duty)
		return
	end
	wait(3)
	player:SendGameMessage(GetWorldMaster(), 50012, 0x20)
	endQuestDuty(player, duty, DUTY_ZONE, TRIGGER_RETURN)
end

function getJournalInformation(player, quest)
	local sequence = quest:GetSequence()
	return (sequence == SEQ_003) and 1 or 0, (sequence >= SEQ_002) and 1 or 0
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_000 or sequence == SEQ_002 then
		return MRKR_AILITH
	elseif sequence == SEQ_001 then
		return MRKR_URIANGER
	elseif sequence == SEQ_003 then
		return MRKR_FULKE
	end
end
