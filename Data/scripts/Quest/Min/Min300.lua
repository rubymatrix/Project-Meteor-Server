require("Global")
require("Quest")
require("QuestFlow")

--[[
Little Saboteurs (Min300, quest 110461). Follows Min200, Miner level 30. Offered by Linette
(processEventLinetteStart, accepted on 1).

Seq 0:   V'korolon's briefing at the Roost (processEvent010; the Amajina & Sons linkpearl).
Seq 5:   The chocobo carriage driver's clue (processEvent013).
Seq 7:   Parley with the driver. Until the Parley is won his talk points at it (worldMaster 51050, then
         processEvent013); won, processEvent017 and the twins' linkpearl call.
Seq 13:  The linkpearl read plays processEvent020 (the call has no text row of its own).
Seq 14:  The buried box in the flower field (push, no scene).
Seq 20:  Linette's interim report (processEvent025).
Seq 25:  Nenekko's arrival at Eshtaime's Lapidaries (processEvent030).
Seq 30:  Nenekko's feelings (processEvent040).
Seq 35:  Linette's warning (processEvent050).
Seq 40:  Popokkuli's Echo (processEvent060, on a yes), then Seserukka's (processEvent070, on a yes), which
         closes the quest.

Completion: COMPLETION_REWARDS.
Spawns and class fills: Data/sql/seed/seed_quest_min300_01.sql.
--]]

local SEQ_000 = 0
local SEQ_005 = 5
local SEQ_007 = 7
local SEQ_013 = 13
local SEQ_014 = 14
local SEQ_020 = 20
local SEQ_025 = 25
local SEQ_030 = 30
local SEQ_035 = 35
local SEQ_040 = 40

local LINETTE           = 1000861
local VKOROLON          = 1000458
local DRIVER            = 1700010
local NENEKKO           = 1000604
local POPOKKULI         = 1000857
local SESERUKKA         = 1000858
local OBJECTIVE_TRIGGER = 1090008

local SPAWN_BURIED_BOX = "min300_buried_box"
local SPAWN_NENEKKO    = "min300_nenekko"

local MRKR_VKOROLON   = 11046101
local MRKR_DRIVER     = 11046104
local MRKR_BURIED_BOX = 11046106
local MRKR_LINETTE    = 11046108
local MRKR_ESHTAIME   = 11046109
local MRKR_NENEKKO    = 11046110
local MRKR_LINETTE2   = 11046111
local MRKR_POPOKKULI  = 11046112
local MRKR_SESERUKKA  = 11046113

local NPCLS_AMAJINA = 25
local DRIVER_DISPLAY_ID = 4000559
local TEXT_PARLEY_TARGET = 51050 -- worldMaster "Target <name> and select Parley from the interaction menu."

-- The Parley with the coach driver: xtx/negotiationTable row 1201 (Little Saboteurs).
PARLEY = {
	row = 1201,
	displayNameId = DRIVER_DISPLAY_ID,
	topics = { 1039, 1040, 1041, 1032, 1035, 1031, 2006, 2012, 2013 },
}

local FLAG_PARLEY_WON           = 0
local FLAG_PARLEY_TUTORIAL_SEEN = 1
local FLAG_PARLEY_WIN_SEEN      = 2
local FLAG_ECHOED_POPOKKULI     = 3

-- The client reward sheet has no class-quest rows.
local COMPLETION_REWARDS = { exp = 3420, gil = 30000 }

local function hasEchoedPopokkuli(player, quest, data)
	return data:GetFlag(FLAG_ECHOED_POPOKKULI)
end

local function popokkuliPending(player, quest, data)
	return not data:GetFlag(FLAG_ECHOED_POPOKKULI)
end

local PHASES = {
	[SEQ_000] = { enpcs = { { VKOROLON, QFLAG_TALK } }, markers = { MRKR_VKOROLON } },
	[SEQ_005] = { enpcs = { { DRIVER, QFLAG_TALK, spawn = true } }, markers = { MRKR_DRIVER } },
	[SEQ_007] = { enpcs = { { DRIVER, QFLAG_TALK, spawn = true } }, markers = { MRKR_DRIVER } },
	-- The twins are reached by linkpearl: nothing lit.
	[SEQ_013] = {},
	[SEQ_014] = {
		enpcs = { { OBJECTIVE_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true } },
		markers = { MRKR_BURIED_BOX },
	},
	[SEQ_020] = { enpcs = { { LINETTE, QFLAG_TALK } }, markers = { MRKR_LINETTE } },
	[SEQ_025] = { enpcs = { { NENEKKO, QFLAG_TALK, spawn = true } }, markers = { MRKR_ESHTAIME } },
	[SEQ_030] = { enpcs = { { NENEKKO, QFLAG_TALK, spawn = true } }, markers = { MRKR_NENEKKO } },
	[SEQ_035] = { enpcs = { { LINETTE, QFLAG_TALK } }, markers = { MRKR_LINETTE2 } },
	-- Seserukka's Echo closes the quest, so it waits for Popokkuli's.
	[SEQ_040] = {
		enpcs = {
			{ POPOKKULI, QFLAG_TALK, when = popokkuliPending, spawn = true },
			{ SESERUKKA, QFLAG_TALK, when = hasEchoedPopokkuli, spawn = true },
		},
		markers = { { MRKR_POPOKKULI, when = popokkuliPending }, { MRKR_SESERUKKA, when = hasEchoedPopokkuli } },
	},
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(LINETTE, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

local STEPS = {
	[SEQ_005] = { DRIVER,  "processEvent013", SEQ_007 },
	[SEQ_020] = { LINETTE, "processEvent025", SEQ_025 },
	[SEQ_025] = { NENEKKO, "processEvent030", SEQ_030 },
	[SEQ_030] = { NENEKKO, "processEvent040", SEQ_035 },
	[SEQ_035] = { LINETTE, "processEvent050", SEQ_040 },
}

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	local data = quest:GetData()
	local step = STEPS[sequence]

	if sequence == SEQ_ACCEPT and classId == LINETTE then
		local accepted = delegateEvent(player, quest, "processEventLinetteStart")
		player:EndEvent()
		if accepted == 1 then
			player:AcceptQuest(quest)
		end
		return
	elseif sequence == SEQ_000 and classId == VKOROLON then
		delegateEvent(player, quest, "processEvent010")
		quest:StartSequence(SEQ_005)
		-- The guild linkpearl comes with the briefing, since accepting the quest is not a step.
		player:AddNpcLs(NPCLS_AMAJINA)
	elseif sequence == SEQ_007 and classId == DRIVER then
		if data:GetFlag(FLAG_PARLEY_WON) then
			delegateEvent(player, quest, "processEvent017")
			quest:StartSequence(SEQ_013)
			quest:NewNpcLsMsg(NPCLS_AMAJINA)
		else
			player:SendGameMessage(GetWorldMaster(), TEXT_PARLEY_TARGET, MESSAGE_TYPE_SYSTEM, 0, DRIVER_DISPLAY_ID)
			delegateEvent(player, quest, "processEvent013")
			parleyAfterSetup(player, quest, npc)
		end
	elseif sequence == SEQ_040 and classId == POPOKKULI then
		if not data:GetFlag(FLAG_ECHOED_POPOKKULI) and delegateEvent(player, quest, "processEvent060") == 1 then
			setQuestFlagOn(quest, FLAG_ECHOED_POPOKKULI)
		end
	elseif sequence == SEQ_040 and classId == SESERUKKA and data:GetFlag(FLAG_ECHOED_POPOKKULI) then
		if delegateEvent(player, quest, "processEvent070") == 1 then
			turnInQuest(player, quest, nil, COMPLETION_REWARDS)
			return
		end
	elseif step ~= nil and classId == step[1] and (classId ~= NENEKKO or npcName(npc) == SPAWN_NENEKKO) then
		delegateEvent(player, quest, step[2])
		quest:StartSequence(step[3])
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	if quest:GetSequence() == SEQ_014 and npcName(npc) == SPAWN_BURIED_BOX then
		player:EndEvent()
		quest:StartSequence(SEQ_020)
		quest:UpdateENPCs()
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

-- The twins' call has no text row: the read plays the transition scene and closes the glow.
function onNpcLS(player, quest, from, msgStep)
	if from == NPCLS_AMAJINA and quest:GetSequence() == SEQ_013 then
		delegateEvent(player, quest, "processEvent020")
		quest:EndOfNpcLsMsgs()
		quest:StartSequence(SEQ_014)
	end
	player:EndEvent()
	quest:UpdateENPCs()
end

-- Parley stays open on the driver until it is won.
function canParley(player, quest, npc)
	local data = quest:GetData()
	if quest:GetSequence() ~= SEQ_007 or npc:GetActorClassId() ~= DRIVER or data:GetFlag(FLAG_PARLEY_WON) then
		return nil
	end
	return {
		row = PARLEY.row, displayNameId = PARLEY.displayNameId, topics = PARLEY.topics,
		tutorial = not data:GetFlag(FLAG_PARLEY_TUTORIAL_SEEN),
		winTutorial = not data:GetFlag(FLAG_PARLEY_WIN_SEEN),
	}
end

function onParleyEnd(player, quest, npc, outcome)
	if quest:GetSequence() ~= SEQ_007 then
		return
	end
	setQuestFlagOn(quest, FLAG_PARLEY_TUTORIAL_SEEN)
	if outcome == "won" then
		setQuestFlagOn(quest, FLAG_PARLEY_WIN_SEEN)
		setQuestFlagOn(quest, FLAG_PARLEY_WON)
	end
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
