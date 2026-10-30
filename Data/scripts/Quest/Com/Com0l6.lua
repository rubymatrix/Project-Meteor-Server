require("Global")
require("Quest")
require("QuestDuty")

--[[
Ceruleum Shock (Com0l6, 111406). After Com0l5. Level 25.

 - Offer, Guincum: processEventGUINCUMStart(0, 0, 0) (1 = accepted). Guincum repeats processEvent_000.
 - SEQ_000 push at the Vesper Bay ferry docks: join ask, the Immortal Flames (QuestDirectorCom0l601).
   Win: SEQ_001, back to the spot.
 - SEQ_001 Storm Private Aisborgsyn: processEvent_005 -> SEQ_002. Repeat processEvent_005_1.
 - SEQ_002 push at the ceruleum fields, northern Thanalan: processEvent_010 (Cid appears) -> SEQ_003.
 - SEQ_003 Cid at the Limsa Lominsa Landing: processEvent_015(0, 0) (the main path), rewards.
Not wired: processEventGUINCUMHint, the dock bystanders processEvent_005_2-4, the landing staff
processEvent_015_1-7 and the landing lift processEvent_elevator_nq1/nq2.
--]]

local SEQ_000	= 0
local SEQ_001	= 1
local SEQ_002	= 2
local SEQ_003	= 3

local GUINCUM					= 1500199
local AISBORGSYN				= 1001749
local CID						= 1001572
local DOCKS_TRIGGER			= 1090346
local FIELDS_TRIGGER			= 1090360

local MRKR_DOCKS				= 11150501
local MRKR_AISBORGSYN			= 11150502
local MRKR_FIELDS				= 11150503
local MRKR_CID				= 11150506
local MRKR_LANDING			= 11150507

local DUTY_ZONE				= 172	-- Western Thanalan
local DUTY_AREA				= "SimpleContentCom0l601"
local DUTY_DIRECTOR			= "Quest/QuestDirectorCom0l601"
local DUTY_ANCHOR				= {-2185.0, 14.23, -421.0, -2.36}
local TRIGGER_RETURN			= {-2183.0, 14.41, -419.0, -2.36}	-- outside the push circle

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

	quest:SetENpc(GUINCUM, QFLAG_OFF)
	if sequence == SEQ_000 then
		quest:SetENpc(DOCKS_TRIGGER, QFLAG_PUSH, false, true, false, true)
	elseif sequence == SEQ_002 then
		quest:SetENpc(FIELDS_TRIGGER, QFLAG_PUSH, false, true, false, true)
	end
	quest:SetENpc(AISBORGSYN, sequence == SEQ_001 and QFLAG_TALK or QFLAG_OFF, true, false, false, true)
	quest:SetENpc(CID, sequence == SEQ_003 and QFLAG_REWARD or QFLAG_OFF, true, false, false, true)
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if classId == GUINCUM then
		if sequence == SEQ_ACCEPT then
			local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventGUINCUMStart", 0, 0, 0)
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_000")
		end
	elseif classId == AISBORGSYN then
		if sequence == SEQ_001 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_005")
			quest:StartSequence(SEQ_002)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_1")
		end
	elseif classId == CID and sequence == SEQ_003 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_015", 0, 0)
		local rewarded = showQuestRewards(player, quest)
		player:EndEvent()
		if rewarded then player:CompleteQuest(quest) end
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

local push = {
	[SEQ_000] = {
		[DOCKS_TRIGGER] = function(player, quest, npc)
			if callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass") == 1 then
				startQuestDuty(player, quest, {
					zone = DUTY_ZONE, area = DUTY_AREA, director = DUTY_DIRECTOR,
					anchor = DUTY_ANCHOR
				})
				return true
			end
		end,
	},
	[SEQ_002] = {
		[FIELDS_TRIGGER] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010")
			quest:StartSequence(SEQ_003)
		end,
	},
}

function onPush(player, quest, npc)
	if runQuestHandler(push, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

-- Called by QuestDirectorCom0l601 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_000 then
		return
	end

	if success then
		wait(2)
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
	return 0
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_000 then
		return MRKR_DOCKS
	elseif sequence == SEQ_001 then
		return MRKR_AISBORGSYN
	elseif sequence == SEQ_002 then
		return MRKR_FIELDS
	elseif sequence == SEQ_003 then
		return MRKR_CID, MRKR_LANDING
	end
end
