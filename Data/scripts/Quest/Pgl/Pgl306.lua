require("Global")
require("Quest")
require("QuestFlow")

--[[
Two Sides to Every Chip (Pgl306, 110062). Prereq: Pgl300; Pugilist level 36. Offered by Gagaruna.
Hurrey's, Titinin's and Gagaruna's scenes fade in only after a warp, so each re-places the
player at the speaker's post. Walkthrough: Data/Docs/Scripts/Quest/Pgl/Pgl306.md.
--]]

local leaveBazaar

local SEQ_000 = 0
local SEQ_020 = 20
local SEQ_030 = 30
SEQ_040 = 40
local SEQ_050 = 50
local SEQ_060 = 60
local SEQ_070 = 70
local SEQ_080 = 80

local GAGARUNA           = 1000862
local TITININ            = 1000934
local HURREY             = 1000603
local LEWENAS_HANDMAIDEN = 1001013
local OBJECTIVE_TRIGGER  = 1090008

local MRKR_OBJECTIVE          = 11006201
local MRKR_HURREY             = 11006202
local MRKR_LEWENAS_HANDMAIDEN = 11006203
local MRKR_OBJECTIVE2         = 11006204
local MRKR_GAGARUNA           = 11006205
local MRKR_TITININ            = 11006206

local BAZAAR_TRIGGER_NAME = "pgl306_silver_bazaar_trigger"

-- The ambush lands at the bazaar trigger and returns there.
local BAZAAR_TRIGGER = { 172, -1387.260, 56.000, 304.200, 0.000 }
local HURREY_POST    = { 175, -178.460, 190.000, 102.620, 0.000 }
local TITININ_POST   = { 175, -170.630, 190.010, 117.150, -1.580 }
local GAGARUNA_POST  = { 175, -184.940, 190.550, 108.870, 1.490 }

-- The client reward sheet has no row for this quest.
local COMPLETION_REWARDS = { exp = 4720, gil = 36000 }


local PHASES = {
	[SEQ_000] = { enpcs = { { HURREY, QFLAG_TALK, spawn = true } }, markers = { MRKR_OBJECTIVE } },
	[SEQ_020] = { enpcs = { { HURREY, QFLAG_TALK, spawn = true } }, markers = { MRKR_HURREY } },
	[SEQ_030] = { enpcs = { { LEWENAS_HANDMAIDEN, QFLAG_TALK, spawn = true } }, markers = { MRKR_LEWENAS_HANDMAIDEN } },
	[SEQ_040] = {
		enpcs = { { OBJECTIVE_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true } },
		markers = { MRKR_OBJECTIVE2 },
	},
	[SEQ_050] = { enpcs = { { TITININ, QFLAG_TALK } }, markers = { MRKR_TITININ } },
	[SEQ_060] = { enpcs = { { GAGARUNA, QFLAG_TALK } }, markers = { MRKR_GAGARUNA } },
	[SEQ_070] = { enpcs = { { GAGARUNA, QFLAG_TALK } }, markers = { MRKR_GAGARUNA } },
	[SEQ_080] = { enpcs = { { GAGARUNA, QFLAG_REWARD } }, markers = { MRKR_GAGARUNA } },
}

local function warpToPost(player, p)
	warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
end

local function playWarpScene(player, quest, eventName, nextSequence, post)
	delegateEvent(player, quest, eventName)
	player:EndEvent()
	quest:StartSequence(nextSequence)
	warpToPost(player, post)
end

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(GAGARUNA, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

local talk = {
	[SEQ_ACCEPT] = {
		[GAGARUNA] = function(player, quest, npc)
			local accepted = delegateEvent(player, quest, "processEventGagarunaStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return true
		end,
	},
	[SEQ_000] = {
		[HURREY] = function(player, quest, npc)
			playWarpScene(player, quest, "processEvent020", SEQ_020, HURREY_POST)
			return true
		end,
	},
	[SEQ_020] = {
		[HURREY] = function(player, quest, npc)
			-- An Echo advances only on a yes.
			if delegateEvent(player, quest, "processEvent030") == 1 then
				quest:StartSequence(SEQ_030)
			end
		end,
	},
	[SEQ_030] = {
		[LEWENAS_HANDMAIDEN] = function(player, quest, npc)
			if delegateEvent(player, quest, "processEvent040") == 1 then
				quest:StartSequence(SEQ_040)
			end
		end,
	},
	[SEQ_050] = {
		[TITININ] = function(player, quest, npc)
			playWarpScene(player, quest, "processEvent060", SEQ_060, TITININ_POST)
			return true
		end,
	},
	[SEQ_060] = {
		[GAGARUNA] = function(player, quest, npc)
			playWarpScene(player, quest, "processEvent070", SEQ_070, GAGARUNA_POST)
			return true
		end,
	},
	[SEQ_070] = {
		[GAGARUNA] = function(player, quest, npc)
			delegateEvent(player, quest, "processEvent080")
			quest:StartSequence(SEQ_080)
		end,
	},
	[SEQ_080] = {
		[GAGARUNA] = function(player, quest, npc)
			turnInQuest(player, quest, "processEvent090", COMPLETION_REWARDS)
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
	local classId = npc:GetActorClassId()

	if sequence == SEQ_040 and classId == OBJECTIVE_TRIGGER and npcName(npc) == BAZAAR_TRIGGER_NAME then
		if delegateEvent(player, quest, "contentsJoinAskInBasaClass") == 1 then
			local p = BAZAAR_TRIGGER
			startQuestContent(player, {
				zone = p[1], content = "SimpleContentPgl30601", director = "Quest/QuestDirectorPgl30601",
				x = p[2], y = p[3], z = p[4], rot = p[5],
			})
			return
		end
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

-- Called by QuestDirectorPgl30601 once both almstakers are down: the aftermath beside Hurrey.
function finishBazaarAmbush(player, quest, duty, area)
	delegateEvent(player, quest, "processEvent050")
	quest:StartSequence(SEQ_050)
	leaveBazaar(player, duty, area)
end

function failBazaarAmbush(player, quest, duty, area)
	leaveBazaar(player, duty, area)
end

function leaveBazaar(player, duty, area)
	local p = BAZAAR_TRIGGER
	leaveQuestContent(player, duty, area, { zone = p[1], x = p[2], y = p[3], z = p[4], rot = p[5] })
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
