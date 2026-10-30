require("Global")
require("Quest")
require("QuestDuty")

--[[
Arms Race (Com0u4, 111804). After Com0u3; level 22. The Hellhounds' blockade fight
(QuestDirectorCom0u401), then a contract from each of three weapon makers in Limsa Lominsa.
Which line goes to which maker follows each line's speech. Journal: int2..int4 = the contracts.
--]]

local SEQ_000	= 0
local SEQ_001	= 1
local SEQ_002	= 2
local SEQ_003	= 3

local AUBREY					= 1500198
local MAKER_WOOLVALE			= 1001633	-- Bamponcet
local MAKER_STRAIGHT_EDGE		= 1001631	-- Raaka Maaka
local MAKER_GIGAS				= 1001632	-- C'ndanya
local HELLHOUND_TRIGGER		= 1090335

local MRKR_HELLHOUNDS			= 11170301
local MRKR_LIMSA				= 11170302
local MRKR_AUBREY				= 11170303
local MRKR_WOOLVALE			= 11170304
local MRKR_STRAIGHT_EDGE		= 11170305
local MRKR_GIGAS				= 11170306

local MAKERS = {
	[MAKER_WOOLVALE]		= {flag = 0, talk = "processEvent_020", free = "processEvent_020_1", marker = MRKR_WOOLVALE},
	[MAKER_STRAIGHT_EDGE]	= {flag = 1, talk = "processEvent_030", free = "processEvent_030_1", marker = MRKR_STRAIGHT_EDGE},
	[MAKER_GIGAS]			= {flag = 2, talk = "processEvent_040", free = "processEvent_040_1", marker = MRKR_GIGAS},
}

local DUTY_ZONE				= 171	-- Eastern Thanalan
local DUTY_AREA				= "SimpleContentCom0u401"
local DUTY_DIRECTOR			= "Quest/QuestDirectorCom0u401"
local DUTY_ANCHOR				= {1155.0, 311.70, -949.14, -2.43}
local TRIGGER_RETURN			= {1154.48, 311.70, -947.71, -2.43}	-- outside the push circle

local function contracts(quest)
	local n = 0
	for _, m in pairs(MAKERS) do
		if questFlag(quest, m.flag) then n = n + 1 end
	end
	return n
end

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

	local aubreyFlag = QFLAG_OFF
	if sequence == SEQ_001 then
		aubreyFlag = QFLAG_TALK
	elseif sequence == SEQ_003 then
		aubreyFlag = QFLAG_REWARD
	end
	quest:SetENpc(AUBREY, aubreyFlag)
	if sequence == SEQ_000 then
		quest:SetENpc(HELLHOUND_TRIGGER, QFLAG_PUSH, false, true, false, true)
	end
	-- isSpawned: the makers exist only for players on this step.
	for classId, m in pairs(MAKERS) do
		local pending = sequence == SEQ_002 and not questFlag(quest, m.flag)
		quest:SetENpc(classId, pending and QFLAG_TALK or QFLAG_OFF, true, false, false, sequence == SEQ_002)
	end
end

local function makerTalk(player, quest, npc)
	local m = MAKERS[npc:GetActorClassId()]
	if not questFlag(quest, m.flag) then
		callClientFunction(player, "delegateEvent", player, quest, m.talk)
		setQuestFlag(quest, m.flag)
		if contracts(quest) == 3 then
			quest:StartSequence(SEQ_003)
		end
	else
		callClientFunction(player, "delegateEvent", player, quest, m.free)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[AUBREY] = function(player, quest)
			if callClientFunction(player, "delegateEvent", player, quest, "processEventAUBREYStart") == 1 then
				player:AcceptQuest(quest)
			end
		end,
	},
	[SEQ_000] = {
		[AUBREY] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_000")
		end,
	},
	[SEQ_001] = {
		[AUBREY] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010")
			quest:StartSequence(SEQ_002)
		end,
	},
	[SEQ_002] = {
		[AUBREY] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_1")
		end,
		[MAKER_WOOLVALE] = makerTalk,
		[MAKER_STRAIGHT_EDGE] = makerTalk,
		[MAKER_GIGAS] = makerTalk,
	},
	[SEQ_003] = {
		[AUBREY] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_050", 0)
			local rewarded = showQuestRewards(player, quest)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest) end
			return true
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	if quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == HELLHOUND_TRIGGER then
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

-- Called by QuestDirectorCom0u401 when the fight ends.
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
	local sequence = quest:GetSequence()
	if sequence ~= SEQ_002 and sequence ~= SEQ_003 then
		return 0, 0, 0
	end
	local function held(flag) return questFlag(quest, flag) and 1 or 0 end
	return held(0), held(1), held(2)
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_000 then
		return MRKR_HELLHOUNDS
	elseif sequence == SEQ_001 or sequence == SEQ_003 then
		return MRKR_AUBREY
	elseif sequence == SEQ_002 then
		local list = {MRKR_LIMSA}
		for _, m in pairs(MAKERS) do
			if not questFlag(quest, m.flag) then table.insert(list, m.marker) end
		end
		return unpack(list)
	end
end
