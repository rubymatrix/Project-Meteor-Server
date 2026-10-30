require("Global")
require("Quest")
require("QuestFlow")

--[[
Never the Twain Shall Meet (Man2l0, 110004). Prereq: Legends Adrift (Man1l0).
Walkthrough: Data/Docs/Scripts/Quest/Man/Man2l0.md.
--]]

local hobFerry, confirmDeckDuel

local SEQ_000 = 0
local SEQ_010 = 10
local SEQ_015 = 15
SEQ_020 = 20
local SEQ_035 = 35
local SEQ_037 = 37
local SEQ_040 = 40
local SEQ_042 = 42
local SEQ_045 = 45
local SEQ_050 = 50
local SEQ_055 = 55
local SEQ_070 = 70

local BADERON             = 1000137
local YSHTOLA             = 1000001
local HOB                 = 1000151
local ISAUDOREL           = 1000152
local BARRACUDA_KNIGHT1   = 1000183
local BARRACUDA_KNIGHT2   = 1000184
local TRIGGER_DOCKS       = 1090386 -- public 230
local EVENTDOOR_SHIP1     = 1090098 -- PA 192/0 (ObjectEventDoor)
local EVENTDOOR_SHIP2     = 1090099 -- PA 192/1 (ObjectEventDoor)
local TRIGGER_DUTYSTART   = 1090085 -- PA 192/0; the class is also a Coliseum trigger in 209
local ECHO_EXIT_TRIGGER   = 1090003 -- the Marauders' Guild doors (public 230)
local TRIGGER_SEAFLD      = 1090082 -- public 128
local TRIGGER_SEAFLD2     = 1090086 -- public 128; the class is also used in 206
local TRIGGER_SEAFLD3     = 1090087 -- PA 128/3; the class is also a public 128 cave trigger

local MRKR_HOB                = 11000401
local MRKR_HOLD_DOOR          = 11000402
local MRKR_DECK_DOOR          = 11000403
local MRKR_SEAFIELD_OUTCROP   = 11000404
local MRKR_MSK_GUILD          = 11000405
local MRKR_ISAUDOREL          = 11000406
local MRKR_GODS_GRIP          = 11000407
local MRKR_SEA_ECHO           = 11000408
local MRKR_BADERON            = 11000409

local CNTR_DUEL_WINNER = 0 -- 1 Emerick, 2 Merodaulyn: the survivor of the last duel won

local BADERON_DISPLAY_ID = 1000015

local DOCKS_ECHO      = { 230, "PrivateAreaMasterPast", 8, -631.93, 2.0, 391.75, -0.05 }
local DROMOND_ARRIVAL = { 192, "PrivateAreaMasterPast", 0, 1831.541, 16.352, 1834.920, 1.569 }
local DROMOND_DECK    = { 192, "PrivateAreaMasterPast", 0, 1828.785, 11.852, 1829.200, -1.675 }
local DROMOND_STAIRS  = { 192, "PrivateAreaMasterPast", 0, 1821.675, 10.352, 1814.964, 2.288 }
local DROMOND_HOLD    = { 192, "PrivateAreaMasterPast", 1, 1823.579, -61.65, 1816.102, 2.42 }
local LIMSA_DOCKS     = { 230, nil, 0, -639.325, 1.0, 403.967, 1.655 }
local SHORELINE_ECHO  = { 128, "PrivateAreaMasterPast", 3, 198.314, 25.928, 1186.126, 1.6 }
local WENCH           = { 133, nil, 0, -435.501, 40.0, 202.698, -2.152 }
local DUEL_ARRIVAL    = { 1829.296, 16.347, 1825.281, -0.023 }

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

local PHASES = {
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

local CHATTER = {
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
local NPCLS_OUTCROP = { 40, 41 }
local NPCLS_FLOW = {
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

local function chatter(player, quest, npc)
	delegateChatter(player, quest, CHATTER, quest:GetSequence(), npc:GetActorClassId())
end

local function hobBoarding(player, quest, npc)
	if not inPrivateArea(player) then
		chatter(player, quest, npc)
		return
	end
	hobFerry(player, quest, quest:GetSequence())
	return true
end

local talk = {
	[SEQ_ACCEPT] = {
		[BADERON] = function(player, quest)
			delegateEvent(player, quest, "processEvent000")
			player:EndEvent()
			player:AcceptQuest(quest, true)
			return true
		end,
		other = function() end,
	},
	[SEQ_000] = {
		[HOB] = function(player, quest, npc)
			if currentZoneId(player) ~= 230 or not inPrivateArea(player) then
				chatter(player, quest, npc)
				return
			end
			delegateEvent(player, quest, "processEvent010")
			player:EndEvent()
			quest:StartSequence(SEQ_010)
			warpToPoint(player, DROMOND_ARRIVAL)
			return true
		end,
	},
	[SEQ_010] = { [HOB] = hobBoarding },
	[SEQ_015] = { [HOB] = hobBoarding },
	[SEQ_020] = { [HOB] = hobBoarding },
	[SEQ_035] = {
		[BADERON] = function(player, quest)
			delegateEvent(player, quest, "processEvent050")
			quest:StartSequence(SEQ_037)
		end,
	},
	[SEQ_045] = {
		[ISAUDOREL] = function(player, quest)
			delegateEvent(player, quest, "processEvent075")
			delegateEvent(player, quest, "processEvent075_2")
			quest:StartSequence(SEQ_050)
		end,
	},
	[SEQ_070] = {
		[BADERON] = function(player, quest)
			turnInQuest(player, quest, "processEvent081_2", player:GetHighestLevel())
			return true
		end,
	},
	other = chatter,
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
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

-- Every step up to the duel keeps the docks push open.
local function enterDocksEcho(player, quest)
	if quest:GetSequence() > SEQ_020 then return end
	player:EndEvent()
	warpToPoint(player, DOCKS_ECHO)
	return true
end

-- The hold's stairs ask for the duel; a decline still walks the player up to the deck.
local function holdStairs(player, quest)
	confirmDeckDuel(player, quest, true)
	return true
end

local function deckTrigger(player, quest)
	if currentZoneId(player) == 192 then
		confirmDeckDuel(player, quest, false)
		return true
	end
end

-- At 55 this walks a player who left the echo back in; the step does not move.
local function enterShorelineEcho(player, quest)
	if currentZoneId(player) ~= 128 then return end
	delegateEvent(player, quest, "processEvent080")
	player:EndEvent()
	if quest:GetSequence() == SEQ_050 then
		quest:StartSequence(SEQ_055)
	end
	warpToPoint(player, SHORELINE_ECHO)
	return true
end

-- Door classes (ObjectEventDoor) have already asked the move question in their own script.
local pushes = {
	[SEQ_010] = {
		[EVENTDOOR_SHIP1] = function(player, quest)
			delegateEvent(player, quest, "processEvent012")
			player:EndEvent()
			quest:StartSequence(SEQ_015)
			warpToPoint(player, DROMOND_HOLD)
			return true
		end,
	},
	[SEQ_015] = {
		[EVENTDOOR_SHIP2] = holdStairs,
		[TRIGGER_DUTYSTART] = deckTrigger,
	},
	[SEQ_020] = {
		[EVENTDOOR_SHIP2] = holdStairs,
		[TRIGGER_DUTYSTART] = deckTrigger,
	},
	[SEQ_037] = {
		[TRIGGER_SEAFLD] = function(player, quest)
			delegateEvent(player, quest, "processEvent060")
			quest:NewNpcLsMsg(1)
			quest:StartSequence(SEQ_040)
		end,
	},
	[SEQ_042] = {
		[ECHO_EXIT_TRIGGER] = function(player, quest)
			delegateEvent(player, quest, "processEvent070")
			quest:StartSequence(SEQ_045)
		end,
	},
	[SEQ_050] = { [TRIGGER_SEAFLD2] = enterShorelineEcho },
	[SEQ_055] = {
		[TRIGGER_SEAFLD2] = enterShorelineEcho,
		[TRIGGER_SEAFLD3] = function(player, quest)
			if not inPrivateArea(player) then return end
			delegateEvent(player, quest, "processEvent081")
			player:EndEvent()
			quest:StartSequence(SEQ_070)
			warpToPoint(player, WENCH)
			return true
		end,
	},
	always = {
		[TRIGGER_DOCKS] = enterDocksEcho,
	},
}

function onPush(player, quest, npc)
	if runQuestHandler(pushes, player, quest, npc) then return end
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
