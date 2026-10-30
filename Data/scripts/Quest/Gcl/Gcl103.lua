require("Global")
require("Quest")
require("QuestDuty")

--[[
Deus ex Machina (Gcl103, 111429). After Gcl102. Level 45, Maelstrom rank 11.

 - Offer: Guincum, processEventStart (1 = accepted). Repeat processEvent000_GUINCUM.
 - SEQ_000 Merlwyb at the Coral Tower (Upper Decks): processEvent000 -> SEQ_005. Hyllfyr, Eynzahr and
   Reyner stand beside her with a line each (processEvent000_HYLLFYR / _EYNZAHR / _REYNER).
 - SEQ_005 push at the Galadion Accord signing, Aleport: processEvent005_NQ(true) -> SEQ_010 and the
   fight.
 - SEQ_010 hold back one magitek vanguard (QuestDirectorGcl10301). Win: processEvent015_NQ, rewards,
   complete there; there is no turn-in function. Later pushes ask to join again.
--]]

local startDuty


local SEQ_000 = 0
local SEQ_005 = 5
local SEQ_010 = 10

local GUINCUM			= 1500199
local MERLWYB			= 1001568
local HYLLFYR			= 1000215
local EYNZAHR			= 1060024
local REYNER			= 1000140
local SITE_TRIGGER	= 1090347

local MRKR_CORAL_TOWER	= 11181201
local MRKR_MERLWYB		= 11181202
local MRKR_ALEPORT		= 11181203
local MRKR_VANGUARD		= 11181204

local DUTY_ZONE		= 129	-- Western La Noscea
local DUTY_AREA		= "SimpleContentGcl10301"
local DUTY_DIRECTOR	= "Quest/QuestDirectorGcl10301"
local DUTY_ANCHOR		= {-1395.9, 3.49, -611.8, -0.80}
local SITE_RETURN		= {-1261.2, 7.68, -651.8, -0.80}		-- outside the push circle

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
	if sequence == SEQ_COMPLETE then
		return
	end

	quest:SetENpc(GUINCUM)
	-- isSpawned: the Coral Tower actors exist only for players on this quest.
	local tower = sequence == SEQ_000
	quest:SetENpc(MERLWYB, tower and QFLAG_TALK or QFLAG_OFF, true, false, false, true)
	quest:SetENpc(HYLLFYR, QFLAG_OFF, true, false, false, true)
	quest:SetENpc(EYNZAHR, QFLAG_OFF, true, false, false, true)
	quest:SetENpc(REYNER, QFLAG_OFF, true, false, false, true)
	if sequence == SEQ_005 or sequence == SEQ_010 then
		quest:SetENpc(SITE_TRIGGER, QFLAG_PUSH, false, true, false, true)
	end
end

local function delegate(player, quest, fn, ...)
	return callClientFunction(player, "delegateEvent", player, quest, fn, ...)
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if sequence == SEQ_ACCEPT then
		if classId == GUINCUM and delegate(player, quest, "processEventStart") == 1 then
			player:EndEvent()
			player:AcceptQuest(quest)
			return
		end
		player:EndEvent()
		return
	end

	if classId == GUINCUM then
		delegate(player, quest, "processEvent000_GUINCUM")
	elseif classId == MERLWYB then
		if sequence == SEQ_000 then
			delegate(player, quest, "processEvent000")
			quest:StartSequence(SEQ_005)
		end
	elseif classId == HYLLFYR then
		delegate(player, quest, "processEvent000_HYLLFYR")
	elseif classId == EYNZAHR then
		delegate(player, quest, "processEvent000_EYNZAHR")
	elseif classId == REYNER then
		delegate(player, quest, "processEvent000_REYNER")
	end
	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence()

	if npc:GetActorClassId() == SITE_TRIGGER then
		if sequence == SEQ_005 then
			delegate(player, quest, "processEvent005_NQ", true)	-- boolean true plays it in place; 1 would not
			quest:StartSequence(SEQ_010)
			startDuty(player, quest)
			return
		elseif sequence == SEQ_010 then
			if delegate(player, quest, "contentsJoinAskInBasaClass") == 1 then
				startDuty(player, quest)
				return
			end
		end
	end
	player:EndEvent()
end

function startDuty(player, quest)
	startQuestDuty(player, quest, {
		zone = DUTY_ZONE, area = DUTY_AREA, director = DUTY_DIRECTOR,
		anchor = DUTY_ANCHOR
	})
end

-- Called by QuestDirectorGcl10301 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_010 then
		return
	end
	if success then
		wait(2)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		delegate(player, quest, "processEvent015_NQ")
		player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
		local rewarded = showQuestRewards(player, quest)
		player:EndEvent()
		if rewarded then
			player:CompleteQuest(quest)
		end
		-- A full inventory keeps SEQ_010: the site push starts the fight again.
		endQuestDuty(player, duty, DUTY_ZONE, SITE_RETURN)
		return
	end
	if reason == "left" then
		endQuestDuty(player, duty)
		return
	end
	wait(3)
	player:SendGameMessage(GetWorldMaster(), 50012, 0x20)
	endQuestDuty(player, duty, DUTY_ZONE, SITE_RETURN)
end

function getJournalInformation(player, quest)
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_000 then
		return MRKR_MERLWYB, MRKR_CORAL_TOWER
	elseif sequence == SEQ_005 then
		return MRKR_ALEPORT
	elseif sequence == SEQ_010 then
		return MRKR_ALEPORT, MRKR_VANGUARD
	end
end
