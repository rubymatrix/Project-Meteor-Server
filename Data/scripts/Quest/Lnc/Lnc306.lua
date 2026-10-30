require("Global")
require("Quest")
require("QuestFlow")

--[[
Necessary Evils (Lnc306, quest 110182). Follows Lnc300, Lancer level 36. Offered by Willelda
(processEventWilleldaStart, accepted on 1).

Seq 0:   Willelda sends the Wailer to J'moldva (processEvent010).
Seq 10:  The broker's caravan on the south road in Central Shroud: processEvent020, the join ask, then the
         woodsent elemental (content SimpleContentLnc30601, QuestDirectorLnc30601). Declined or lost: stays 10.
Seq 20:  The campfire aftermath (processEvent030); the brazen-faced broker's Echo (processEvent035 asks, then
         processEvent040 on a yes).
Seq 30:  Report to J'moldva (processEvent050).
Seq 40:  Willelda's reward.

Completion: processEvent060, then COMPLETION_REWARDS.
Spawns and class fills: Data/sql/seed/seed_quest_lnc306_01.sql.
--]]

SEQ_000 = 0
SEQ_010 = 10
SEQ_020 = 20
SEQ_030 = 30
SEQ_040 = 40

WILLELDA          = 1000242
JMOLDVA           = 1000599
BROKER            = 1000403
OBJECTIVE_TRIGGER = 1090008

SPAWN_CARAVAN = "lnc306_caravan_trig"
SPAWN_BROKER  = "lnc306_brazen_broker"

MRKR_JMOLDVA   = 11018201
MRKR_OBJECTIVE = 11018202
MRKR_BROKER    = 11018203
MRKR_JMOLDVA2  = 11018204
MRKR_WILLELDA  = 11018205

-- The client reward sheet has no class-quest rows.
COMPLETION_REWARDS = { exp = 4720, gil = 36000 }

-- The battle lands at the south road caravan trigger and returns there.
CARAVAN_ENTRY = { 150, 394.230, 5.455, -782.400, 0.0 }

PHASES = {
	[SEQ_000] = { enpcs = { { JMOLDVA, QFLAG_TALK } }, markers = { MRKR_JMOLDVA } },
	[SEQ_010] = {
		enpcs = { { OBJECTIVE_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true } },
		markers = { MRKR_OBJECTIVE },
	},
	[SEQ_020] = { enpcs = { { BROKER, QFLAG_TALK, spawn = true } }, markers = { MRKR_BROKER } },
	[SEQ_030] = { enpcs = { { JMOLDVA, QFLAG_TALK } }, markers = { MRKR_JMOLDVA2 } },
	[SEQ_040] = { enpcs = { { WILLELDA, QFLAG_REWARD } }, markers = { MRKR_WILLELDA } },
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(WILLELDA, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if sequence == SEQ_ACCEPT and classId == WILLELDA then
		local accepted = delegateEvent(player, quest, "processEventWilleldaStart")
		player:EndEvent()
		if accepted == 1 then
			player:AcceptQuest(quest)
		end
		return
	elseif sequence == SEQ_000 and classId == JMOLDVA then
		delegateEvent(player, quest, "processEvent010")
		quest:StartSequence(SEQ_010)
	elseif sequence == SEQ_020 and classId == BROKER and npcName(npc) == SPAWN_BROKER then
		if delegateEvent(player, quest, "processEvent035") == 1 then
			delegateEvent(player, quest, "processEvent040")
			quest:StartSequence(SEQ_030)
		end
	elseif sequence == SEQ_030 and classId == JMOLDVA then
		delegateEvent(player, quest, "processEvent050")
		quest:StartSequence(SEQ_040)
	elseif sequence == SEQ_040 and classId == WILLELDA then
		turnInQuest(player, quest, "processEvent060", COMPLETION_REWARDS)
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	if quest:GetSequence() == SEQ_010 and npcName(npc) == SPAWN_CARAVAN then
		delegateEvent(player, quest, "processEvent020")
		if delegateEvent(player, quest, "contentsJoinAskInBasaClass") == 1 then
			local p = CARAVAN_ENTRY
			startQuestContent(player, {
				zone = p[1], content = "SimpleContentLnc30601", director = "Quest/QuestDirectorLnc30601",
				x = p[2], y = p[3], z = p[4], rot = p[5],
			})
			return
		end
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

-- Called by QuestDirectorLnc30601 on the win. The campfire aftermath fades in after the
-- return to the road.
function finishLnc306Battle(player, quest, duty, area)
	delegateEvent(player, quest, "processEvent030")
	quest:StartSequence(SEQ_020)
	local p = CARAVAN_ENTRY
	leaveQuestContent(player, duty, area, { zone = p[1], x = p[2], y = p[3], z = p[4], rot = p[5] })
end

function failLnc306Battle(player, quest, duty, area)
	local p = CARAVAN_ENTRY
	leaveQuestContent(player, duty, area, { zone = p[1], x = p[2], y = p[3], z = p[4], rot = p[5] })
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
