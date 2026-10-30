require("Global")
require("Quest")
require("QuestFlow")

--[[

Quest Script

Name:   Mystery of the Gastronome Gone Home
Code:   Cul300
Id:     110441
Prereq: Showdown (Cul200 - 110440)

Seq 65535: Offered by Charlys (Limsa Lominsa).
Seq 0:  Charlys's briefing.
Seq 5:  Prudentia's account at the Bismarck.
Seq 10: Charlys's lead, Deaustie's answer and the thickset tailor in Ul'dah.
Seq 15: The Parley with the thickset tailor (negotiationTable row 3001).
Seq 25: The report to Charlys.
Seq 30: The alley objective in Limsa Lominsa (push).
Seq 35: Charlys's reward.

The lead and the question have no scene in the client script, so each only records its flag.
Spawns, gates and class fills: Data/sql/seed/seed_quest_cul300_01.sql.

--]]

local SEQ_000 = 0
local SEQ_005 = 5
local SEQ_010 = 10
local SEQ_015 = 15
local SEQ_025 = 25
local SEQ_030 = 30
local SEQ_035 = 35

local CHARLYS         = 1000138
local PRUDENTIA       = 1000168
local DEAUSTIE        = 1000293
local THICKSET_TAILOR = 1000292 -- spawn cul300_thickset_tailor (Ul'dah)
local ALLEY_TRIGGER   = 1090008 -- spawn cul300_alley_trigger (Limsa Lominsa)

local MRKR_PRUDENTIA       = 11044101
local MRKR_CHARLYS         = 11044102
local MRKR_DEAUSTIE        = 11044103
local MRKR_THICKSET_TAILOR = 11044104
local MRKR_CHARLYS2        = 11044105
local MRKR_ALLEY           = 11044106
local MRKR_CHARLYS3        = 11044107

local THICKSET_TAILOR_DISPLAY_ID = 4000063
local TEXT_SELECT_PARLEY = 51050 -- worldMaster "Target <name> and select Parley from the interaction menu."

local FLAG_LED        = 0
local FLAG_QUESTIONED = 1
local FLAG_PARLEY_WON = 2

-- The Parley with the tailor (questflow.lua Parley). The topics are a server choice.
PARLEY = {
	row = 3001,
	displayNameId = THICKSET_TAILOR_DISPLAY_ID,
	topics = { 1036, 1034, 1033, 1032, 1035, 2006, 2007, 2012, 2013 },
}

-- Completion pay: the client reward sheet has no row for this quest (questflow.lua turnInQuest).
local COMPLETION_REWARDS = { exp = 3420, gil = 30000 }


local function isLeadPending(player, quest, data)
	return not data:GetFlag(FLAG_LED)
end

local function isQuestionPending(player, quest, data)
	return data:GetFlag(FLAG_LED) and not data:GetFlag(FLAG_QUESTIONED)
end

local function isTailorWaiting(player, quest, data)
	return data:GetFlag(FLAG_QUESTIONED)
end

local PHASES = {
	[SEQ_000] = {
		enpcs = { { CHARLYS, QFLAG_TALK } },
		markers = { MRKR_CHARLYS },
	},
	[SEQ_005] = {
		enpcs = { { PRUDENTIA, QFLAG_TALK } },
		markers = { MRKR_PRUDENTIA },
	},
	[SEQ_010] = {
		enpcs = {
			{ CHARLYS, QFLAG_TALK, when = isLeadPending },
			{ DEAUSTIE, QFLAG_TALK, when = isQuestionPending },
			{ THICKSET_TAILOR, QFLAG_TALK, when = isTailorWaiting, spawn = true },
		},
		markers = {
			{ MRKR_CHARLYS, when = isLeadPending },
			{ MRKR_DEAUSTIE, when = isQuestionPending },
			{ MRKR_THICKSET_TAILOR, when = isTailorWaiting },
		},
	},
	[SEQ_015] = {
		enpcs = { { THICKSET_TAILOR, QFLAG_TALK, spawn = true } },
		markers = { MRKR_THICKSET_TAILOR },
	},
	[SEQ_025] = {
		enpcs = { { CHARLYS, QFLAG_TALK } },
		markers = { MRKR_CHARLYS2 },
	},
	[SEQ_030] = {
		enpcs = { { ALLEY_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true } },
		markers = { MRKR_ALLEY },
	},
	[SEQ_035] = {
		enpcs = { { CHARLYS, QFLAG_REWARD } },
		markers = { MRKR_CHARLYS3 },
	},
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(CHARLYS, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if sequence == SEQ_ACCEPT then
		if classId == CHARLYS then
			local accepted = delegateEvent(player, quest, "processEventCharlysStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return
		end
	elseif sequence == SEQ_000 and classId == CHARLYS then
		delegateEvent(player, quest, "processEvent010")
		quest:StartSequence(SEQ_005)
	elseif sequence == SEQ_005 and classId == PRUDENTIA then
		delegateEvent(player, quest, "processEvent012")
		quest:StartSequence(SEQ_010)
	elseif sequence == SEQ_010 then
		if classId == CHARLYS and not getQuestFlag(quest, FLAG_LED) then
			setQuestFlagOn(quest, FLAG_LED)
		elseif classId == DEAUSTIE and getQuestFlag(quest, FLAG_LED) and not getQuestFlag(quest, FLAG_QUESTIONED) then
			setQuestFlagOn(quest, FLAG_QUESTIONED)
		elseif classId == THICKSET_TAILOR and getQuestFlag(quest, FLAG_QUESTIONED) then
			delegateEvent(player, quest, "processEvent014")
			quest:StartSequence(SEQ_015)
		end
	elseif sequence == SEQ_015 and classId == THICKSET_TAILOR then
		if getQuestFlag(quest, FLAG_PARLEY_WON) then
			delegateEvent(player, quest, "processEvent020")
			quest:StartSequence(SEQ_025)
		else
			-- The setup scene points at the Parley menu until the board is won.
			player:SendGameMessage(GetWorldMaster(), TEXT_SELECT_PARLEY, 0x20, 0, THICKSET_TAILOR_DISPLAY_ID)
			delegateEvent(player, quest, "processEvent016")
			parleyAfterSetup(player, quest, npc)
		end
	elseif sequence == SEQ_025 and classId == CHARLYS then
		delegateEvent(player, quest, "processEvent025")
		quest:StartSequence(SEQ_030)
	elseif sequence == SEQ_035 and classId == CHARLYS then
		turnInQuest(player, quest, "processEvent035", COMPLETION_REWARDS)
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc, eventName)
	if quest:GetSequence() == SEQ_030 and npcName(npc) == "cul300_alley_trigger" then
		delegateEvent(player, quest, "processEvent030")
		quest:StartSequence(SEQ_035)
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function canParley(player, quest, npc)
	return quest:GetSequence() == SEQ_015 and npc:GetActorClassId() == THICKSET_TAILOR
		and not getQuestFlag(quest, FLAG_PARLEY_WON)
end

function onParleyEnd(player, quest, npc, outcome)
	if quest:GetSequence() == SEQ_015 and outcome == "won" then
		setQuestFlagOn(quest, FLAG_PARLEY_WON)
	end
end

function onNotice(player, quest, target)
	player:EndEvent()
	quest:UpdateENPCs()
end

-- The journal counts the lead and the question; the tailor's talk closes the step.
function getJournalInformation(player, quest)
	if quest:GetSequence() ~= SEQ_010 then
		return 0, 0, 0, 0, 0
	end
	local done = (getQuestFlag(quest, FLAG_LED) and 1 or 0) + (getQuestFlag(quest, FLAG_QUESTIONED) and 1 or 0)
	return done, 0, 0, 0, 3
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
