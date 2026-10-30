require("Global")
require("Quest")
require("QuestDuty")

--[[
Shadow of the Raven (Gcg103, 111629). After Gcg102. Level 45, Twin Adder rank 11.

 - Offer: Fulke (Adders' Nest), processEventStart (1 = accepted). Repeat processEventStartAfter.
 - SEQ_000 Kan-E-Senna before Stillglade Fane: processEventSenna(a3, a4) -> SEQ_005. a3 = 1 for a
   Gridanian, a4 = 1 on the White Mage job.
 - SEQ_005 Swethyna south of Camp Crimson Bark (West Shroud): processEventNQ01(0), then a magitek
   vanguard attacks (QuestDirectorGcg10301) -> SEQ_010.
 - SEQ_010 the fight; a win plays processEventNQ02 and completes the quest here: there is no turn-in
   function. A loss, or a full inventory, leaves SEQ_010; Swethyna restarts it.
Ambient: O-App-Pesi processEventPesi, Brookstone processEventSwethryk. No quest markers.
--]]

local startDuty


local SEQ_000 = 0
local SEQ_005 = 5
local SEQ_010 = 10

local FULKE		= 1500200
local KANESENNA	= 1001569
local SWETHYNA	= 1000680
local OAPPPESI	= 1000033
local BROOKSTONE	= 1060025	-- the client names this one Swethryk

local DUTY_ZONE		= 153	-- West Shroud
local DUTY_AREA		= "SimpleContentGcg10301"
local DUTY_DIRECTOR	= "Quest/QuestDirectorGcg10301"
local DUTY_ANCHOR		= {-1570.0, -11.0, -520.0, 2.9}
local SITE_RETURN		= {-1570.0, -11.0, -520.0, 2.9}

local CLASS_CNJ = 23

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
	-- isSpawned: these story actors exist only for players on these steps.
	quest:SetENpc(KANESENNA, sequence == SEQ_000 and QFLAG_TALK or QFLAG_OFF, true, false, false, sequence == SEQ_000)
	quest:SetENpc(SWETHYNA, sequence >= SEQ_005 and QFLAG_TALK or QFLAG_OFF, true, false, false, sequence >= SEQ_005)
	quest:SetENpc(OAPPPESI)
	quest:SetENpc(BROOKSTONE, QFLAG_OFF, true, false, false, sequence == SEQ_000)
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

	if classId == FULKE then
		callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter")
	elseif classId == KANESENNA then
		if sequence == SEQ_000 then
			local gridanian = player:GetInitialTown() == 2 and 1 or 0
			local whiteMage = (player:GetClass() == CLASS_CNJ and player.currentJob ~= 0) and 1 or 0
			callClientFunction(player, "delegateEvent", player, quest, "processEventSenna", gridanian, whiteMage)
			quest:StartSequence(SEQ_005)
		end
	elseif classId == SWETHYNA then
		if sequence == SEQ_005 then
			callClientFunction(player, "delegateEvent", player, quest, "processEventNQ01", 0)
			quest:StartSequence(SEQ_010)
			startDuty(player, quest)
			return
		elseif sequence == SEQ_010 then
			if callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass") == 1 then
				startDuty(player, quest)
				return
			end
		end
	elseif classId == OAPPPESI then
		callClientFunction(player, "delegateEvent", player, quest, "processEventPesi")
	elseif classId == BROOKSTONE then
		callClientFunction(player, "delegateEvent", player, quest, "processEventSwethryk")
	end
	player:EndEvent()
end

function startDuty(player, quest)
	startQuestDuty(player, quest, {
		zone = DUTY_ZONE, area = DUTY_AREA, director = DUTY_DIRECTOR,
		anchor = DUTY_ANCHOR
	})
end

-- Called by QuestDirectorGcg10301 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_010 then
		return
	end
	if success then
		wait(2)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		callClientFunction(player, "delegateEvent", player, quest, "processEventNQ02")
		player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
		local rewarded = showQuestRewards(player, quest)
		player:EndEvent()
		if rewarded then
			player:CompleteQuest(quest)
		end
		-- A full inventory keeps SEQ_010: Swethyna restarts the fight.
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
end
