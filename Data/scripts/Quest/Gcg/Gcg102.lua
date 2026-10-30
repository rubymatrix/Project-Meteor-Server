require("Global")
require("Quest")
require("QuestDuty")

--[[
Two Vans are Better than One (Gcg102, 111627). After Gcg101. Level 40, Twin Adder rank 11.

 - Offer: Fulke (Adders' Nest), processEventStart (1 = accepted). Repeat processEventStartAfter.
 - SEQ_000 Serpent Commander Flutaint at the Toro-Moy Battlewarrens (East Shroud):
   processEventQuinquerol(0) hands over the Mist Emitter (int2, held to the end) -> SEQ_001. The
   fallen party talks: Pfrymloef, Arthur, Yarborough. Talloak has no actor class: left out.
 - SEQ_001 Flutaint asks to go: three Garlean soldiers ahead of the warrens (QuestDirectorGcg10201).
   Win -> SEQ_002, back at the warrens. The Mist Emitter can't be used yet; the fight has no gas.
 - SEQ_002 Pfrymloef: processEventPfrymloefNQF asks to use the Echo. Yes -> processEventPfrymloefNQ
   -> SEQ_003. The scene plays in place, not in the Echo's past area.
 - SEQ_003 Flutaint processEventQuinquerolNQA -> SEQ_004.
 - SEQ_004 at the Gridania airship landing: Ebrelnaux processEventEbrelnaux -> SEQ_005; Cid
   processEventCid (busy), Bardo, Lionnellais.
 - SEQ_005 Cid processEventClear, rewards.
No quest markers exist for this quest.
--]]

local startDuty


local SEQ_000 = 0
local SEQ_001 = 1
local SEQ_002 = 2
local SEQ_003 = 3
local SEQ_004 = 4
local SEQ_005 = 5

local FULKE		= 1500200
local FLUTAINT	= 1001809	-- the client calls him Quinquerol
local YARBOROUGH	= 1001808	-- the client names this one Vevina
local ARTHUR		= 1001734
local PFRYMLOEF	= 1001812
local CID			= 1001572
local EBRELNAUX	= 1060011
local BARDO		= 1001580
local LIONNELLAIS	= 1500055

local DUTY_ZONE		= 151	-- East Shroud
local DUTY_AREA		= "SimpleContentGcg10201"
local DUTY_DIRECTOR	= "Quest/QuestDirectorGcg10201"
local DUTY_ANCHOR		= {1644.0, 45.1, -796.0, -1.2}
local SITE_RETURN		= {1644.0, 45.1, -796.0, -1.2}

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
	if sequence == SEQ_COMPLETE then
		return
	end
	quest:SetENpc(FULKE)
	if sequence <= SEQ_003 then
		local flutaintTalk = (sequence == SEQ_000 or sequence == SEQ_001 or sequence == SEQ_003)
		-- isSpawned: these story actors exist only for players on this quest.
		quest:SetENpc(FLUTAINT, flutaintTalk and QFLAG_TALK or QFLAG_OFF, true, false, false, true)
		quest:SetENpc(PFRYMLOEF, sequence == SEQ_002 and QFLAG_TALK or QFLAG_OFF, true, false, false, true)
		quest:SetENpc(ARTHUR, QFLAG_OFF, true, false, false, true)
		quest:SetENpc(YARBOROUGH, QFLAG_OFF, true, false, false, true)
	else
		quest:SetENpc(EBRELNAUX, sequence == SEQ_004 and QFLAG_TALK or QFLAG_OFF, true, false, false, true)
		quest:SetENpc(CID, sequence == SEQ_005 and QFLAG_REWARD or QFLAG_OFF, true, false, false, true)
		quest:SetENpc(BARDO, QFLAG_OFF, true, false, false, true)
		quest:SetENpc(LIONNELLAIS)
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if sequence == SEQ_ACCEPT then
		if classId == FULKE then
			local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart") == 1
			player:EndEvent()
			if accepted then
				player:AcceptQuest(quest)
			end
			return
		end
		player:EndEvent()
		return
	end

	local function talk(fn, ...)
		callClientFunction(player, "delegateEvent", player, quest, fn, ...)
	end

	if classId == FULKE then
		talk("processEventStartAfter")
	elseif classId == FLUTAINT then
		if sequence == SEQ_000 then
			-- 0 plays the main path.
			talk("processEventQuinquerol", 0)
			quest:StartSequence(SEQ_001)
		elseif sequence == SEQ_001 then
			if callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass") == 1 then
				startDuty(player, quest)
				return
			end
		elseif sequence == SEQ_002 then
			talk("processEventQuinquerolNQF")
		elseif sequence == SEQ_003 then
			talk("processEventQuinquerolNQA")
			quest:StartSequence(SEQ_004)
		else
			talk("processEventQuinquerolFragC")
		end
	elseif classId == PFRYMLOEF then
		if sequence == SEQ_002 then
			local r = callClientFunction(player, "delegateEvent", player, quest, "processEventPfrymloefNQF")
			if r == 1 or r == true then
				talk("processEventPfrymloefNQ")
				quest:StartSequence(SEQ_003)
			end
		elseif sequence == SEQ_003 then
			talk("processEventPfrymloefNQA")
		else
			talk("processEventPfrymloef")
		end
	elseif classId == ARTHUR then
		if sequence <= SEQ_001 then talk("processEventArthur")
		elseif sequence == SEQ_002 then talk("processEventArthurNQF")
		else talk("processEventArthurNQA") end
	elseif classId == YARBOROUGH then
		if sequence <= SEQ_001 then talk("processEventVevina01")
		elseif sequence == SEQ_002 then talk("processEventVevina02")
		else talk("processEventVevina03") end
	elseif classId == EBRELNAUX then
		if sequence == SEQ_004 then
			talk("processEventEbrelnaux")
			quest:StartSequence(SEQ_005)
		else
			talk("processEventEbrelnauxAfter")
		end
	elseif classId == BARDO then
		talk(sequence == SEQ_004 and "processEventBardo" or "processEventBardoAfter")
	elseif classId == LIONNELLAIS then
		talk("processEventLionnellais")
	elseif classId == CID then
		if sequence == SEQ_005 then
			talk("processEventClear")
			local rewarded = showQuestRewards(player, quest)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest) end
			return
		end
		talk("processEventCid")
	end
	player:EndEvent()
end

function startDuty(player, quest)
	startQuestDuty(player, quest, {
		zone = DUTY_ZONE, area = DUTY_AREA, director = DUTY_DIRECTOR,
		anchor = DUTY_ANCHOR
	})
end

-- Called by QuestDirectorGcg10201 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_001 then
		return
	end
	if success then
		wait(2)
		quest:StartSequence(SEQ_002)
		player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
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
	local sequence = quest:GetSequence()
	local held = (sequence >= SEQ_001 and sequence ~= SEQ_ACCEPT) and 1 or 0
	return held
end

function getJournalMapMarkerList(player, quest)
end
