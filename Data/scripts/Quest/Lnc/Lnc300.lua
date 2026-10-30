require("Global")
require("Quest")
require("QuestFlow")

--[[
Culture Shock (Lnc300, 110181). Prereq: Lnc200; Lancer level 30. Offered by J'moldva, whose
offer asks nothing: the quest is taken once it closes. Walkthrough: Data/Docs/Scripts/Quest/Lnc/Lnc300.md.
--]]

local SEQ_000 = 0
local SEQ_010 = 10
local SEQ_020 = 20
SEQ_030 = 30
local SEQ_040 = 40
local SEQ_050 = 50
local SEQ_060 = 60

local WILLELDA          = 1000242
local JMOLDVA           = 1000599
local GAGARUNA          = 1000862
local DREUES            = 1000402
local BROKER            = 1000403
local OBJECTIVE_TRIGGER = 1090008

local SPAWN_CARAVAN = "lnc300_caravan_trig"
local SPAWN_BROKER  = "lnc300_brazen_broker"

local MRKR_GAGARUNA  = 11018101
local MRKR_JMOLDVA   = 11018102
local MRKR_OBJECTIVE = 11018103
local MRKR_BROKER    = 11018104
local MRKR_JMOLDVA2  = 11018105
local MRKR_WILLELDA  = 11018106
local MRKR_DREUES    = 11018107

-- The client reward sheet has no class-quest rows.
local COMPLETION_REWARDS = { exp = 3420, gil = 30000 }

-- The defense lands at the caravan trigger and a loss returns there; a win returns to the broker.
local CARAVAN_ENTRY = { 150, 379.700, 6.188, -14.300, 0.0 }
local BROKER_POST   = { 206, 187.480, 27.500, -1583.960, 0.0 }

local PHASES = {
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

local function step(scene, nextSequence)
	return function(player, quest)
		delegateEvent(player, quest, scene)
		quest:StartSequence(nextSequence)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[JMOLDVA] = function(player, quest)
			delegateEvent(player, quest, "processEventJMoldvaStart")
			player:EndEvent()
			player:AcceptQuest(quest)
			return true
		end,
	},
	[SEQ_000] = { [GAGARUNA] = step("processEvent020", SEQ_010) },
	[SEQ_010] = { [DREUES] = step("processEvent030", SEQ_020) },
	[SEQ_020] = { [JMOLDVA] = step("processEvent040", SEQ_030) },
	[SEQ_040] = {
		[BROKER] = function(player, quest, npc)
			if npcName(npc) == SPAWN_BROKER then
				step("processEvent068", SEQ_050)(player, quest)
			end
		end,
	},
	[SEQ_050] = { [JMOLDVA] = step("processEvent070", SEQ_060) },
	[SEQ_060] = {
		[WILLELDA] = function(player, quest)
			turnInQuest(player, quest, "processEvent075", COMPLETION_REWARDS)
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
