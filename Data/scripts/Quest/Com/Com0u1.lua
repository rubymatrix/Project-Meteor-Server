require("Global")
require("Quest")
require("QuestDuty")

--[[
Career Opportunities (Com0u1, 111801). Immortal Flames, first quest; the Ul'dah twin of Com0g1.
Level 22.

 - Offer, Flame Lieutenant Aubrey (Hall of Flames): processEventAUBREYStart (1 = accepted). Repeat
   processEvent_000.
 - SEQ_000 Taylor at the Western Thanalan ferry docks: processEvent_010 -> SEQ_001. Repeat
   processEvent_010_1.
 - SEQ_001 Urianger SE of the docks: join ask, processEvent_020(false), then the fight with his
   familiar (QuestDirectorCom0u101). Win: processEvent_030(0) (Thancred arrives) -> SEQ_002.
 - SEQ_002 Taylor: processEvent_040 (his letter for Aubrey) -> SEQ_003. Repeat processEvent_040_1.
 - SEQ_003 Aubrey: processEvent_050, rewards, complete.
Journal: int2 = Taylor's Letter (SEQ_003), int3 = familiar beaten (SEQ_002+).
--]]

local startFight


local SEQ_000	= 0
local SEQ_001	= 1
local SEQ_002	= 2
local SEQ_003	= 3

local AUBREY					= 1500198
local TAYLOR					= 1001447
local URIANGER				= 1060009

local MRKR_TAYLOR				= 11170001
local MRKR_URIANGER			= 11170002
local MRKR_AUBREY				= 11170003

local DUTY_ZONE				= 172	-- Western Thanalan
local DUTY_AREA				= "SimpleContentCom0u101"
local DUTY_DIRECTOR			= "Quest/QuestDirectorCom0u101"
local DUTY_ANCHOR				= {-1715.0, 55.77, 92.0, -0.73}
local URIANGER_RETURN			= {-1730.0, 56.43, 110.0, 2.4}

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

	quest:SetENpc(AUBREY, sequence == SEQ_003 and QFLAG_REWARD or QFLAG_OFF)
	quest:SetENpc(TAYLOR, (sequence == SEQ_000 or sequence == SEQ_002) and QFLAG_TALK or QFLAG_OFF)
	-- isSpawned: this Urianger exists only for players on this quest.
	quest:SetENpc(URIANGER, sequence == SEQ_001 and QFLAG_TALK or QFLAG_OFF, true, false, false, sequence <= SEQ_001)
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
		elseif sequence == SEQ_003 then
			talk("processEvent_050")
			local rewarded = showQuestRewards(player, quest)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest) end
			return
		else
			talk("processEvent_000")
		end
	elseif classId == TAYLOR then
		if sequence == SEQ_000 then
			talk("processEvent_010")
			quest:StartSequence(SEQ_001)
		elseif sequence == SEQ_001 then
			talk("processEvent_010_1")
		elseif sequence == SEQ_002 then
			talk("processEvent_040")
			quest:StartSequence(SEQ_003)
		else
			talk("processEvent_040_1")
		end
	elseif classId == URIANGER and sequence == SEQ_001 then
		if callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass") == 1 then
			-- false: the cutscene fades in after the warp into the fight.
			talk("processEvent_020", false)
			startFight(player, quest)
			return
		end
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function startFight(player, quest)
	startQuestDuty(player, quest, {
		zone = DUTY_ZONE, area = DUTY_AREA, director = DUTY_DIRECTOR,
		anchor = DUTY_ANCHOR
	})
end

-- Called by QuestDirectorCom0u101 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_001 then
		return
	end

	if success then
		wait(2)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		-- Thancred arrives; 0 plays the main path.
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
		return MRKR_TAYLOR
	elseif sequence == SEQ_001 then
		return MRKR_URIANGER
	elseif sequence == SEQ_003 then
		return MRKR_AUBREY
	end
end
