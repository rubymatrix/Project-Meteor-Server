require("Global")
require("Quest")
require("QuestDuty")

--[[
Like Father, Like Son (Gcu102, 111827). After Gcu101. Level 40, Immortal Flames rank 11.

 - Offer, Aubrey: processEventStart (1 = accepted). Repeat processEvent000_2.
 - SEQ_000 Ryder's Free Brigade near Camp Black Brush: Ryder processEvent005(0) hands over an item
   (int2, held until the win) -> SEQ_001.
 - SEQ_001 push at the cave NW of Camp Black Brush: join ask, the chief with two soldiers
   (QuestDirectorGcu10201). Win -> SEQ_002, back outside.
 - SEQ_002 make the surviving Garlean talk: processEvent010 asks to use the Echo; 1 -> processEvent015
   -> SEQ_003. The scene plays in place, not in the Echo's past area. The Garlean has no known class:
   the cave push stands in for him, asked right after the win and again at the cave. Ryder repeats
   processEvent010_2.
 - SEQ_003 Ryder: processEvent020 -> SEQ_004. Repeat processEvent015_2.
 - SEQ_004 Cid at the Ul'dah airship landing: processEvent025, rewards.
No markers. Not wired: the Ul'dah crowd (_000_3.._5), the unconscious Garleans (_010_3.._5), the
landing staff (_025_2.._8) and the lift scenes (processEvent_elevator_nq1F/2F; the Wellhead Lift's
actors carry the player). The item can't be used yet, so the chief keeps its buffs.
--]]

local startDuty


local SEQ_000	= 0
local SEQ_001	= 1
local SEQ_002	= 2
local SEQ_003	= 3
local SEQ_004	= 4

local AUBREY					= 1500198
local RYDER					= 1001815
local CID						= 1001572
local CAVE_TRIGGER			= 1090362

local DUTY_ZONE				= 170	-- Central Thanalan
local DUTY_AREA				= "SimpleContentGcu10201"
local DUTY_DIRECTOR			= "Quest/QuestDirectorGcu10201"
local DUTY_ANCHOR				= {50.0, 205.33, -400.0, 0.0}		-- in the cave mouth, facing in
local CAVE_RETURN				= {50.0, 203.72, -412.0, 0.0}		-- outside the push circle

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
	if sequence == SEQ_COMPLETE then
		return
	end
	quest:SetENpc(AUBREY)
	-- isSpawned: these story actors exist only for players on these steps.
	local ryderTalk = (sequence == SEQ_000 or sequence == SEQ_003)
	quest:SetENpc(RYDER, ryderTalk and QFLAG_TALK or QFLAG_OFF, true, false, false, sequence <= SEQ_003)
	if sequence == SEQ_001 or sequence == SEQ_002 then
		quest:SetENpc(CAVE_TRIGGER, QFLAG_PUSH, false, true, false, true)
	end
	quest:SetENpc(CID, sequence == SEQ_004 and QFLAG_REWARD or QFLAG_OFF, true, false, false, sequence == SEQ_004)
end

local function talk(player, quest, fn, ...)
	return callClientFunction(player, "delegateEvent", player, quest, fn, ...)
end

local function interrogate(player, quest)
	if talk(player, quest, "processEvent010") == 1 then
		talk(player, quest, "processEvent015")
		quest:StartSequence(SEQ_003)
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if classId == AUBREY then
		if sequence == SEQ_ACCEPT then
			if talk(player, quest, "processEventStart") == 1 then
				player:AcceptQuest(quest)
			end
		else
			talk(player, quest, "processEvent000_2")
		end
	elseif classId == RYDER then
		if sequence == SEQ_000 then
			talk(player, quest, "processEvent005", 0)
			quest:StartSequence(SEQ_001)
		elseif sequence == SEQ_002 then
			talk(player, quest, "processEvent010_2")
		elseif sequence == SEQ_003 then
			talk(player, quest, "processEvent020")
			quest:StartSequence(SEQ_004)
		else
			talk(player, quest, "processEvent015_2")
		end
	elseif classId == CID and sequence == SEQ_004 then
		talk(player, quest, "processEvent025")
		local rewarded = showQuestRewards(player, quest)
		player:EndEvent()
		if rewarded then player:CompleteQuest(quest) end
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence()
	if npc:GetActorClassId() == CAVE_TRIGGER then
		if sequence == SEQ_001 then
			if talk(player, quest, "contentsJoinAskInBasaClass") == 1 then
				startDuty(player, quest)
				return
			end
		elseif sequence == SEQ_002 then
			interrogate(player, quest)
		end
	end
	player:EndEvent()
	quest:UpdateENPCs()
end

function startDuty(player, quest)
	startQuestDuty(player, quest, {
		zone = DUTY_ZONE, area = DUTY_AREA, director = DUTY_DIRECTOR,
		anchor = DUTY_ANCHOR
	})
end

-- Called by QuestDirectorGcu10201 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_001 then
		return
	end
	if success then
		wait(2)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		quest:StartSequence(SEQ_002)
		interrogate(player, quest)
		player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
		player:EndEvent()
		endQuestDuty(player, duty, DUTY_ZONE, CAVE_RETURN)
		return
	end
	if reason == "left" then
		endQuestDuty(player, duty)
		return
	end
	wait(3)
	player:SendGameMessage(GetWorldMaster(), 50012, 0x20)
	endQuestDuty(player, duty, DUTY_ZONE, CAVE_RETURN)
end

function getJournalInformation(player, quest)
	local sequence = quest:GetSequence()
	return (sequence == SEQ_001) and 1 or 0
end

function getJournalMapMarkerList(player, quest)
end
