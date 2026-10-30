require("Global")
require("Quest")
require("QuestFlow")

--[[
Thrill of the Fight (Gla306, 110082). Prereq: Gla300; Gladiator level 36.
Two spawns share Yoyobina's class and two share the challenger's; the handlers tell them apart by
spawn name. Walkthrough: Data/Docs/Scripts/Quest/Gla/Gla306.md.
--]]

local SEQ_000 = 0
SEQ_005 = 5
local SEQ_023 = 23
SEQ_024 = 24
local SEQ_030 = 30
local SEQ_040 = 40
local SEQ_045 = 45
local SEQ_050 = 50
local SEQ_055 = 55

local LULUTSU           = 1000863
local YOYOBINA          = 1001076
local CHALLENGER        = 1000601
local OBJECTIVE_TRIGGER = 1090008

local SPAWN_YOYOBINA_FIRST  = "gla300_yoyobina"
local SPAWN_YOYOBINA_SECOND = "gla306_yoyobina_second"
local SPAWN_CHALLENGER      = "gla306_echo_challenger"
local SPAWN_CHALLENGER2     = "gla306_echo_challenger2"
local SPAWN_STANDS          = "gla306_stands_trig"
local SPAWN_BAZAAR          = "gla306_bazaar_trig"

local MRKR_YOYOBINA    = 11008201
local MRKR_YOYOBINA2   = 11008202
local MRKR_YOYOBINA3   = 11008203
local MRKR_CHALLENGER  = 11008204
local MRKR_YOYOBINA4   = 11008205
local MRKR_STANDS      = 11008206
local MRKR_CHALLENGER2 = 11008207
local MRKR_BAZAAR      = 11008208
local MRKR_LULUTSU     = 11008209

-- The client reward sheet has no class-quest rows.
local COMPLETION_REWARDS = { exp = 4720, gil = 36000 }

local BOUT_ENTRY = { -187.225, 190.150, 219.730, 0.0 }
-- Own spots of the speakers and triggers whose scenes fade in only after a warp.
local YOYOBINA_FIRST_POST  = { 209, -186.340, 195.050, 188.810, 0.0 }
local YOYOBINA_SECOND_POST = { 209, -177.120, 195.050, 221.190, 0.0 }
local CHALLENGER_POST      = { 209, -177.890, 195.050, 205.090, 0.0 }
local STANDS_SPOT          = { 209, -185.260, 195.050, 179.740, 0.0 }
local CHALLENGER2_POST     = { 209, -177.400, 195.050, 222.470, 0.0 }
local BAZAAR_SPOT          = { 172, -1342.940, 56.000, 487.890, 0.0 }

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

local PHASES = {
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

-- Some scenes fade in only after a warp, so the player is moved to where the scene plays.
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

local talk = {
	[SEQ_ACCEPT] = {
		[LULUTSU] = function(player, quest)
			local accepted = delegateEvent(player, quest, "processEventLulutsuStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return true
		end,
	},
	[SEQ_000] = {
		[YOYOBINA] = function(player, quest, npc, name)
			if name == SPAWN_YOYOBINA_FIRST then
				delegateEvent(player, quest, "processEvent003")
				quest:StartSequence(SEQ_005)
			end
		end,
	},
	[SEQ_005] = {
		[YOYOBINA] = function(player, quest, npc, name)
			return name == SPAWN_YOYOBINA_FIRST
				and enterBout(player, quest, "processEvent005", "processEvent010", "SimpleContentGla30601", "Quest/QuestDirectorGla30601")
		end,
	},
	[SEQ_023] = {
		[YOYOBINA] = function(player, quest, npc, name)
			if name == SPAWN_YOYOBINA_SECOND then
				delegateEvent(player, quest, "processEvent023")
				quest:StartSequence(SEQ_024)
			end
		end,
	},
	[SEQ_024] = {
		[CHALLENGER] = function(player, quest, npc, name)
			return name == SPAWN_CHALLENGER
				and enterBout(player, quest, "processEvent024", "processEvent020_999", "SimpleContentGla30602", "Quest/QuestDirectorGla30602")
		end,
	},
	[SEQ_030] = {
		[YOYOBINA] = function(player, quest, npc, name)
			if name == SPAWN_YOYOBINA_SECOND then
				warpScene(player, quest, "processEvent030", SEQ_040, YOYOBINA_SECOND_POST)
				return true
			end
		end,
	},
	[SEQ_045] = {
		[CHALLENGER] = function(player, quest, npc, name)
			if name == SPAWN_CHALLENGER2 and delegateEvent(player, quest, "processEvent045") == 1 then
				player:EndEvent()
				quest:StartSequence(SEQ_050)
				warpToPost(player, CHALLENGER2_POST)
				return true
			end
		end,
	},
	[SEQ_055] = {
		[LULUTSU] = function(player, quest)
			turnInQuest(player, quest, "processEvent055", COMPLETION_REWARDS)
			return true
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc, npcName(npc)) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

-- Both objective triggers share a class; the spawn name tells them apart.
local push = {
	[SEQ_040] = {
		other = function(player, quest, npc, name)
			if name == SPAWN_STANDS then
				warpScene(player, quest, "processEvent040", SEQ_045, STANDS_SPOT)
				return true
			end
		end,
	},
	[SEQ_050] = {
		other = function(player, quest, npc, name)
			if name == SPAWN_BAZAAR then
				warpScene(player, quest, "processEvent050", SEQ_055, BAZAAR_SPOT)
				return true
			end
		end,
	},
}

function onPush(player, quest, npc)
	if runQuestHandler(push, player, quest, npc, npcName(npc)) then return end
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
