require("Global")
require("Quest")
require("QuestFlow")

--[[
Unalienable Rights (Gla300, quest 110081). Follows Gla200, Gladiator level 30. Offered by Lulutsu
(processEventLulutsuStart, accepted on 1).

Seq 0:   Miounne in Gridania.
Seq 10:  Willelda's choice (processEvent025, moves on a yes).
Seq 15:  J'moldva's challenge: the join ask, processEvent030, then the fight (content SimpleContentGla30001,
         QuestDirectorGla30001). A lost fight keeps 15.
Seq 20:  J'moldva's Echo after the fight (processEvent050, moves on a yes).
Seq 30:  The report to Lulutsu.
Seq 40:  Yoyobina's Echo (processEvent065 asks; processEvent060, then the fade-in beside her).
Seq 50:  Yoyobina's follow-up.
Seq 60:  Lulutsu's reward.

Completion: processEvent090, then COMPLETION_REWARDS.
Spawns and class fills: Data/sql/seed/seed_quest_gla300_01.sql.
--]]

local SEQ_000 = 0
local SEQ_010 = 10
SEQ_015 = 15
local SEQ_020 = 20
local SEQ_030 = 30
local SEQ_040 = 40
local SEQ_050 = 50
local SEQ_060 = 60

local LULUTSU  = 1000863
local MIOUNNE  = 1000230
local WILLELDA = 1000242
local JMOLDVA  = 1000599
local YOYOBINA = 1001076

local MRKR_MIOUNNE   = 11008101
local MRKR_WILLELDA  = 11008102
local MRKR_JMOLDVA   = 11008103
local MRKR_JMOLDVA2  = 11008104
local MRKR_LULUTSU   = 11008105
local MRKR_YOYOBINA  = 11008106
local MRKR_YOYOBINA2 = 11008107
local MRKR_LULUTSU2  = 11008108

-- The client reward sheet has no class-quest rows.
local COMPLETION_REWARDS = { exp = 3420, gil = 30000 }

-- The challenge lands at Willelda's post and returns there.
local WILLELDA_POST = { 206, 179.150, 27.500, -1580.590, -1.450 }
-- Yoyobina's scenes fade in only after a warp back beside her.
local YOYOBINA_POST = { 209, -186.340, 195.050, 188.810, 0.0 }

local function warpToPost(player, p)
	warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
end

local PHASES = {
	[SEQ_000] = { enpcs = { { MIOUNNE, QFLAG_TALK } }, markers = { MRKR_MIOUNNE } },
	[SEQ_010] = { enpcs = { { WILLELDA, QFLAG_TALK } }, markers = { MRKR_WILLELDA } },
	[SEQ_015] = { enpcs = { { JMOLDVA, QFLAG_TALK } }, markers = { MRKR_JMOLDVA } },
	[SEQ_020] = { enpcs = { { JMOLDVA, QFLAG_TALK } }, markers = { MRKR_JMOLDVA2 } },
	[SEQ_030] = { enpcs = { { LULUTSU, QFLAG_TALK } }, markers = { MRKR_LULUTSU } },
	[SEQ_040] = { enpcs = { { YOYOBINA, QFLAG_TALK, spawn = true } }, markers = { MRKR_YOYOBINA } },
	[SEQ_050] = { enpcs = { { YOYOBINA, QFLAG_TALK, spawn = true } }, markers = { MRKR_YOYOBINA2 } },
	[SEQ_060] = { enpcs = { { LULUTSU, QFLAG_REWARD } }, markers = { MRKR_LULUTSU2 } },
}

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
		[LULUTSU] = function(player, quest, npc)
			local accepted = delegateEvent(player, quest, "processEventLulutsuStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return true
		end,
	},
	[SEQ_000] = {
		[MIOUNNE] = function(player, quest, npc)
			delegateEvent(player, quest, "processEvent020")
			quest:StartSequence(SEQ_010)
		end,
	},
	[SEQ_010] = {
		[WILLELDA] = function(player, quest, npc)
			if delegateEvent(player, quest, "processEvent025") == 1 then
				quest:StartSequence(SEQ_015)
			end
		end,
	},
	[SEQ_015] = {
		[JMOLDVA] = function(player, quest, npc)
			if delegateEvent(player, quest, "contentsJoinAskInBasaClass") == 1 then
				delegateEvent(player, quest, "processEvent030")
				local p = WILLELDA_POST
				startQuestContent(player, {
					zone = p[1], content = "SimpleContentGla30001", director = "Quest/QuestDirectorGla30001",
					x = p[2], y = p[3], z = p[4], rot = p[5],
				})
				return true
			end
		end,
	},
	[SEQ_020] = {
		[JMOLDVA] = function(player, quest, npc)
			if delegateEvent(player, quest, "processEvent050") == 1 then
				quest:StartSequence(SEQ_030)
			end
		end,
	},
	[SEQ_030] = {
		[LULUTSU] = function(player, quest, npc)
			delegateEvent(player, quest, "processEvent055")
			quest:StartSequence(SEQ_040)
		end,
	},
	[SEQ_040] = {
		[YOYOBINA] = function(player, quest, npc)
			if delegateEvent(player, quest, "processEvent065") == 1 then
				delegateEvent(player, quest, "processEvent060")
				player:EndEvent()
				quest:StartSequence(SEQ_050)
				warpToPost(player, YOYOBINA_POST)
				return true
			end
		end,
	},
	[SEQ_050] = {
		[YOYOBINA] = function(player, quest, npc)
			delegateEvent(player, quest, "processEvent070")
			player:EndEvent()
			quest:StartSequence(SEQ_060)
			warpToPost(player, YOYOBINA_POST)
			return true
		end,
	},
	[SEQ_060] = {
		[LULUTSU] = function(player, quest, npc)
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

-- Called by QuestDirectorGla30001 on the win.
function finishGla300Challenge(player, quest, duty, area)
	delegateEvent(player, quest, "processEvent040")
	quest:StartSequence(SEQ_020)
	local p = WILLELDA_POST
	leaveQuestContent(player, duty, area, { zone = p[1], x = p[2], y = p[3], z = p[4], rot = p[5] })
end

function failGla300Challenge(player, quest, duty, area)
	local p = WILLELDA_POST
	leaveQuestContent(player, duty, area, { zone = p[1], x = p[2], y = p[3], z = p[4], rot = p[5] })
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
