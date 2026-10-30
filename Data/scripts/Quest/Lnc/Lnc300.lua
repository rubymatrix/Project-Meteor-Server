require("Global")
require("Quest")
require("QuestFlow")

--[[
Culture Shock (Lnc300, quest 110181). Follows Lnc200, Lancer level 30. Offered by J'moldva
(processEventJMoldvaStart asks nothing: taken once it closes).

Seq 0:   Canvass Gagaruna in Ul'dah (processEvent020).
Seq 10:  Dreues tests the Wailer in Ul'dah (processEvent030).
Seq 20:  J'moldva's caravan order (processEvent040).
Seq 30:  The caravan trigger in Central Shroud: processEvent050, the join ask, on a yes the Garlean flyover
         (processEvent060) and the defense (content SimpleContentLnc30001, QuestDirectorLnc30001). A declined
         or lost defense keeps 30.
Seq 40:  The defense won (processEvent065 after the return): the brazen-faced broker's thanks (processEvent068).
Seq 50:  Report to J'moldva (processEvent070).
Seq 60:  Willelda's reward.

Completion: processEvent075, then COMPLETION_REWARDS.
Spawns and class fills: Data/sql/seed/seed_quest_lnc300_01.sql.
--]]

SEQ_000 = 0
SEQ_010 = 10
SEQ_020 = 20
SEQ_030 = 30
SEQ_040 = 40
SEQ_050 = 50
SEQ_060 = 60

WILLELDA          = 1000242
JMOLDVA           = 1000599
GAGARUNA          = 1000862
DREUES            = 1000402
BROKER            = 1000403
OBJECTIVE_TRIGGER = 1090008

SPAWN_CARAVAN = "lnc300_caravan_trig"
SPAWN_BROKER  = "lnc300_brazen_broker"

MRKR_GAGARUNA  = 11018101
MRKR_JMOLDVA   = 11018102
MRKR_OBJECTIVE = 11018103
MRKR_BROKER    = 11018104
MRKR_JMOLDVA2  = 11018105
MRKR_WILLELDA  = 11018106
MRKR_DREUES    = 11018107

-- The client reward sheet has no class-quest rows.
COMPLETION_REWARDS = { exp = 3420, gil = 30000 }

-- The defense lands at the caravan trigger and a loss returns there; a win returns to the broker.
CARAVAN_ENTRY = { 150, 379.700, 6.188, -14.300, 0.0 }
BROKER_POST   = { 206, 187.480, 27.500, -1583.960, 0.0 }

PHASES = {
	[SEQ_000] = { enpcs = { { GAGARUNA, QFLAG_TALK } }, markers = { MRKR_GAGARUNA } },
	[SEQ_010] = { enpcs = { { DREUES, QFLAG_TALK, spawn = true } }, markers = { MRKR_DREUES } },
	[SEQ_020] = { enpcs = { { JMOLDVA, QFLAG_TALK } }, markers = { MRKR_JMOLDVA } },
	[SEQ_030] = {
		enpcs = { { OBJECTIVE_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true } },
		markers = { MRKR_OBJECTIVE },
	},
	[SEQ_040] = { enpcs = { { BROKER, QFLAG_TALK, spawn = true } }, markers = { MRKR_BROKER } },
	[SEQ_050] = { enpcs = { { JMOLDVA, QFLAG_TALK } }, markers = { MRKR_JMOLDVA2 } },
	[SEQ_060] = { enpcs = { { WILLELDA, QFLAG_REWARD } }, markers = { MRKR_WILLELDA } },
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(JMOLDVA, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

-- { npc, scene, next sequence }: one scene, then the next step.
STEPS = {
	[SEQ_000] = { GAGARUNA, "processEvent020", SEQ_010 },
	[SEQ_010] = { DREUES,   "processEvent030", SEQ_020 },
	[SEQ_020] = { JMOLDVA,  "processEvent040", SEQ_030 },
	[SEQ_040] = { BROKER,   "processEvent068", SEQ_050 },
	[SEQ_050] = { JMOLDVA,  "processEvent070", SEQ_060 },
}

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	local step = STEPS[sequence]

	if sequence == SEQ_ACCEPT and classId == JMOLDVA then
		delegateEvent(player, quest, "processEventJMoldvaStart")
		player:EndEvent()
		player:AcceptQuest(quest)
		return
	elseif sequence == SEQ_060 and classId == WILLELDA then
		turnInQuest(player, quest, "processEvent075", COMPLETION_REWARDS)
		return
	elseif step ~= nil and classId == step[1] and (classId ~= BROKER or npcName(npc) == SPAWN_BROKER) then
		delegateEvent(player, quest, step[2])
		quest:StartSequence(step[3])
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence()

	if sequence == SEQ_030 and npcName(npc) == SPAWN_CARAVAN then
		delegateEvent(player, quest, "processEvent050")
		if delegateEvent(player, quest, "contentsJoinAskInBasaClass") == 1 then
			delegateEvent(player, quest, "processEvent060")
			local p = CARAVAN_ENTRY
			startQuestContent(player, {
				zone = p[1], content = "SimpleContentLnc30001", director = "Quest/QuestDirectorLnc30001",
				x = p[2], y = p[3], z = p[4], rot = p[5],
			})
			return
		end
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

-- Called by QuestDirectorLnc30001 on the win. The aftermath fades in after the return
-- to the barracks, beside the broker.
function finishLnc300Defense(player, quest, duty, area)
	delegateEvent(player, quest, "processEvent065")
	quest:StartSequence(SEQ_040)
	local p = BROKER_POST
	leaveQuestContent(player, duty, area, { zone = p[1], x = p[2], y = p[3], z = p[4], rot = p[5] })
end

function failLnc300Defense(player, quest, duty, area)
	local p = CARAVAN_ENTRY
	leaveQuestContent(player, duty, area, { zone = p[1], x = p[2], y = p[3], z = p[4], rot = p[5] })
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
