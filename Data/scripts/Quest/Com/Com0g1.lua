require("Global")
require("Quest")
require("QuestDuty")

--[[
Breaking the Seals (Com0g1, 111601). Order of the Twin Adder, first quest. Level 22.
Walkthrough: Data/Docs/Scripts/Quest/Com/Com0g1.md.
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

local function say(event)
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
		[AILITH] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEventAilithShiren")
			quest:StartSequence(SEQ_001)
		end,
	},
	[SEQ_001] = {
		[AILITH] = say("processEventAilithShirenFree"),
	},
	[SEQ_002] = {
		[AILITH] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEventAilith")
			quest:StartSequence(SEQ_003)
		end,
	},
	[SEQ_003] = {
		[FULKE] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear")
			local rewarded = showQuestRewards(player, quest)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest) end
			return true
		end,
	},
	always = {
		[FULKE] = say("processEventStartAfter"),
		[AILITH] = say("processEventAilithFree"),
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
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
