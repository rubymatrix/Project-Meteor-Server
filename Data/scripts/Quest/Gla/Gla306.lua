require("Global")
require("Quest")
require("QuestFlow")

--[[
Thrill of the Fight (Gla306, quest 110082). Follows Gla300, Gladiator level 36. Offered by Lulutsu
(processEventLulutsuStart, accepted on 1).

Seq 0:   Yoyobina's first talk (processEvent003).
Seq 5:   Yoyobina's question (processEvent005, on a yes), the join ask, processEvent010, then the bout with
         the Ala Mhigan bladedancer (content SimpleContentGla30601, QuestDirectorGla30601). Lost: stays 5.
Seq 23:  Yoyobina at her second spot (processEvent023).
Seq 24:  The Ala Mhigan challenger's Echo (processEvent024, on a yes), the join ask, processEvent020_999,
         then the bout (content SimpleContentGla30602, QuestDirectorGla30602). Lost: stays 24.
Seq 30:  Yoyobina at her second spot again (processEvent030, fade-in after a warp).
Seq 40:  The Coliseum stands trigger (processEvent040).
Seq 45:  The second Ala Mhigan challenger Echo (processEvent045, moves on a yes).
Seq 50:  The Silver Bazaar trigger in Western Thanalan (processEvent050).
Seq 55:  Lulutsu's reward.

Two spawns share Yoyobina's class (her first spot gla300_yoyobina and gla306_yoyobina_second) and two share
the challenger's; the handlers tell them apart by uniqueId. Both triggers are class 1090008.
Completion: processEvent055, then COMPLETION_REWARDS.
Spawns and class fills: Data/sql/seed/seed_quest_gla306_01.sql.
--]]

SEQ_000 = 0
SEQ_005 = 5
SEQ_023 = 23
SEQ_024 = 24
SEQ_030 = 30
SEQ_040 = 40
SEQ_045 = 45
SEQ_050 = 50
SEQ_055 = 55

LULUTSU           = 1000863
YOYOBINA          = 1001076
CHALLENGER        = 1000601
OBJECTIVE_TRIGGER = 1090008

SPAWN_YOYOBINA_FIRST  = "gla300_yoyobina"
SPAWN_YOYOBINA_SECOND = "gla306_yoyobina_second"
SPAWN_CHALLENGER      = "gla306_echo_challenger"
SPAWN_CHALLENGER2     = "gla306_echo_challenger2"
SPAWN_STANDS          = "gla306_stands_trig"
SPAWN_BAZAAR          = "gla306_bazaar_trig"

MRKR_YOYOBINA    = 11008201
MRKR_YOYOBINA2   = 11008202
MRKR_YOYOBINA3   = 11008203
MRKR_CHALLENGER  = 11008204
MRKR_YOYOBINA4   = 11008205
MRKR_STANDS      = 11008206
MRKR_CHALLENGER2 = 11008207
MRKR_BAZAAR      = 11008208
MRKR_LULUTSU     = 11008209

-- The client reward sheet has no class-quest rows.
COMPLETION_REWARDS = { exp = 4720, gil = 36000 }

BOUT_ENTRY = { -187.225, 190.150, 219.730, 0.0 }
-- Own spots of the speakers and triggers whose scenes fade in only after a warp.
YOYOBINA_FIRST_POST  = { 209, -186.340, 195.050, 188.810, 0.0 }
YOYOBINA_SECOND_POST = { 209, -177.120, 195.050, 221.190, 0.0 }
CHALLENGER_POST      = { 209, -177.890, 195.050, 205.090, 0.0 }
STANDS_SPOT          = { 209, -185.260, 195.050, 179.740, 0.0 }
CHALLENGER2_POST     = { 209, -177.400, 195.050, 222.470, 0.0 }
BAZAAR_SPOT          = { 172, -1342.940, 56.000, 487.890, 0.0 }

local function warpToPost(player, p)
	warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
end

local function yoyobina(icon)
	return { YOYOBINA, icon, spawn = true }
end

-- Every gated spawn of a class shows while the class is spawned, so each step keeps them all.
local function challenger(icon)
	return { CHALLENGER, icon, spawn = true }
end

local function trigger(icon)
	return { OBJECTIVE_TRIGGER, icon, talk = false, push = true, spawn = true }
end

PHASES = {
	[SEQ_000] = { enpcs = { yoyobina(QFLAG_TALK) }, markers = { MRKR_YOYOBINA } },
	[SEQ_005] = { enpcs = { yoyobina(QFLAG_TALK) }, markers = { MRKR_YOYOBINA2 } },
	[SEQ_023] = { enpcs = { yoyobina(QFLAG_TALK), challenger(QFLAG_OFF) }, markers = { MRKR_YOYOBINA3 } },
	[SEQ_024] = { enpcs = { yoyobina(QFLAG_OFF), challenger(QFLAG_TALK) }, markers = { MRKR_CHALLENGER } },
	[SEQ_030] = { enpcs = { yoyobina(QFLAG_TALK), challenger(QFLAG_OFF) }, markers = { MRKR_YOYOBINA4 } },
	[SEQ_040] = { enpcs = { trigger(QFLAG_PUSH), yoyobina(QFLAG_OFF), challenger(QFLAG_OFF) }, markers = { MRKR_STANDS } },
	[SEQ_045] = { enpcs = { challenger(QFLAG_TALK), yoyobina(QFLAG_OFF) }, markers = { MRKR_CHALLENGER2 } },
	[SEQ_050] = { enpcs = { trigger(QFLAG_PUSH) }, markers = { MRKR_BAZAAR } },
	[SEQ_055] = { enpcs = { { LULUTSU, QFLAG_REWARD } }, markers = { MRKR_LULUTSU } },
}

-- Opens a bout after its gate scene (on a yes) and the join ask; a lost bout keeps the step.
local function enterBout(player, quest, gateEvent, entryScene, content, director)
	if delegateEvent(player, quest, gateEvent) ~= 1 then
		return false
	end
	if delegateEvent(player, quest, "contentsJoinAskInBasaClass") ~= 1 then
		return false
	end
	delegateEvent(player, quest, entryScene)
	startQuestContent(player, {
		zone = 209, content = content, director = director,
		x = BOUT_ENTRY[1], y = BOUT_ENTRY[2], z = BOUT_ENTRY[3], rot = BOUT_ENTRY[4],
	})
	return true
end

-- A scene that fades in only after a warp: the player is re-placed at the scene's own spot.
local function warpScene(player, quest, eventName, nextSequence, spot)
	delegateEvent(player, quest, eventName)
	player:EndEvent()
	quest:StartSequence(nextSequence)
	warpToPost(player, spot)
end

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(LULUTSU, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	local name = npcName(npc)

	if sequence == SEQ_ACCEPT and classId == LULUTSU then
		local accepted = delegateEvent(player, quest, "processEventLulutsuStart")
		player:EndEvent()
		if accepted == 1 then
			player:AcceptQuest(quest)
		end
		return
	elseif classId == YOYOBINA and name == SPAWN_YOYOBINA_FIRST then
		if sequence == SEQ_000 then
			delegateEvent(player, quest, "processEvent003")
			quest:StartSequence(SEQ_005)
		elseif sequence == SEQ_005 then
			if enterBout(player, quest, "processEvent005", "processEvent010", "SimpleContentGla30601", "Quest/QuestDirectorGla30601") then
				return
			end
		end
	elseif classId == YOYOBINA and name == SPAWN_YOYOBINA_SECOND then
		if sequence == SEQ_023 then
			delegateEvent(player, quest, "processEvent023")
			quest:StartSequence(SEQ_024)
		elseif sequence == SEQ_030 then
			warpScene(player, quest, "processEvent030", SEQ_040, YOYOBINA_SECOND_POST)
			return
		end
	elseif classId == CHALLENGER and name == SPAWN_CHALLENGER and sequence == SEQ_024 then
		if enterBout(player, quest, "processEvent024", "processEvent020_999", "SimpleContentGla30602", "Quest/QuestDirectorGla30602") then
			return
		end
	elseif classId == CHALLENGER and name == SPAWN_CHALLENGER2 and sequence == SEQ_045 then
		if delegateEvent(player, quest, "processEvent045") == 1 then
			player:EndEvent()
			quest:StartSequence(SEQ_050)
			warpToPost(player, CHALLENGER2_POST)
			return
		end
	elseif sequence == SEQ_055 and classId == LULUTSU then
		turnInQuest(player, quest, "processEvent055", COMPLETION_REWARDS)
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence()
	local name = npcName(npc)

	if sequence == SEQ_040 and name == SPAWN_STANDS then
		warpScene(player, quest, "processEvent040", SEQ_045, STANDS_SPOT)
		return
	elseif sequence == SEQ_050 and name == SPAWN_BAZAAR then
		warpScene(player, quest, "processEvent050", SEQ_055, BAZAAR_SPOT)
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

-- Called by QuestDirectorGla30601 on the win: the aftermath, then Yoyobina's second spot.
function finishGla306Bladedancer(player, quest, duty, area)
	delegateEvent(player, quest, "processEvent020")
	quest:StartSequence(SEQ_023)
	local p = YOYOBINA_SECOND_POST
	leaveQuestContent(player, duty, area, { zone = p[1], x = p[2], y = p[3], z = p[4], rot = p[5] })
end

-- Called by QuestDirectorGla30602 on the win: no aftermath scene.
function finishGla306Challenger(player, quest, duty, area)
	quest:StartSequence(SEQ_030)
	local p = YOYOBINA_SECOND_POST
	leaveQuestContent(player, duty, area, { zone = p[1], x = p[2], y = p[3], z = p[4], rot = p[5] })
end

-- A lost bout or the time running out returns the player where that bout was entered.
function failGla306Bout(player, quest, duty, area)
	local p = (quest:GetSequence() == SEQ_024) and CHALLENGER_POST or YOYOBINA_FIRST_POST
	leaveQuestContent(player, duty, area, { zone = p[1], x = p[2], y = p[3], z = p[4], rot = p[5] })
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
