require("Global")
require("Quest")
require("QuestFlow")

--[[

Quest Script

Name:   Good Knight, Sweet Dreams
Code:   Cnj300
Id:     110261
Prereq: Dendrological Duties (Cnj200 - 110260)

Seq 65535: Offered by Soileine (Gridania).
Seq 0:  Soileine sends the conjurer to Brother Morys at Lifemend Stump (Central Shroud).
Seq 10: Calm the elementals at Amberscale Rock (push; SimpleContentCnj30001, QuestDirectorCnj30001).
Seq 20: Report to Soileine.
Seq 30: Yuhelmeric at the Owl's Nest (Coerthas Eastern Lowlands).
Seq 40: The newly outfitted knight's Echo.
Seq 50: Morys at the forest border (North Shroud).
Seq 60: Soileine's reward.

Morys has two story spawns of one class (Lifemend Stump, forest border); the sequence picks the one that
answers. A declined or lost duty keeps 10, so the same push opens the next attempt.
Spawns, gates and class fills: Data/sql/seed/seed_quest_cnj300_01.sql.

--]]

local startElementals

local SEQ_000 = 0
SEQ_010 = 10
local SEQ_020 = 20
local SEQ_030 = 30
local SEQ_040 = 40
local SEQ_050 = 50
local SEQ_060 = 60

local SOILEINE               = 1000234
local MORYS                  = 1000505 -- cnj300_morys_lifemend (150), cnj300_morys_forest_border (152)
local YUHELMERIC             = 1000370
local NEWLY_OUTFITTED_KNIGHT = 1000573
local AMBERSCALE_TRIGGER     = 1090008 -- spawn cnj300_amberscale_trigger (Central Shroud)

local MRKR_LIFEMEND   = 11026101
local MRKR_AMBERSCALE = 11026102
local MRKR_SOILEINE   = 11026103
local MRKR_YUHELMERIC = 11026104
local MRKR_KNIGHT     = 11026105
local MRKR_BORDER     = 11026106
local MRKR_SOILEINE2  = 11026107

-- The Amberscale trigger, where the duty lands and returns.
local AMBERSCALE_ENTRY = { -543.790, 5.000, -511.350, 0.0 }

-- Completion pay: the client reward sheet has no row for this quest (questflow.lua turnInQuest).
local COMPLETION_REWARDS = { exp = 3420, gil = 30000 }


local PHASES = {
	[SEQ_000] = {
		enpcs = { { MORYS, QFLAG_TALK, spawn = true }, SOILEINE },
		markers = { MRKR_LIFEMEND },
	},
	[SEQ_010] = {
		enpcs = { { AMBERSCALE_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true } },
		markers = { MRKR_AMBERSCALE },
	},
	[SEQ_020] = {
		enpcs = { { SOILEINE, QFLAG_TALK } },
		markers = { MRKR_SOILEINE },
	},
	[SEQ_030] = {
		enpcs = { { YUHELMERIC, QFLAG_TALK, spawn = true }, SOILEINE },
		markers = { MRKR_YUHELMERIC },
	},
	[SEQ_040] = {
		enpcs = { { NEWLY_OUTFITTED_KNIGHT, QFLAG_TALK, spawn = true }, { YUHELMERIC, spawn = true } },
		markers = { MRKR_KNIGHT },
	},
	[SEQ_050] = {
		enpcs = { { MORYS, QFLAG_TALK, spawn = true }, { NEWLY_OUTFITTED_KNIGHT, spawn = true } },
		markers = { MRKR_BORDER },
	},
	[SEQ_060] = {
		enpcs = { { SOILEINE, QFLAG_REWARD } },
		markers = { MRKR_SOILEINE2 },
	},
}

local CHATTER = {
	[SEQ_000] = { [SOILEINE] = "processEvent010_2" },
	[SEQ_030] = { [SOILEINE] = "processEvent030_2" },
	[SEQ_040] = { [YUHELMERIC] = "processEvent040_1" },
	[SEQ_050] = { [NEWLY_OUTFITTED_KNIGHT] = "processEvent050_6" },
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(SOILEINE, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if sequence == SEQ_ACCEPT then
		if classId == SOILEINE and not inPrivateArea(player) then
			local accepted = delegateEvent(player, quest, "processEventSoileineStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return
		end
	elseif sequence == SEQ_000 and classId == MORYS and npcName(npc) == "cnj300_morys_lifemend" then
		delegateEvent(player, quest, "processEvent010")
		quest:StartSequence(SEQ_010)
	elseif sequence == SEQ_020 and classId == SOILEINE then
		delegateEvent(player, quest, "processEvent030")
		quest:StartSequence(SEQ_030)
	elseif sequence == SEQ_030 and classId == YUHELMERIC then
		delegateEvent(player, quest, "processEvent040")
		quest:StartSequence(SEQ_040)
	elseif sequence == SEQ_040 and classId == NEWLY_OUTFITTED_KNIGHT then
		-- The Echo goes on only on a yes; its scene plays inside the same event.
		if delegateEvent(player, quest, "processEvent050") == 1 then
			quest:StartSequence(SEQ_050)
		end
	elseif sequence == SEQ_050 and classId == MORYS and npcName(npc) == "cnj300_morys_forest_border" then
		delegateEvent(player, quest, "processEvent060")
		quest:StartSequence(SEQ_060)
	elseif sequence == SEQ_060 and classId == SOILEINE then
		turnInQuest(player, quest, "processEvent070", COMPLETION_REWARDS)
		return
	else
		delegateChatter(player, quest, CHATTER, sequence, classId)
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc, eventName)
	if quest:GetSequence() == SEQ_010 and npcName(npc) == "cnj300_amberscale_trigger" then
		delegateEvent(player, quest, "processEvent015_1")
		if delegateEvent(player, quest, "contentsJoinAskInBasaClass") == 1 then
			startElementals(player, quest)
			return
		end
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function startElementals(player, quest)
	local a = AMBERSCALE_ENTRY
	startQuestContent(player, {
		zone = 150, content = "SimpleContentCnj30001", director = "Quest/QuestDirectorCnj30001",
		x = a[1], y = a[2], z = a[3], rot = a[4],
	})
end

-- QuestDirectorCnj30001, the last elemental down, with its noticeEvent open: the aftermath fades in after
-- the return warp.
function finishElementals(player, quest, duty, area)
	delegateEvent(player, quest, "processEvent020")
	quest:StartSequence(SEQ_020)
	local a = AMBERSCALE_ENTRY
	leaveQuestContent(player, duty, area, { zone = 150, x = a[1], y = a[2], z = a[3], rot = a[4] })
end

function failElementals(player, quest, duty, area)
	player:SetHP(player:GetMaxHP())
	local a = AMBERSCALE_ENTRY
	leaveQuestContent(player, duty, area, { zone = 150, x = a[1], y = a[2], z = a[3], rot = a[4] })
end

function onNotice(player, quest, target)
	player:EndEvent()
	quest:UpdateENPCs()
end

function getJournalInformation(player, quest)
	return
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
