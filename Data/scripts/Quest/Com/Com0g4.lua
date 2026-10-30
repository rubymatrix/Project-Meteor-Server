require("Global")
require("Quest")
require("QuestDuty")

--[[
The Mail Must Get Through (Com0g4, 111604). After Com0g1. Level 22.

 - Offer, Fulke: processEventStart (1 = accepted).
 - SEQ_000 push NW of the city (North Shroud): join ask, then the imperials (QuestDirectorCom0g401).
   Win: the letter is on a corpse (int2), SEQ_001, back to the public spot. Fulke repeats
   processEventStartAfter.
 - SEQ_001 Fulke: processEventFulke -> SEQ_002. SEQ_002 Fulke repeats processEventFulkeFree.
 - SEQ_002 Radulf at Little Ala Mhigo: processEventRadulf, the letter goes, the designs come (int3)
   -> SEQ_003. Repeat processEventRadulfFree.
 - SEQ_003 Fulke: processEventClear(0, 0), rewards.
--]]

local SEQ_000	= 0
local SEQ_001	= 1
local SEQ_002	= 2
local SEQ_003	= 3

local FULKE					= 1500200
local RADULF					= 1001334
local IMPERIAL_TRIGGER		= 1090331

local MRKR_FULKE				= 11160301
local MRKR_RADULF				= 11160302
local MRKR_IMPERIALS			= 11160303
local MRKR_GRIDANIA			= 11160304	-- quest area on the Gridania map

local DUTY_ZONE				= 152	-- North Shroud
local DUTY_AREA				= "SimpleContentCom0g401"
local DUTY_DIRECTOR			= "Quest/QuestDirectorCom0g401"
local DUTY_ANCHOR				= {-630.0, 19.5, -2025.0, -2.36}
local TRIGGER_RETURN			= {-626.0, 19.5, -2020.0, -2.36}	-- outside the push circle

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

	local fulkeFlag = QFLAG_OFF
	if sequence == SEQ_001 then
		fulkeFlag = QFLAG_TALK
	elseif sequence == SEQ_003 then
		fulkeFlag = QFLAG_REWARD
	end
	quest:SetENpc(FULKE, fulkeFlag)
	-- isSpawned: Radulf exists only for players on this quest.
	quest:SetENpc(RADULF, sequence == SEQ_002 and QFLAG_TALK or QFLAG_OFF, true, false, false, sequence >= SEQ_002)
	if sequence == SEQ_000 then
		quest:SetENpc(IMPERIAL_TRIGGER, QFLAG_PUSH, false, true, false, true)
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
		elseif sequence == SEQ_000 then
			callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter")
		elseif sequence == SEQ_001 then
			callClientFunction(player, "delegateEvent", player, quest, "processEventFulke")
			quest:StartSequence(SEQ_002)
		elseif sequence == SEQ_002 then
			callClientFunction(player, "delegateEvent", player, quest, "processEventFulkeFree")
		elseif sequence == SEQ_003 then
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear", 0, 0)
			local rewarded = showQuestRewards(player, quest)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest) end
			return
		end
	elseif classId == RADULF then
		if sequence == SEQ_002 then
			callClientFunction(player, "delegateEvent", player, quest, "processEventRadulf")
			quest:StartSequence(SEQ_003)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEventRadulfFree")
		end
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	if quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == IMPERIAL_TRIGGER then
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

-- Called by QuestDirectorCom0g401 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_000 then
		return
	end

	if success then
		wait(2)
		-- No letter item: the journal shows it from SEQ_001.
		quest:StartSequence(SEQ_001)
	elseif reason == "left" then
		endQuestDuty(player, duty)
		return
	else
		wait(3)
	end
	player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
	endQuestDuty(player, duty, DUTY_ZONE, TRIGGER_RETURN)
end

function getJournalInformation(player, quest)
	local sequence = quest:GetSequence()
	local letter = (sequence == SEQ_001 or sequence == SEQ_002) and 1 or 0
	local designs = (sequence == SEQ_003) and 1 or 0	-- Radulf keeps the letter
	return letter, designs
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_000 then
		return MRKR_IMPERIALS
	elseif sequence == SEQ_001 or sequence == SEQ_003 then
		return MRKR_FULKE, MRKR_GRIDANIA
	elseif sequence == SEQ_002 then
		return MRKR_RADULF
	end
end
