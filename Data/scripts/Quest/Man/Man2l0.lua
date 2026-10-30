require("Global")
require("Quest")
require("QuestFlow")

--[[

Quest Script

Name:   Never the Twain Shall Meet
Code:   Man2l0
Id:     110004
Prereq: Legends Adrift (Man1l0 - 110003)

Seq 65535: Offered by Baderon.
Seq 0:  Hob at the Limsa docks: the docks push leads into the docks echo (PA 230/8), where Hob sails.
Seq 10: The dromond echo (PA 192/0): the door into the hold.
Seq 15: The hold (PA 192/1): the stairs or the deck trigger ask to start the duel.
Seq 20: The deck duel (content SimpleContentMan2l001, QuestDirectorMan2l001); a lost duel keeps 20 and
        every boarding route stays armed for a retry.
Seq 35: Baderon's briefing.
Seq 37: The sea-field outcrop (public 128) lights Baderon's linkpearl.
Seq 40: Linkpearl pending; the read moves to 42. Nothing else is armed.
Seq 42: The Marauders' Guild doors (public 230).
Seq 45: Isaudorel at the Coral Tower.
Seq 50: The Gods' Grip push into the shoreline echo (PA 128/3).
Seq 55: The shoreline echo with Y'shtola: the far push plays the ending and lands at the Wench.
Seq 70: Turn in to Baderon.

The duel: Emerick and Merodaulyn square off on the deck; the one the player attacks fights the other, and
the survivor picks the cutscene (processEvent020 a3: 1 Emerick, 2 Merodaulyn).
Completion: processEvent081_2 (a3 = level: "travel to Ul'dah" at 18+), then the reward window (500 EXP,
30000 gil, Parley from the client reward sheet).

--]]

SEQ_000 = 0
SEQ_010 = 10
SEQ_015 = 15
SEQ_020 = 20
SEQ_035 = 35
SEQ_037 = 37
SEQ_040 = 40
SEQ_042 = 42
SEQ_045 = 45
SEQ_050 = 50
SEQ_055 = 55
SEQ_070 = 70

BADERON             = 1000137
YSHTOLA             = 1000001
HOB                 = 1000151
ISAUDOREL           = 1000152
BARRACUDA_KNIGHT1   = 1000183
BARRACUDA_KNIGHT2   = 1000184
TRIGGER_DOCKS       = 1090386 -- public 230
EVENTDOOR_SHIP1     = 1090098 -- PA 192/0 (ObjectEventDoor)
EVENTDOOR_SHIP2     = 1090099 -- PA 192/1 (ObjectEventDoor)
TRIGGER_DUTYSTART   = 1090085 -- PA 192/0; the class is also a Coliseum trigger in 209
ECHO_EXIT_TRIGGER   = 1090003 -- the Marauders' Guild doors (public 230)
TRIGGER_SEAFLD      = 1090082 -- public 128
TRIGGER_SEAFLD2     = 1090086 -- public 128; the class is also used in 206
TRIGGER_SEAFLD3     = 1090087 -- PA 128/3; the class is also a public 128 cave trigger

MRKR_HOB                = 11000401
MRKR_HOLD_DOOR          = 11000402
MRKR_DECK_DOOR          = 11000403
MRKR_SEAFIELD_OUTCROP   = 11000404
MRKR_MSK_GUILD          = 11000405
MRKR_ISAUDOREL          = 11000406
MRKR_GODS_GRIP          = 11000407
MRKR_SEA_ECHO           = 11000408
MRKR_BADERON            = 11000409

CNTR_DUEL_WINNER = 0 -- 1 Emerick, 2 Merodaulyn: the survivor of the last duel won

BADERON_DISPLAY_ID = 1000015

DOCKS_ECHO      = { 230, "PrivateAreaMasterPast", 8, -631.93, 2.0, 391.75, -0.05 }
DROMOND_ARRIVAL = { 192, "PrivateAreaMasterPast", 0, 1831.541, 16.352, 1834.920, 1.569 }
DROMOND_DECK    = { 192, "PrivateAreaMasterPast", 0, 1828.785, 11.852, 1829.200, -1.675 }
DROMOND_STAIRS  = { 192, "PrivateAreaMasterPast", 0, 1821.675, 10.352, 1814.964, 2.288 }
DROMOND_HOLD    = { 192, "PrivateAreaMasterPast", 1, 1823.579, -61.65, 1816.102, 2.42 }
LIMSA_DOCKS     = { 230, nil, 0, -639.325, 1.0, 403.967, 1.655 }
SHORELINE_ECHO  = { 128, "PrivateAreaMasterPast", 3, 198.314, 25.928, 1186.126, 1.6 }
WENCH           = { 133, nil, 0, -435.501, 40.0, 202.698, -2.152 }
DUEL_ARRIVAL    = { 1829.296, 16.347, 1825.281, -0.023 }

local function warpToPoint(player, p)
	warpTo(player, p[1], p[2], p[3], p[4], p[5], p[6], p[7])
end

local function isInEcho(player)
	return inPrivateArea(player)
end

local function isOutOfEcho(player)
	return not inPrivateArea(player)
end

local function push(classId, icon)
	return { classId, icon or QFLAG_PUSH, talk = false, push = true }
end

-- The boarding span (10-20) keeps every way on and off the ship armed, across a lost duel too.
local function boardingEnpcs(doorClass, withDutyStart)
	local entries = {
		push(TRIGGER_DOCKS, QFLAG_OFF), HOB, BARRACUDA_KNIGHT1, BARRACUDA_KNIGHT2, push(doorClass),
	}
	if withDutyStart then
		entries[#entries + 1] = push(TRIGGER_DUTYSTART)
	end
	return entries
end

PHASES = {
	[SEQ_000] = {
		enpcs = { push(TRIGGER_DOCKS), { HOB, QFLAG_TALK }, BADERON },
		markers = { MRKR_HOB },
	},
	[SEQ_010] = {
		enpcs = boardingEnpcs(EVENTDOOR_SHIP1, false),
		markers = { { MRKR_HOLD_DOOR, when = isInEcho }, { MRKR_HOB, when = isOutOfEcho } },
	},
	[SEQ_015] = {
		enpcs = boardingEnpcs(EVENTDOOR_SHIP2, true),
		markers = { { MRKR_DECK_DOOR, when = isInEcho }, { MRKR_HOB, when = isOutOfEcho } },
	},
	[SEQ_020] = {
		enpcs = boardingEnpcs(EVENTDOOR_SHIP2, true),
		markers = { { MRKR_DECK_DOOR, when = isInEcho }, { MRKR_HOB, when = isOutOfEcho } },
	},
	[SEQ_035] = { enpcs = { { BADERON, QFLAG_TALK } }, markers = { MRKR_BADERON } },
	[SEQ_037] = { enpcs = { push(TRIGGER_SEAFLD), BADERON }, markers = { MRKR_SEAFIELD_OUTCROP } },
	[SEQ_040] = {},
	[SEQ_042] = { enpcs = { push(ECHO_EXIT_TRIGGER), BADERON }, markers = { MRKR_MSK_GUILD } },
	[SEQ_045] = { enpcs = { { ISAUDOREL, QFLAG_TALK } }, markers = { MRKR_ISAUDOREL } },
	[SEQ_050] = { enpcs = { push(TRIGGER_SEAFLD2), ISAUDOREL }, markers = { MRKR_GODS_GRIP } },
	[SEQ_055] = {
		enpcs = { push(TRIGGER_SEAFLD2), push(TRIGGER_SEAFLD3), YSHTOLA },
		markers = { { MRKR_SEA_ECHO, when = isInEcho }, { MRKR_GODS_GRIP, when = isOutOfEcho } },
	},
	[SEQ_070] = { enpcs = { { BADERON, QFLAG_REWARD } }, markers = { MRKR_BADERON } },
}

local BOARDING_LINES = {
	[HOB] = "processEvent010_3", [BARRACUDA_KNIGHT1] = "processEvent011_3", [BARRACUDA_KNIGHT2] = "processEvent011_4",
}

CHATTER = {
	[SEQ_000] = { [HOB] = "processEvent010_3", [BADERON] = "processEvent000_2" },
	[SEQ_010] = BOARDING_LINES,
	[SEQ_015] = BOARDING_LINES,
	[SEQ_020] = BOARDING_LINES,
	[SEQ_037] = { [BADERON] = "processEvent050_2" },
	[SEQ_042] = { [BADERON] = "processEvent060_2" },
	[SEQ_050] = { [ISAUDOREL] = "processEvent075_3" },
	[SEQ_055] = { [YSHTOLA] = "processEvent080_2" },
}

-- Baderon's linkpearl from the outcrop.
NPCLS_OUTCROP = { 40, 41 }
NPCLS_FLOW = {
	from = 1,
	sender = BADERON_DISPLAY_ID,
	packs = { [SEQ_040] = NPCLS_OUTCROP, [SEQ_042] = NPCLS_OUTCROP },
	advances = { [SEQ_040] = SEQ_042 },
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		if player:IsQuestCompleted(110003) then
			quest:SetENpc(BADERON, QFLAG_TALK)
		end
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if sequence == SEQ_ACCEPT then
		if classId == BADERON then
			delegateEvent(player, quest, "processEvent000")
			player:EndEvent()
			player:AcceptQuest(quest, true)
			return
		end
	elseif sequence == SEQ_000 and classId == HOB and currentZoneId(player) == 230 and inPrivateArea(player) then
		delegateEvent(player, quest, "processEvent010")
		player:EndEvent()
		quest:StartSequence(SEQ_010)
		warpToPoint(player, DROMOND_ARRIVAL)
		return
	elseif sequence >= SEQ_010 and sequence <= SEQ_020 and classId == HOB and inPrivateArea(player) then
		hobFerry(player, quest, sequence)
		return
	elseif sequence == SEQ_035 and classId == BADERON then
		delegateEvent(player, quest, "processEvent050")
		quest:StartSequence(SEQ_037)
	elseif sequence == SEQ_045 and classId == ISAUDOREL then
		delegateEvent(player, quest, "processEvent075")
		delegateEvent(player, quest, "processEvent075_2")
		quest:StartSequence(SEQ_050)
	elseif sequence == SEQ_070 and classId == BADERON then
		turnInQuest(player, quest, "processEvent081_2", player:GetHighestLevel())
		return
	else
		delegateChatter(player, quest, CHATTER, sequence, classId)
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

-- Hob's round trip between the docks echo and the dromond; a decline leaves the player where they stand.
function hobFerry(player, quest, sequence)
	if currentZoneId(player) == 230 then
		if delegateEvent(player, quest, "processEvent010_2") == 1 then
			player:EndEvent()
			warpToPoint(player, (sequence >= SEQ_015) and DROMOND_DECK or DROMOND_ARRIVAL)
			return
		end
	elseif currentZoneId(player) == 192 then
		if delegateEvent(player, quest, "processEvent011_2") == 1 then
			player:EndEvent()
			warpToPoint(player, LIMSA_DOCKS)
			return
		end
	else
		delegateEvent(player, quest, "processEvent010_3")
	end
	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	local zoneId = currentZoneId(player)

	-- Door classes (ObjectEventDoor) have already asked the move question in their own script.
	if sequence <= SEQ_020 and classId == TRIGGER_DOCKS then
		player:EndEvent()
		warpToPoint(player, DOCKS_ECHO)
		return
	elseif sequence == SEQ_010 and classId == EVENTDOOR_SHIP1 then
		delegateEvent(player, quest, "processEvent012")
		player:EndEvent()
		quest:StartSequence(SEQ_015)
		warpToPoint(player, DROMOND_HOLD)
		return
	elseif (sequence == SEQ_015 or sequence == SEQ_020) and classId == EVENTDOOR_SHIP2 then
		-- The hold's stairs ask for the duel; a decline still walks the player up to the deck.
		confirmDeckDuel(player, quest, true)
		return
	elseif (sequence == SEQ_015 or sequence == SEQ_020) and classId == TRIGGER_DUTYSTART and zoneId == 192 then
		confirmDeckDuel(player, quest, false)
		return
	elseif sequence == SEQ_037 and classId == TRIGGER_SEAFLD then
		delegateEvent(player, quest, "processEvent060")
		quest:NewNpcLsMsg(1)
		quest:StartSequence(SEQ_040)
	elseif sequence == SEQ_042 and classId == ECHO_EXIT_TRIGGER then
		delegateEvent(player, quest, "processEvent070")
		quest:StartSequence(SEQ_045)
	elseif (sequence == SEQ_050 or sequence == SEQ_055) and classId == TRIGGER_SEAFLD2 and zoneId == 128 then
		-- At 55 this walks a player who left the echo back in; the step does not move.
		delegateEvent(player, quest, "processEvent080")
		player:EndEvent()
		if sequence == SEQ_050 then
			quest:StartSequence(SEQ_055)
		end
		warpToPoint(player, SHORELINE_ECHO)
		return
	elseif sequence == SEQ_055 and classId == TRIGGER_SEAFLD3 and inPrivateArea(player) then
		delegateEvent(player, quest, "processEvent081")
		player:EndEvent()
		quest:StartSequence(SEQ_070)
		warpToPoint(player, WENCH)
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onNotice(player, quest, target)
	player:EndEvent()
	quest:UpdateENPCs()
end

function onNpcLS(player, quest, from, msgStep)
	readNpcLs(player, quest, NPCLS_FLOW, from, msgStep)
end

-- The duty ask; declineToDeck walks a decliner up out of the hold.
function confirmDeckDuel(player, quest, declineToDeck)
	if delegateEvent(player, quest, "contentsJoinAskInBasaClass") ~= 1 then
		player:EndEvent()
		if declineToDeck then
			warpToPoint(player, DROMOND_STAIRS)
		end
		return
	end
	-- The boarding cutscene plays with the ask still open; a retry at 20 skips the step.
	delegateEvent(player, quest, "processEvent013")
	if quest:GetSequence() ~= SEQ_020 then
		quest:StartSequence(SEQ_020)
	end
	setQuestCounter(quest, CNTR_DUEL_WINNER, 0)
	local a = DUEL_ARRIVAL
	startQuestContent(player, {
		zone = 192, content = "SimpleContentMan2l001", director = "Quest/QuestDirectorMan2l001",
		x = a[1], y = a[2], z = a[3], rot = a[4],
	})
end

-- QuestDirectorMan2l001, one duelist down, with its noticeEvent open: the survivor's scene, then the docks.
function finishDeckDuel(player, quest, fight, area, winner)
	setQuestCounter(quest, CNTR_DUEL_WINNER, winner)
	delegateEvent(player, quest, "processEvent020", winner)
	quest:StartSequence(SEQ_035)
	leaveQuestContent(player, fight, area, {
		zone = LIMSA_DOCKS[1], x = LIMSA_DOCKS[4], y = LIMSA_DOCKS[5], z = LIMSA_DOCKS[6], rot = LIMSA_DOCKS[7],
	})
end

-- A lost duel keeps 20: back on the dromond by the stairs.
function failDeckDuel(player, quest, fight, area)
	player:SetHP(player:GetMaxHP())
	local p = DROMOND_STAIRS
	leaveQuestContent(player, fight, area, {
		zone = p[1], privateAreaName = p[2], privateAreaLevel = p[3], x = p[4], y = p[5], z = p[6], rot = p[7],
	})
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
