require("Global")
require("Quest")
require("QuestFlow")

--[[
Necessary Evils (Lnc306, 110182). Prereq: Lnc300; Lancer level 36.
Walkthrough: Data/Docs/Scripts/Quest/Lnc/Lnc306.md.
--]]

local SEQ_000 = 0
SEQ_010 = 10
local SEQ_020 = 20
local SEQ_030 = 30
local SEQ_040 = 40

local WILLELDA          = 1000242
local JMOLDVA           = 1000599
local BROKER            = 1000403
local OBJECTIVE_TRIGGER = 1090008

local SPAWN_CARAVAN = "lnc306_caravan_trig"
local SPAWN_BROKER  = "lnc306_brazen_broker"

local MRKR_JMOLDVA   = 11018201
local MRKR_OBJECTIVE = 11018202
local MRKR_BROKER    = 11018203
local MRKR_JMOLDVA2  = 11018204
local MRKR_WILLELDA  = 11018205

-- The client reward sheet has no class-quest rows.
local COMPLETION_REWARDS = { exp = 4720, gil = 36000 }

-- The battle lands at the south road caravan trigger and returns there.
local CARAVAN_ENTRY = { 150, 394.230, 5.455, -782.400, 0.0 }

local PHASES = {
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

local talk = {
	[SEQ_ACCEPT] = {
		[WILLELDA] = function(player, quest)
			local accepted = delegateEvent(player, quest, "processEventWilleldaStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return true
		end,
	},
	[SEQ_000] = {
		[JMOLDVA] = function(player, quest)
			delegateEvent(player, quest, "processEvent010")
			quest:StartSequence(SEQ_010)
		end,
	},
	[SEQ_020] = {
		[BROKER] = function(player, quest, npc)
			if npcName(npc) ~= SPAWN_BROKER then return end
			if delegateEvent(player, quest, "processEvent035") == 1 then
				delegateEvent(player, quest, "processEvent040")
				quest:StartSequence(SEQ_030)
			end
		end,
	},
	[SEQ_030] = {
		[JMOLDVA] = function(player, quest)
			delegateEvent(player, quest, "processEvent050")
			quest:StartSequence(SEQ_040)
		end,
	},
	[SEQ_040] = {
		[WILLELDA] = function(player, quest)
			turnInQuest(player, quest, "processEvent060", COMPLETION_REWARDS)
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
