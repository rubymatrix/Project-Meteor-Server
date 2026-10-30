require("Global")
require("Quest")
require("QuestFlow")

--[[
A Wailing Welcome (Lnc200, quest 110180). Lancer level 20, offered by Willelda
(processEventWilleldaStart, accepted on 1).

Seq 0:   Willelda sends the new Wailer to J'moldva: his briefing (processEvent010) ends in the join ask and
         moves to 10 (the Wailing Barracks linkpearl) whatever the answer.
Seq 10:  J'moldva's ranging: on a yes, the four orchard chigoes at Lifemend Stump (content
         SimpleContentLnc20001, QuestDirectorLnc20001). A declined or lost ranging is retried from him.
Seq 20:  The ranging won (processEvent020): report to J'moldva (processEvent030).
Seq 30:  Willelda's payment.

Completion: processEvent040, then COMPLETION_REWARDS.
Spawns and class fills: Data/sql/seed/seed_quest_lnc200_01.sql.
--]]

local SEQ_000 = 0
SEQ_010 = 10
local SEQ_020 = 20
local SEQ_030 = 30

local WILLELDA = 1000242
local JMOLDVA  = 1000599

local MRKR_JMOLDVA   = 11018001
local MRKR_OBJECTIVE = 11018002
local MRKR_JMOLDVA2  = 11018003
local MRKR_WILLELDA  = 11018004

local NPCLS_WAILING_BARRACKS = 14

-- The client reward sheet has no class-quest rows.
local COMPLETION_REWARDS = { exp = 1760, gil = 20000, items = { { 4080406, 1 } } }

-- The ranging lands at Lifemend Stump (marker 11018002); a win returns to J'moldva's post.
local RANGING_ENTRY = { 150, -643.270, 20.217, -1061.140, 0.0 }
local JMOLDVA_POST  = { 206, 195.040, 27.900, -1591.100, -0.150 }

local PHASES = {
	[SEQ_000] = { enpcs = { { JMOLDVA, QFLAG_TALK }, WILLELDA }, markers = { MRKR_JMOLDVA } },
	[SEQ_010] = { enpcs = { { JMOLDVA, QFLAG_TALK } }, markers = { MRKR_OBJECTIVE } },
	[SEQ_020] = { enpcs = { { JMOLDVA, QFLAG_TALK }, WILLELDA }, markers = { MRKR_JMOLDVA2 } },
	[SEQ_030] = { enpcs = { { WILLELDA, QFLAG_REWARD } }, markers = { MRKR_WILLELDA } },
}

local CHATTER = {
	[SEQ_000] = { [WILLELDA] = "processEvent005_2" },
	[SEQ_020] = { [WILLELDA] = "processEvent020_2" },
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
	elseif (sequence == SEQ_000 or sequence == SEQ_010) and classId == JMOLDVA then
		if sequence == SEQ_000 then
			delegateEvent(player, quest, "processEvent010")
		end
		local answer = delegateEvent(player, quest, "contentsJoinAskInBasaClass")
		if sequence == SEQ_000 then
			-- The guild linkpearl comes with the briefing, since accepting the quest is not a step.
			quest:StartSequence(SEQ_010)
			player:AddNpcLs(NPCLS_WAILING_BARRACKS)
		end
		if answer == 1 then
			local p = RANGING_ENTRY
			startQuestContent(player, {
				zone = p[1], content = "SimpleContentLnc20001", director = "Quest/QuestDirectorLnc20001",
				x = p[2], y = p[3], z = p[4], rot = p[5],
			})
			return
		end
	elseif sequence == SEQ_020 and classId == JMOLDVA then
		delegateEvent(player, quest, "processEvent030")
		quest:StartSequence(SEQ_030)
	elseif sequence == SEQ_030 and classId == WILLELDA then
		turnInQuest(player, quest, "processEvent040", COMPLETION_REWARDS)
		return
	else
		delegateChatter(player, quest, CHATTER, sequence, classId)
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

-- Called by QuestDirectorLnc20001 on the win. The aftermath fades in after the return
-- to the barracks.
function finishLnc200Ranging(player, quest, duty, area)
	delegateEvent(player, quest, "processEvent020")
	quest:StartSequence(SEQ_020)
	local p = JMOLDVA_POST
	leaveQuestContent(player, duty, area, { zone = p[1], x = p[2], y = p[3], z = p[4], rot = p[5] })
end

-- A loss or timeout leaves the player at Lifemend Stump.
function failLnc200Ranging(player, quest, duty, area)
	local p = RANGING_ENTRY
	leaveQuestContent(player, duty, area, { zone = p[1], x = p[2], y = p[3], z = p[4], rot = p[5] })
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
