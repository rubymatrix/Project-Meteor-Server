require("Global")
require("Quest")
require("QuestDuty")

--[[
The Mail Must Get Through (Com0g4, 111604). Prereq: Com0g1; level 22.
Imperials in the North Shroud hold the letter; Fulke sends it on to Radulf at Little Ala Mhigo.
Walkthrough: Data/Docs/Scripts/Quest/Com/Com0g4.md.
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

local function radulfFree(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEventRadulfFree")
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
		[FULKE] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter")
		end,
	},
	[SEQ_001] = {
		[FULKE] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEventFulke")
			quest:StartSequence(SEQ_002)
		end,
	},
	[SEQ_002] = {
		[FULKE] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEventFulkeFree")
		end,
		[RADULF] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEventRadulf")
			quest:StartSequence(SEQ_003)
		end,
	},
	[SEQ_003] = {
		[FULKE] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear", 0, 0)
			local rewarded = showQuestRewards(player, quest)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest) end
			return true
		end,
	},
	always = {
		[RADULF] = radulfFree,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
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
