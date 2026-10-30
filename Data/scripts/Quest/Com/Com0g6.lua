require("Global")
require("Quest")
require("QuestDuty")

--[[
Appetite for Destruction (Com0g6, 111606). Prereq: Their Finest Hour (Com0g5); level 25.
The beasts west of Nine Ivies are a quest duty (QuestDirectorCom0g601).
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

local function delegate(event)
	return function(player, quest)
		callClientFunction(player, "delegateEvent", player, quest, event)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[FULKE] = function(player, quest)
			local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart")
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
		end,
	},
	[SEQ_000] = {
		[LEWIN] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEventLewin", 0, 0)
			quest:StartSequence(SEQ_001)
		end,
	},
	[SEQ_002] = {
		[CID] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear", 2)
			local rewarded = showQuestRewards(player, quest)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest) end
			return true
		end,
		[CONCESSA] = delegate("processEventConcessaAfter"),
		[KINBOROW] = delegate("processEventKinborowAfter"),
	},
	always = {
		[FULKE] = delegate("processEventStartAfter"),
		[LEWIN] = delegate("processEventLewinAfter"),
		[CONCESSA] = delegate("processEventConcessa"),
		[KINBOROW] = delegate("processEventKinborow"),
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
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
