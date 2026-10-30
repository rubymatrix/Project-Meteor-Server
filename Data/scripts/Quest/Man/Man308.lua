require("Global")
require("Quest")
require("QuestFlow")

--[[
Lord Errant (Man308, quest 110017). Follows Forever Taken (Man304); level 38.

Seq 1:  held: Forever Taken's payout grants the quest silently (player:AddQuest) and the companion calls
        on the Path of the Twelve pearl. The journal has no paragraph for 1. The Gold Court trigger
        (Ul'dah 209) opens the Gold Court content, where the companion offers the quest (pES, accept
        window; 1 = accepted). Back on the plaza at Seq 0. A character who finished Forever Taken without
        the hand-on gets the same offer at Seq 65535.
Seq 0:  the Paglth'an gate (Southern Thanalan): pE01 (man30800 in place) -> 5.
Seq 5:  the southwest approach: duty ask, pE10 (man30810, a8 false = fade after warp) -> 10, into the cell
        (content SimpleContentMan30802, QuestDirectorEventMan30801).
Seq 10: the cell: both prisoners (processEvent020_1/_2), then the companion (pE20, the plan) arms the cave
        exit; the exit asks, pE30 (man30830) -> 15 and the Bowl. A relog that dropped the cell: the public
        approach relaunches it.
Seq 15: the Bowl of Embers (content SimpleContentMan30803, QuestDirectorEventMan30802): on landing pE50
        (HQ man40640 + man30850) and pE60 (man30860), journal int3 = 1; stop the three tempered captives
        (each withdraws at its HP floor), then the Amalj'aa war party (30 minutes). Win: pE80 (man30880 +
        man30890) -> 20 at the Paglth'an gates. A loss keeps 15; the public approach relaunches it.
Seq 20: Tataru in the Waking Sands: pE90 (man30900, after warp) out to an Ul'dah street, where the
        after-warp notice pays the reward window and completes.

Journal phases: 0, 5, 10-19 (int3 = the ritual seen) and 20. pE90 hands a4 straight to the
cutscene, so it takes the companion's class id, not the skin.
Data: Data/sql/seed/seed_quest_man308_01.sql (+ the m3g_man308_* triggers in
seed_msq_gridania_10_man3xx.sql).
--]]

local startGoldCourt, enterAtApproach, leaveCellByCave, reportToTataru, payReward, sandsPush

local SEQ_000 = 0
SEQ_HELD = 1
local SEQ_005 = 5
local SEQ_010 = 10
SEQ_015 = 15
local SEQ_020 = 20

local GOLD_COURT_TRIGGER     = 1090187
local GATE_TRIGGER           = 1090216
local APPROACH_TRIGGER       = 1090217 -- also the cell's cave exit
local CLOUDY_EYED_PRISONER   = 1001390
local EMOTIONLESS_PRISONER   = 1001391
local SNPC_BASE              = 1070000 -- the Path companion's class is SNPC_BASE + skin

local TATARU                 = 1001046
local SERANELIEN             = 1001378
local SAHJA_ZHWAN            = 1001373
local GODFREY                = 1001375
local FENANA                 = 1001376
local NONORU                 = 1001377
local SATZFLOH               = 1001228
local PERCEVAINS             = 1001229
local UNA_TAYUUN             = 1001230
local TROUBLED_TRADER        = 1000812
local BURLY_VOICED_BRUTE     = 1001379
local NONCHALANT_GOLDSMITH   = 1001015
local SOIL_SCENTED_BOTANIST  = 1000835
local STERN_FACED_SEA_WOLF   = 1001222

local MARKET_ENTRANCE_ULDAH  = 1090265
local SANDS_EXIT_DOOR        = 1090160
local OFFICE_WEST_DOOR       = 1090161
local OFFICE_EAST_DOOR       = 1090162

local MRKR_GATE              = 11001701
local MRKR_APPROACH          = 11001702
local MRKR_MARKET_ENTRANCE   = 11001704
local MRKR_CAVE_EXIT         = 11001705
local MRKR_CLOUDY_EYED       = 11001706
local MRKR_EMOTIONLESS       = 11001707
local MRKR_COMPANION         = 11001708
-- The client ships no 110017 marker on Tataru; Fade to White's Tataru row stands in.
local MRKR_SANDS_TATARU      = 11001303

local FLAG_CLOUDY_TALKED       = 0
local FLAG_EMOTIONLESS_TALKED  = 1
local FLAG_COMPANION_BRIEFED   = 2
FLAG_RITUAL_SEEN         = 3
local FLAG_BOWL_WON            = 4
local FLAG_REWARD_SCENE_SEEN   = 5
FLAG_MAID_SETTLED        = 12
FLAG_ELEZEN_SETTLED      = 13
FLAG_MIDLANDER_SETTLED   = 14
FLAG_CAPTIVES_STOPPED    = 15

CNTR_CAPTIVES_SUBDUED    = 0

local TEXT_ENTERED_INSTANCE    = 34108
-- man308 rows 635-643: the companion's call, one row per personality position.
local TEXT_COMPANION_CALL      = 635
local NPCLS_PATH_OF_THE_TWELVE = 6

local SANDS_ZONE = 181

local QUEST_LEVEL = 38

-- Points: { zone, x, y, z, rot }
local GOLD_COURT_ENTRY = { 209, -147.633, 198.0, 160.064, 0.0 }
local CELL_ENTRY       = { 174, 1000.714, 308.565, 985.779, 1.541 }
local BOWL_ENTRY       = { 240, 2533.785, 249.349, 2213.483, -1.758 }
local GATES_LANDING    = { 174, 1217.65, 311.707, 776.001, -0.931 }
local BOWL_EJECT       = { 174, 1134.053, 312.43, 830.706, -1.649 }
local ULDAH_STREET     = { 175, -216.52, 190.0, 30.5, 2.32 }
local SANDS_ENTRY      = { 181, -205.25, 0.0, -160.0, 1.55 }
local OFFICE_INSIDE    = { -126.2, 1.2, -160.0, 1.6 }
local OFFICE_OUTSIDE   = { -142.75, 1.0, -160.0, -1.6 }

local AFTER_WARP_NOTICE = true

-- The Path companion's talk reaches this quest (PopulaceSnpcStandard), so the companion makes the
-- offer and tells the plan. With false, the Gold Court director plays the offer on landing and the
-- cave exit plays the plan.
SNPC_TALK_ROUTED = true

local function companionClass(player)
	return SNPC_BASE + player:GetSNpcSkin()
end

-- The companion tuple the pE functions take as a3..a7.
function companionEvent(player, quest, eventName, ...)
	return delegateEvent(player, quest, eventName, player:GetSNpcNickname(), player:GetSNpcSkin(),
		player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown(), ...)
end

local function inSands(player)
	return currentZoneId(player) == SANDS_ZONE
end

local function outOfSands(player)
	return currentZoneId(player) ~= SANDS_ZONE
end

local function bothPrisonersHeard(data)
	return data:GetFlag(FLAG_CLOUDY_TALKED) and data:GetFlag(FLAG_EMOTIONLESS_TALKED)
end

local function isBriefed(data)
	return data:GetFlag(FLAG_COMPANION_BRIEFED) or (not SNPC_TALK_ROUTED and bothPrisonersHeard(data))
end

local function isCloudyMarked(player, quest, data)
	return not data:GetFlag(FLAG_CLOUDY_TALKED)
end

local function isEmotionlessMarked(player, quest, data)
	return not data:GetFlag(FLAG_EMOTIONLESS_TALKED)
end

local function isCompanionMarked(player, quest, data)
	return bothPrisonersHeard(data) and not isBriefed(data)
end

local function isCaveExitMarked(player, quest, data)
	return isBriefed(data)
end

local function push(classId, icon)
	return { classId, icon or QFLAG_OFF, talk = false, push = true }
end

local function trigger(classId)
	return { classId, QFLAG_PUSH, talk = false, push = true, spawn = true }
end

local function isLevelMet(player)
	return player:GetLevel() >= QUEST_LEVEL
end

local PHASES = {
	-- Below the level the Gold Court trigger stays dark and inert.
	[SEQ_HELD] = {
		enpcs = { { GOLD_COURT_TRIGGER, QFLAG_PUSH, when = isLevelMet, talk = false, push = isLevelMet, spawn = true } },
	},
	[SEQ_000] = { enpcs = { trigger(GATE_TRIGGER) }, markers = { MRKR_GATE } },
	[SEQ_005] = { enpcs = { trigger(APPROACH_TRIGGER) }, markers = { MRKR_APPROACH } },
	-- The approach stays armed so a relog that dropped the cell relaunches it; in the cell the same class
	-- is the cave exit.
	[SEQ_010] = {
		enpcs = {
			{ CLOUDY_EYED_PRISONER, QFLAG_TALK, when = isCloudyMarked },
			{ EMOTIONLESS_PRISONER, QFLAG_TALK, when = isEmotionlessMarked },
			trigger(APPROACH_TRIGGER),
		},
		markers = {
			{ MRKR_CLOUDY_EYED, when = isCloudyMarked },
			{ MRKR_EMOTIONLESS, when = isEmotionlessMarked },
			{ MRKR_COMPANION, when = isCompanionMarked },
			{ MRKR_CAVE_EXIT, when = isCaveExitMarked },
		},
	},
	-- A lost or dropped Bowl relaunches from the approach.
	[SEQ_015] = { enpcs = { trigger(APPROACH_TRIGGER) } },
	[SEQ_020] = {
		enpcs = {
			{ TATARU, QFLAG_REWARD },
			SERANELIEN, SAHJA_ZHWAN, GODFREY, FENANA, NONORU, SATZFLOH, PERCEVAINS, UNA_TAYUUN,
			-- The Merchants Ward has no public spawn of these; this quest's own rows bring them.
			{ TROUBLED_TRADER, spawn = true }, { BURLY_VOICED_BRUTE, spawn = true },
			{ NONCHALANT_GOLDSMITH, spawn = true }, { SOIL_SCENTED_BOTANIST, spawn = true },
			{ STERN_FACED_SEA_WOLF, spawn = true },
			push(MARKET_ENTRANCE_ULDAH), push(SANDS_EXIT_DOOR), push(OFFICE_WEST_DOOR), push(OFFICE_EAST_DOOR),
		},
		markers = {
			{ MRKR_MARKET_ENTRANCE, when = outOfSands },
			{ MRKR_SANDS_TATARU, when = inSands },
		},
	},
}

-- The Waking Sands after the Bowl (man308 rows 600-622). The long-legged lady's 090_13 has no spawn.
local CHATTER = {
	[SEQ_020] = {
		[SERANELIEN] = "processEvent090_1", [SAHJA_ZHWAN] = "processEvent090_2", [GODFREY] = "processEvent090_3",
		[FENANA] = "processEvent090_4", [NONORU] = "processEvent090_5", [SATZFLOH] = "processEvent090_6",
		[PERCEVAINS] = "processEvent090_7", [UNA_TAYUUN] = "processEvent090_8",
		[TROUBLED_TRADER] = "processEvent090_9", [BURLY_VOICED_BRUTE] = "processEvent090_10",
		[NONCHALANT_GOLDSMITH] = "processEvent090_11", [SOIL_SCENTED_BOTANIST] = "processEvent090_12",
		[STERN_FACED_SEA_WOLF] = "processEvent090_14",
	},
}

-- Granted (Forever Taken's hand-on) or accepted on an old character's offer: held either way; the
-- offer moves a held quest to 0. The companion's call arms once per grant.
function onStart(player, quest)
	quest:StartSequenceForNpcLs(SEQ_HELD)
	callNpcLs(quest, NPCLS_PATH_OF_THE_TWELVE)
end

local function isOffer(sequence)
	return sequence == SEQ_ACCEPT or sequence == SEQ_HELD
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		-- The journal ships no Gold Court marker: the trigger's circle is the only cue.
		quest:SetENpc(GOLD_COURT_TRIGGER, QFLAG_PUSH, false, true, false, true)
		quest:SetENpc(companionClass(player), QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
	if sequence == SEQ_HELD then
		quest:SetENpc(companionClass(player), QFLAG_TALK)
	end

	-- The companion's class depends on the player, so it stays out of the phase table.
	if sequence == SEQ_010 then
		local data = quest:GetData()
		quest:SetENpc(companionClass(player), isCompanionMarked(player, quest, data) and QFLAG_TALK or QFLAG_OFF)
	elseif sequence == SEQ_015 then
		-- No man308 line exists for the companion in the Bowl.
		quest:SetENpc(companionClass(player))
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if isOffer(sequence) then
		if classId == companionClass(player) and inPrivateArea(player) then
			offerAtGoldCourt(player, quest)
			return
		end
	elseif sequence == SEQ_010 and classId == CLOUDY_EYED_PRISONER then
		delegateEvent(player, quest, "processEvent020_1")
		setQuestFlagOn(quest, FLAG_CLOUDY_TALKED)
	elseif sequence == SEQ_010 and classId == EMOTIONLESS_PRISONER then
		delegateEvent(player, quest, "processEvent020_2")
		setQuestFlagOn(quest, FLAG_EMOTIONLESS_TALKED)
	elseif sequence == SEQ_010 and classId == companionClass(player) then
		-- The plan repeats any time; the exit opens once both prisoners were heard first.
		companionEvent(player, quest, "pE20")
		if bothPrisonersHeard(quest:GetData()) then
			setQuestFlagOn(quest, FLAG_COMPANION_BRIEFED)
		end
	elseif sequence == SEQ_020 and classId == TATARU then
		if not getQuestFlag(quest, FLAG_REWARD_SCENE_SEEN) then
			reportToTataru(player, quest)
		else
			-- The after-warp notice never came: pay here.
			payReward(player, quest)
		end
		return
	else
		delegateChatter(player, quest, CHATTER, sequence, classId)
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc, eventName)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if isOffer(sequence) then
		if classId == GOLD_COURT_TRIGGER and not inPrivateArea(player) and isLevelMet(player) then
			startGoldCourt(player)
			return
		end
	elseif sandsPush(player, classId) then
		return
	elseif sequence == SEQ_000 and classId == GATE_TRIGGER then
		companionEvent(player, quest, "pE01")
		quest:StartSequence(SEQ_005)
	elseif classId == APPROACH_TRIGGER then
		if inPrivateArea(player) then
			if sequence == SEQ_010 then
				leaveCellByCave(player, quest)
				return
			end
		elseif sequence == SEQ_005 or sequence == SEQ_010 or sequence == SEQ_015 then
			enterAtApproach(player, quest, sequence)
			return
		end
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function startGoldCourt(player)
	local p = GOLD_COURT_ENTRY
	startQuestContent(player, { zone = p[1], content = "SimpleContentMan30801", director = "Quest/QuestDirectorMan30801",
		x = p[2], y = p[3], z = p[4], rot = p[5] })
end

-- pES: lines, the accept window, more lines; 1 = accepted. The player stays where they stood when the
-- content drops.
function offerAtGoldCourt(player, quest)
	local answer = companionEvent(player, quest, "pES")
	player:EndEvent()
	local accepted = (answer == 1 or answer == true)
	if not accepted and SNPC_TALK_ROUTED then
		-- Declined: the companion keeps waiting for another talk.
		return
	end
	if accepted then
		if quest:GetSequence() == SEQ_ACCEPT then
			player:AcceptQuest(quest)
			quest = player:GetQuest(110017)
		end
		if quest ~= nil then
			if quest:GetData():GetNpcLsFrom() ~= 0 then
				quest:EndOfNpcLsMsgs()
			end
			quest:StartSequence(SEQ_000)
		end
	end
	local area = player.CurrentArea
	pcall(function() area:ContentFinished() end)
	local p = GOLD_COURT_ENTRY
	warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
end

local function startCell(player)
	local p = CELL_ENTRY
	startQuestContent(player, { zone = p[1], content = "SimpleContentMan30802", director = "Quest/QuestDirectorEventMan30801",
		x = p[2], y = p[3], z = p[4], rot = p[5] })
end

local function startBowl(player)
	local p = BOWL_ENTRY
	startQuestContent(player, { zone = p[1], content = "SimpleContentMan30803", director = "Quest/QuestDirectorEventMan30802",
		x = p[2], y = p[3], z = p[4], rot = p[5] })
end

-- The approach is the duty door: the first push plays the capture and opens the cell; later pushes
-- relaunch whichever content a relog or a loss dropped.
function enterAtApproach(player, quest, sequence)
	if delegateEvent(player, quest, "contentsJoinAskInBasaClass") ~= 1 then
		player:EndEvent()
		return
	end

	if sequence == SEQ_005 then
		-- The capture is bound as its own instance and released before the cell.
		player:SendGameMessage(GetWorldMaster(), TEXT_ENTERED_INSTANCE, 0x20)
		player:SendGameMessage(GetWorldMaster(), TEXT_BOUND_BY_DUTY, 0x20)
		companionEvent(player, quest, "pE10", false)
		quest:StartSequence(SEQ_010)
		player:SendGameMessage(GetWorldMaster(), TEXT_UNBOUND_FROM_DUTY, 0x20)
		startCell(player)
	elseif sequence == SEQ_010 then
		startCell(player)
	else
		startBowl(player)
	end
end

function leaveCellByCave(player, quest)
	if not isBriefed(quest:GetData()) then
		player:EndEvent()
		quest:UpdateENPCs()
		return
	end
	if delegateEvent(player, quest, "contentsJoinAskInBasaClass") ~= 1 then
		player:EndEvent()
		return
	end

	if not getQuestFlag(quest, FLAG_COMPANION_BRIEFED) then
		-- Not briefed by the companion (SNPC_TALK_ROUTED off): the plan it would have told.
		companionEvent(player, quest, "pE20")
		setQuestFlagOn(quest, FLAG_COMPANION_BRIEFED)
	end
	companionEvent(player, quest, "pE30")
	quest:StartSequence(SEQ_015)
	player:SendGameMessage(GetWorldMaster(), TEXT_UNBOUND_FROM_DUTY, 0x20)
	local area = player.CurrentArea
	pcall(function() area:ContentFinished() end)
	startBowl(player)
end

-- Called by QuestDirectorEventMan30802 once the war party is down: Ifrit's questions, then
-- back at the gates.
function finishBowl(player, quest, duty, area)
	companionEvent(player, quest, "pE80")
	setQuestFlagOn(quest, FLAG_BOWL_WON)
	quest:StartSequence(SEQ_020)
	local p = GATES_LANDING
	leaveQuestContent(player, duty, area, { zone = p[1], x = p[2], y = p[3], z = p[4], rot = p[5] })
end

function failBowl(player, quest, duty, area)
	local p = BOWL_EJECT
	leaveQuestContent(player, duty, area, { zone = p[1], x = p[2], y = p[3], z = p[4], rot = p[5] })
end

-- man30900 fades in only after a warp: out to an Ul'dah street, where the notice pays.
function reportToTataru(player, quest)
	delegateEvent(player, quest, "pE90", player:GetSNpcNickname(), companionClass(player),
		player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown())
	player:EndEvent()
	setQuestFlagOn(quest, FLAG_REWARD_SCENE_SEEN)
	local p = ULDAH_STREET
	kickAfterWarpNotice(player, p[1])
	warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
end

function onNotice(player, quest, target)
	if quest:GetSequence() == SEQ_020 and getQuestFlag(quest, FLAG_REWARD_SCENE_SEEN) then
		dismissNowLoadingVeil(player, quest)
		payReward(player, quest)
		return
	end
	player:EndEvent()
	quest:UpdateENPCs()
end

-- Of Men They Sing's distress call rides the Path pearl before Tataru's offer, so the payout hands the
-- story on silently.
function payReward(player, quest)
	if turnInQuest(player, quest) then
		player:AddQuest(110018, true)
	end
end

function sandsPush(player, classId)
	local p
	if classId == MARKET_ENTRANCE_ULDAH then
		player:EndEvent()
		p = SANDS_ENTRY
		warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
		return true
	elseif classId == SANDS_EXIT_DOOR then
		player:EndEvent()
		p = ULDAH_STREET
		warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
		return true
	elseif classId == OFFICE_WEST_DOOR then
		player:EndEvent()
		p = OFFICE_INSIDE
		bouncePlayer(player, p[1], p[2], p[3], p[4])
		return true
	elseif classId == OFFICE_EAST_DOOR then
		player:EndEvent()
		p = OFFICE_OUTSIDE
		bouncePlayer(player, p[1], p[2], p[3], p[4])
		return true
	end
	return false
end

-- Nine-row packs by personality position: the Roegadyn male (7) reads position 8 and the Miqo'te female
-- (8) position 7.
local function companionPackPosition(player)
	local personality = math.max(1, math.min(9, player:GetSNpcPersonality() or 1))
	if personality == 7 then
		return 8
	elseif personality == 8 then
		return 7
	end
	return personality
end

-- The companion's call while the quest is held (rows 635-643 by personality, the nickname as sender);
-- it arms once per grant and never moves the quest.
function onNpcLS(player, quest, from, msgStep)
	if from == NPCLS_PATH_OF_THE_TWELVE and quest:GetSequence() == SEQ_HELD then
		player:SendGameMessageDisplayName(quest, TEXT_COMPANION_CALL + companionPackPosition(player) - 1,
			MESSAGE_TYPE_NPC_LINKSHELL, player:GetSNpcNickname())
		quest:EndOfNpcLsMsgs()
	end
	player:EndEvent()
end
-- int3: the summoning seen (the 10-19 journal branch); the rows read the companion's name.
function getJournalInformation(player, quest)
	local data = quest:GetData()
	local ritual = (data ~= nil and data:GetFlag(FLAG_RITUAL_SEEN)) and 1 or 0
	return 0, ritual, 0, 0, 0, player:GetSNpcNickname()
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
