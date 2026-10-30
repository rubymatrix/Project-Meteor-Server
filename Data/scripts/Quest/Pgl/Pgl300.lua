require("Global")
require("Quest")
require("QuestFlow")

--[[
Here There Be Pirates (Pgl300, quest 110061). Pugilist level 30, after The House Always Wins.
Offered by Gagaruna in Ul'dah.

Seq 0:  Waekbyrt in Limsa Lominsa (230); the Platinum Mirage linkpearl comes with his scene.
Seq 20: Mytesyn's Bronze Kraken Key (133).
Seq 30: The boarding of the Kraken (QuestDirectorPgl30001, content SimpleContentPgl30001, zone 230). A lost
        boarding keeps 30 and Mytesyn's talk asks again. The win gives the counterfeit chip mold.
Seq 40: Titinin inspects the mold.
Seq 50: Titinin's verdict.
Seq 60: The Echoes of Hurrey, Melisie and Halstein, any order (flags 0-2); the last opens 90.
Seq 90: Gagaruna's reward.

Titinin's scenes fade in only after a warp, so each re-places the player beside him. The key and the
mold are this quest's props and leave with it. Spawns: Data/sql/seed/seed_quest_pgl300_01.sql.
--]]

local leaveKraken

local SEQ_000 = 0
local SEQ_020 = 20
SEQ_030 = 30
local SEQ_040 = 40
local SEQ_050 = 50
local SEQ_060 = 60
local SEQ_090 = 90

local GAGARUNA = 1000862
local WAEKBYRT = 1000003
local MYTESYN  = 1000167
local TITININ  = 1000934
local HURREY   = 1000603
local MELISIE  = 1001009
local HALSTEIN = 1001007

local MRKR_WAEKBYRT  = 11006101
local MRKR_MYTESYN   = 11006102
local MRKR_OBJECTIVE = 11006103
local MRKR_TITININ   = 11006104
local MRKR_HURREY    = 11006105
local MRKR_MELISIE   = 11006106
local MRKR_HALSTEIN  = 11006107
local MRKR_GAGARUNA  = 11006108

local FLAG_HURREY_HEARD   = 0
local FLAG_MELISIE_HEARD  = 1
local FLAG_HALSTEIN_HEARD = 2

local ITEM_COUNTERFEIT_CHIP_MOLD = 11000019
local ITEM_BRONZE_KRAKEN_KEY     = 11000020

local NPCLS_PLATINUM_MIRAGE = 10

local KRAKEN_DECK  = { -417.000, 41.200, 446.000, 0.000 }
local MYTESYN_POST = { 133, -435.200, 40.000, 207.070, -1.900 }
local TITININ_POST = { 175, -170.630, 190.010, 117.150, -1.580 }

local function isHurreyUnheard(player, quest, data)   return not data:GetFlag(FLAG_HURREY_HEARD) end
local function isMelisieUnheard(player, quest, data)  return not data:GetFlag(FLAG_MELISIE_HEARD) end
local function isHalsteinUnheard(player, quest, data) return not data:GetFlag(FLAG_HALSTEIN_HEARD) end

-- The client reward sheet has no row for this quest.
local COMPLETION_REWARDS = { exp = 3420, gil = 30000 }


local PHASES = {
	[SEQ_000] = { enpcs = { { WAEKBYRT, QFLAG_TALK } }, markers = { MRKR_WAEKBYRT } },
	[SEQ_020] = { enpcs = { { MYTESYN, QFLAG_TALK } }, markers = { MRKR_MYTESYN } },
	[SEQ_030] = { enpcs = { { MYTESYN, QFLAG_TALK } }, markers = { MRKR_OBJECTIVE } },
	[SEQ_040] = { enpcs = { { TITININ, QFLAG_TALK } }, markers = { MRKR_TITININ } },
	[SEQ_050] = { enpcs = { { TITININ, QFLAG_TALK } }, markers = { MRKR_TITININ } },
	-- A heard Echo leaves its speaker to the speaker's own talk.
	[SEQ_060] = {
		enpcs = function(player, quest, data)
			local list = {};
			if isHurreyUnheard(player, quest, data) then list[#list + 1] = { HURREY, QFLAG_TALK, spawn = true }; end
			if isMelisieUnheard(player, quest, data) then list[#list + 1] = { MELISIE, QFLAG_TALK }; end
			if isHalsteinUnheard(player, quest, data) then list[#list + 1] = { HALSTEIN, QFLAG_TALK }; end
			return list;
		end,
		markers = {
			{ MRKR_HURREY, when = isHurreyUnheard },
			{ MRKR_MELISIE, when = isMelisieUnheard },
			{ MRKR_HALSTEIN, when = isHalsteinUnheard },
		},
	},
	[SEQ_090] = { enpcs = { { GAGARUNA, QFLAG_REWARD } }, markers = { MRKR_GAGARUNA } },
}

local ECHOES = {
	[HURREY]   = { "processEvent060", FLAG_HURREY_HEARD },
	[MELISIE]  = { "processEvent070", FLAG_MELISIE_HEARD },
	[HALSTEIN] = { "processEvent080", FLAG_HALSTEIN_HEARD },
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

-- Completion and abandon alike: the key and the mold do not outlive the run.
function onFinish(player, quest)
	takeKeyItem(player, ITEM_BRONZE_KRAKEN_KEY)
	takeKeyItem(player, ITEM_COUNTERFEIT_CHIP_MOLD)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(GAGARUNA, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if sequence == SEQ_ACCEPT then
		if classId == GAGARUNA then
			local accepted = delegateEvent(player, quest, "processEventGagarunaStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return
		end
	elseif sequence == SEQ_000 and classId == WAEKBYRT then
		delegateEvent(player, quest, "processEvent020")
		quest:StartSequence(SEQ_020)
		player:AddNpcLs(NPCLS_PLATINUM_MIRAGE)
	elseif sequence == SEQ_020 and classId == MYTESYN then
		delegateEvent(player, quest, "processEvent025")
		giveKeyItem(player, ITEM_BRONZE_KRAKEN_KEY)
		quest:StartSequence(SEQ_030)
	elseif sequence == SEQ_030 and classId == MYTESYN then
		if delegateEvent(player, quest, "contentsJoinAskInBasaClass") == 1 then
			delegateEvent(player, quest, "processEvent030")
			local p = KRAKEN_DECK
			startQuestContent(player, {
				zone = 230, content = "SimpleContentPgl30001", director = "Quest/QuestDirectorPgl30001",
				x = p[1], y = p[2], z = p[3], rot = p[4],
			})
			return
		end
	elseif (sequence == SEQ_040 or sequence == SEQ_050) and classId == TITININ then
		-- Titinin reissues a lost mold.
		giveKeyItem(player, ITEM_COUNTERFEIT_CHIP_MOLD)
		delegateEvent(player, quest, (sequence == SEQ_040) and "processEvent040" or "processEvent050")
		player:EndEvent()
		quest:StartSequence((sequence == SEQ_040) and SEQ_050 or SEQ_060)
		local p = TITININ_POST
		warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
		return
	elseif sequence == SEQ_060 and ECHOES[classId] ~= nil then
		local echo = ECHOES[classId]
		if delegateEvent(player, quest, echo[1]) == 1 then
			setQuestFlagOn(quest, echo[2])
			local data = quest:GetData()
			if data:GetFlag(FLAG_HURREY_HEARD) and data:GetFlag(FLAG_MELISIE_HEARD) and data:GetFlag(FLAG_HALSTEIN_HEARD) then
				quest:StartSequence(SEQ_090)
			end
		end
	elseif sequence == SEQ_090 and classId == GAGARUNA then
		turnInQuest(player, quest, "processEvent090", COMPLETION_REWARDS)
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

-- Called by QuestDirectorPgl30001 once the last deckhand is down: the mold is the spoil.
function finishKrakenBoarding(player, quest, duty, area)
	quest:StartSequence(SEQ_040)
	giveKeyItem(player, ITEM_COUNTERFEIT_CHIP_MOLD)
	leaveKraken(player, duty, area)
end

function failKrakenBoarding(player, quest, duty, area)
	leaveKraken(player, duty, area)
end

function leaveKraken(player, duty, area)
	local p = MYTESYN_POST
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
