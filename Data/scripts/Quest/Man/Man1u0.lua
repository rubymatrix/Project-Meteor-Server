require("Global")
require("Quest")
require("QuestFlow")

local enterFuneralHall

--[[
Golden Sacrifices (Man1u0, quest 110011). Follows Court in the Sands (Man0u1); offered by Momodi.

Seq 0:  Momodi's errand in the Quicksand echo (PA 175/0).
Seq 5:  Gagaruna's briefing outside the Platinum Mirage.
Seq 10: The Mirage lobby (PA 181/6) and the gambling-room door.
Seq 15: Thancred's accusation in the gambling room (PA 181/7).
Seq 20: Momodi's linkpearl about the accusation; the read moves to 25.
Seq 25: Deaustie's lead at Sunsilk Tapestries.
Seq 28: F'lhaminn's rehearsal at the natural bridge (Central Thanalan push).
Seq 30: The natural-bridge crossing into the Thanalan echo (PA 170/0).
Seq 35: Ascilia's roadside meeting in the echo.
Seq 40: Momodi's linkpearl about the thaumaturges; the read moves to 45.
Seq 45: Yayake's hand-off at the Thaumaturges' Guild.
Seq 50: The funeral hall (PA 209/4) and the thaumaturges' commune.
Seq 55: Niellefresne's testimony.
Seq 60: The funeral-hall farewell lights Momodi's linkpearl.
Seq 65: Momodi's closing linkpearl; the read moves to 70.
Seq 70: Momodi's reward at the Quicksand.

No duty and no director. Every echo can be walked out of: Momodi (Seq 0), the bridge triggers
(Seq 35) and Yayake (Seq 50-60) replay the scene that leads back in. Spawns, private areas and class
fills: Data/sql/seed/seed_msq_uldah_01_npcs.sql.
--]]

local SEQ_000 = 0
local SEQ_005 = 5
local SEQ_010 = 10
local SEQ_015 = 15
local SEQ_020 = 20
local SEQ_025 = 25
local SEQ_028 = 28
local SEQ_030 = 30
local SEQ_035 = 35
local SEQ_040 = 40
local SEQ_045 = 45
local SEQ_050 = 50
local SEQ_055 = 55
local SEQ_060 = 60
local SEQ_065 = 65
local SEQ_070 = 70

local MOMODI                       = 1000841
local RUMINATING_ELEZEN            = 1000942
local WELL_DRESSED_MIDLANDER       = 1000943
local QUEERLY_COORDINATED_LALAFELL = 1000944
local SILVER_HAIRED_SEDUCTRESS     = 1000945
local WAXEN_FACED_WIDOWER          = 1000946
local LUMBERING_LALAFELL           = 1000947
local GAGARUNA                     = 1000862
local QATA_NELHAH                  = 1001462
local MAMMET                       = 1001455
local GAMBLING_HALL_TRIGGER        = 1090114
local GAMBLING_ROOM_TRIGGER        = 1090283
local KOCHACHA                     = 1001504
local PATIENT_CROW                 = 1001505
local GWENOLIE                     = 1001506
local RAGINHART                    = 1001507
local THANCRED                     = 1000948
local GREINFARR                    = 1000039
local FLHAMINN                     = 1000038
local QOQOBA                       = 1000855
local CORGUEVAIS_SCENE             = 1001054
local POPOKKULI_MIRAGE             = 1000040
local SESERUKKA_MIRAGE             = 1000041
local NIELLEFRESNE                 = 1001867
local DEAUSTIE                     = 1000293
local FLHAMINN_TRIGGER             = 1090075
local NATURAL_BRIDGE_TRIGGER       = 1090077
local ASCILIA                      = 1000042
local GEGEISSA                     = 1001424
local YAYAKE                       = 1000846
local THAUMATURGE_TRIGGER          = 1090045
local THAUMATURGE_HALL_TRIGGER     = 1090047
local SWOLLEN_EYED_STRUMPET        = 1001215
local SINETTE                      = 1001145
local ZSSAPA                       = 1000887
local DOWNCAST_DERELICT            = 1001214
local AILING_ROEGADYN              = 1001216
local GOGOFU                       = 1000046

local MRKR_MOMODI         = 11001101
local MRKR_GAGARUNA       = 11001102
local MRKR_GAMBLING_HALL  = 11001103
local MRKR_THANCRED       = 11001104
local MRKR_DEAUSTIE       = 11001105
local MRKR_NATURAL_BRIDGE = 11001106
local MRKR_ASCILIA        = 11001108
local MRKR_YAYAKE         = 11001109
local MRKR_FUNERAL_HALL   = 11001110
local MRKR_NIELLEFRESNE   = 11001111

local MOMODI_DISPLAY_ID = 1500014

local QUICKSAND_ECHO   = { 0, -73.811, 195, 78.759, -0.448 }
local MIRAGE_LOBBY     = { 181, 6, -204.944, 0, -159.944, 1.591 }
local MIRAGE_ROOM      = { 181, 7, -134.301, 1, -159.996, 1.581 }
local MIRAGE_EXIT      = { 175, -149.812, 185.454, 123.459, 2.411 }
local THANALAN_ECHO    = { 0, 290.64, 245.201, -875.147, 2.315 }
local ROADSIDE         = { 314.75, 247.899, -894, 2.363 }
local FUNERAL_HALL     = { 4, -344.473, 206, 243.186, 1.704 }
local COMMUNE_SPOT     = { -294.941, 206, 231.882, -1.567 }

local function isInEcho(player)
	return inPrivateArea(player)
end

local function isOutOfEcho(player)
	return not inPrivateArea(player)
end

-- The bridge triggers stay armed through the echo so a player who walks out can replay the way back in.
local BRIDGE_TRIGGERS = {
	{ FLHAMINN_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true },
	{ NATURAL_BRIDGE_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true },
}

-- The circles stay armed across the testimony so the farewell push fires without a disable and
-- re-enable on the same actor.
local HALL_TRIGGERS = {
	{ THAUMATURGE_TRIGGER, QFLAG_PUSH, talk = false, push = true },
	{ THAUMATURGE_HALL_TRIGGER, QFLAG_PUSH, talk = false, push = true },
}

local FUNERAL_CROWD = { THANCRED, SWOLLEN_EYED_STRUMPET, SINETTE, ZSSAPA, DOWNCAST_DERELICT, AILING_ROEGADYN }

local PHASES = {
	[SEQ_000] = {
		enpcs = {
			{ MOMODI, QFLAG_TALK },
			RUMINATING_ELEZEN, WELL_DRESSED_MIDLANDER, QUEERLY_COORDINATED_LALAFELL,
			SILVER_HAIRED_SEDUCTRESS, WAXEN_FACED_WIDOWER, LUMBERING_LALAFELL,
		},
		markers = { MRKR_MOMODI },
	},
	[SEQ_005] = {
		enpcs = { { GAGARUNA, QFLAG_TALK }, MOMODI, QATA_NELHAH, MAMMET },
		markers = { MRKR_GAGARUNA },
	},
	[SEQ_010] = {
		enpcs = {
			{ GAMBLING_HALL_TRIGGER, QFLAG_PUSH, talk = false, push = true },
			{ GAMBLING_ROOM_TRIGGER, QFLAG_PUSH, talk = false, push = true },
			MOMODI, GAGARUNA, QATA_NELHAH, MAMMET, KOCHACHA, PATIENT_CROW, GWENOLIE, RAGINHART,
		},
		markers = { MRKR_GAMBLING_HALL },
	},
	[SEQ_015] = {
		enpcs = {
			{ THANCRED, QFLAG_TALK },
			{ GAMBLING_HALL_TRIGGER, QFLAG_PUSH, talk = false, push = true },
			GREINFARR, FLHAMINN, QOQOBA, CORGUEVAIS_SCENE, POPOKKULI_MIRAGE, SESERUKKA_MIRAGE, NIELLEFRESNE,
		},
		-- Outside the echo the journal points back at the gambling-hall doors.
		markers = { { MRKR_THANCRED, when = isInEcho }, { MRKR_GAMBLING_HALL, when = isOutOfEcho } },
	},
	-- The pearl carries this step: only its spoken twins answer.
	[SEQ_020] = { enpcs = { MOMODI, GAGARUNA } },
	[SEQ_025] = {
		enpcs = { { DEAUSTIE, QFLAG_TALK }, MOMODI, GAGARUNA },
		markers = { MRKR_DEAUSTIE },
	},
	[SEQ_028] = {
		enpcs = { { FLHAMINN_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true }, DEAUSTIE, MOMODI },
		markers = { MRKR_NATURAL_BRIDGE },
	},
	[SEQ_030] = {
		enpcs = { { NATURAL_BRIDGE_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true }, DEAUSTIE, MOMODI },
		markers = { MRKR_NATURAL_BRIDGE },
	},
	[SEQ_035] = {
		enpcs = {
			{ ASCILIA, QFLAG_TALK }, BRIDGE_TRIGGERS[1], BRIDGE_TRIGGERS[2], FLHAMINN, DEAUSTIE, MOMODI,
		},
		markers = { { MRKR_ASCILIA, when = isInEcho }, { MRKR_NATURAL_BRIDGE, when = isOutOfEcho } },
	},
	[SEQ_040] = { enpcs = { GEGEISSA } },
	[SEQ_045] = {
		enpcs = { { YAYAKE, QFLAG_TALK }, GEGEISSA },
		markers = { MRKR_YAYAKE },
	},
	[SEQ_050] = {
		-- Yayake stands only in the public zone: her row is the escaped player's way back in.
		enpcs = { HALL_TRIGGERS[1], HALL_TRIGGERS[2], { YAYAKE, QFLAG_TALK } },
		markers = { { MRKR_FUNERAL_HALL, when = isInEcho }, { MRKR_YAYAKE, when = isOutOfEcho } },
	},
	[SEQ_055] = {
		enpcs = {
			HALL_TRIGGERS[1], HALL_TRIGGERS[2], { NIELLEFRESNE, QFLAG_TALK }, { YAYAKE, QFLAG_TALK },
			{ crowd = FUNERAL_CROWD },
		},
		markers = { { MRKR_NIELLEFRESNE, when = isInEcho }, { MRKR_YAYAKE, when = isOutOfEcho } },
	},
	[SEQ_060] = {
		enpcs = {
			HALL_TRIGGERS[1], HALL_TRIGGERS[2], { YAYAKE, QFLAG_TALK }, NIELLEFRESNE,
			{ crowd = FUNERAL_CROWD },
		},
		markers = { { MRKR_FUNERAL_HALL, when = isInEcho }, { MRKR_YAYAKE, when = isOutOfEcho } },
	},
	[SEQ_065] = { enpcs = { YAYAKE, GOGOFU } },
	[SEQ_070] = {
		enpcs = { { MOMODI, QFLAG_REWARD }, YAYAKE, GOGOFU },
		markers = { MRKR_MOMODI },
	},
}

-- Lines that answer in place (the reminder owners follow the client's man1u0 text sheet).
local CHATTER = {
	[SEQ_000] = {
		[RUMINATING_ELEZEN] = "processEvent000_2", [WELL_DRESSED_MIDLANDER] = "processEvent000_3",
		[QUEERLY_COORDINATED_LALAFELL] = "processEvent000_4", [SILVER_HAIRED_SEDUCTRESS] = "processEvent000_5",
		[WAXEN_FACED_WIDOWER] = "processEvent000_6", [LUMBERING_LALAFELL] = "processEvent000_7",
	},
	[SEQ_005] = { [MOMODI] = "processEvent010_2", [QATA_NELHAH] = "processEvent010_3", [MAMMET] = "processEvent010_4" },
	[SEQ_010] = {
		[MOMODI] = "processEvent010_2", [GAGARUNA] = "processEvent015_2", [QATA_NELHAH] = "processEvent015_3",
		[MAMMET] = "processEvent015_4", [KOCHACHA] = "processEvent015_5", [PATIENT_CROW] = "processEvent015_6",
		[GWENOLIE] = "processEvent015_7", [RAGINHART] = "processEvent015_8",
	},
	[SEQ_015] = {
		[GREINFARR] = "processEvent020_2", [FLHAMINN] = "processEvent020_3", [QOQOBA] = "processEvent020_4",
		[CORGUEVAIS_SCENE] = "processEvent020_5", [POPOKKULI_MIRAGE] = "processEvent020_6",
		[SESERUKKA_MIRAGE] = "processEvent020_7", [NIELLEFRESNE] = "processEvent020_8",
	},
	[SEQ_020] = { [GAGARUNA] = "processEvent021_2", [MOMODI] = "processEvent025_2" },
	[SEQ_025] = { [GAGARUNA] = "processEvent021_2", [MOMODI] = "processEvent025_2" },
	-- Momodi's 1000_2 names the flower the player sold: it covers Deaustie's lead to the roadside.
	[SEQ_028] = { [DEAUSTIE] = "processEvent028_2", [MOMODI] = "processEvent1000_2" },
	[SEQ_030] = { [DEAUSTIE] = "processEvent028_2", [MOMODI] = "processEvent1000_2" },
	[SEQ_035] = { [DEAUSTIE] = "processEvent028_2", [FLHAMINN] = "processEvent040_2", [MOMODI] = "processEvent1000_2" },
	[SEQ_040] = { [GEGEISSA] = "processEvent055_2" },
	[SEQ_045] = { [GEGEISSA] = "processEvent055_2" },
	[SEQ_055] = {
		[THANCRED] = "processEvent070_2", [SWOLLEN_EYED_STRUMPET] = "processEvent070_3", [SINETTE] = "processEvent070_4",
		[ZSSAPA] = "processEvent070_5", [DOWNCAST_DERELICT] = "processEvent070_6", [AILING_ROEGADYN] = "processEvent070_7",
	},
	[SEQ_060] = {
		[THANCRED] = "processEvent070_2", [SWOLLEN_EYED_STRUMPET] = "processEvent070_3", [SINETTE] = "processEvent070_4",
		[ZSSAPA] = "processEvent070_5", [DOWNCAST_DERELICT] = "processEvent070_6", [AILING_ROEGADYN] = "processEvent070_7",
		[NIELLEFRESNE] = "processEvent080_2",
	},
	[SEQ_065] = { [YAYAKE] = "processEvent090_2", [GOGOFU] = "processEvent1000_4" },
	[SEQ_070] = { [YAYAKE] = "processEvent090_2", [GOGOFU] = "processEvent1000_4" },
}

-- A call is readable at the step that lit it and at the step its read moves to.
local NPCLS_MIRAGE    = { 73, 74, 200 }
local NPCLS_OSSUARY   = { 114, 115, 116, 117 }
local NPCLS_QUICKSAND = { 160 }

local NPCLS_FLOW = {
	from = 1,
	sender = MOMODI_DISPLAY_ID,
	packs = {
		[SEQ_020] = NPCLS_MIRAGE, [SEQ_025] = NPCLS_MIRAGE,
		[SEQ_040] = NPCLS_OSSUARY, [SEQ_045] = NPCLS_OSSUARY,
		[SEQ_065] = NPCLS_QUICKSAND, [SEQ_070] = NPCLS_QUICKSAND,
	},
	advances = { [SEQ_020] = SEQ_025, [SEQ_040] = SEQ_045, [SEQ_065] = SEQ_070 },
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
	local p = QUICKSAND_ECHO
	warpToPrivateArea(player, p[1], p[2], p[3], p[4], p[5])
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		if player:IsQuestCompleted(110010) then
			quest:SetENpc(MOMODI, QFLAG_TALK)
		end
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if sequence == SEQ_ACCEPT then
		if classId == MOMODI then
			delegateEvent(player, quest, "processEventMomodiStart")
			player:EndEvent()
			player:AcceptQuest(quest)
			return
		end
	elseif sequence == SEQ_000 and classId == MOMODI then
		-- The echo replays from its opening scene: a player who walked out re-enters through Momodi.
		if isOutOfEcho(player) then
			delegateEvent(player, quest, "processEventMomodiStart")
			player:EndEvent()
			local p = QUICKSAND_ECHO
			warpToPrivateArea(player, p[1], p[2], p[3], p[4], p[5])
			return
		end
		delegateEvent(player, quest, "processEvent010")
		player:EndEvent()
		quest:StartSequence(SEQ_005)
		warpToPublic(player)
		return
	elseif sequence == SEQ_005 and classId == GAGARUNA then
		delegateEvent(player, quest, "processEvent015")
		quest:StartSequence(SEQ_010)
	elseif sequence == SEQ_015 and classId == THANCRED then
		delegateEvent(player, quest, "processEvent021")
		quest:NewNpcLsMsg(1)
		player:EndEvent()
		quest:StartSequence(SEQ_020)
		local p = MIRAGE_EXIT
		warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
		return
	elseif sequence == SEQ_025 and classId == DEAUSTIE then
		delegateEvent(player, quest, "processEvent028")
		quest:StartSequence(SEQ_028)
	elseif sequence == SEQ_035 and classId == ASCILIA then
		delegateEvent(player, quest, "processEvent050")
		quest:NewNpcLsMsg(1)
		player:EndEvent()
		quest:StartSequence(SEQ_040)
		local p = ROADSIDE
		warpToPublic(player, p[1], p[2], p[3], p[4])
		return
	elseif sequence == SEQ_045 and classId == YAYAKE then
		delegateEvent(player, quest, "processEvent060")
		player:EndEvent()
		quest:StartSequence(SEQ_050)
		enterFuneralHall(player)
		return
	elseif (sequence == SEQ_050 or sequence == SEQ_055 or sequence == SEQ_060) and classId == YAYAKE then
		-- She keeps her post outside: the hand-off scene again, and back into the hall.
		delegateEvent(player, quest, "processEvent060")
		player:EndEvent()
		enterFuneralHall(player)
		return
	elseif sequence == SEQ_055 and classId == NIELLEFRESNE then
		delegateEvent(player, quest, "processEvent080")
		quest:StartSequence(SEQ_060)
	elseif sequence == SEQ_070 and classId == MOMODI then
		turnInQuest(player, quest, "processEvent100")
		return
	else
		delegateChatter(player, quest, CHATTER, sequence, classId)
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	-- The Mirage doors are an ObjectEventDoor: its script has already asked the move question.
	if classId == GAMBLING_HALL_TRIGGER and (sequence == SEQ_010 or sequence == SEQ_015) then
		local p = (sequence == SEQ_010) and MIRAGE_LOBBY or MIRAGE_ROOM
		player:EndEvent()
		warpTo(player, p[1], "PrivateAreaMasterPast", p[2], p[3], p[4], p[5], p[6])
		return
	elseif sequence == SEQ_010 and classId == GAMBLING_ROOM_TRIGGER and inPrivateAreaOf(player, 181, "PrivateAreaMasterPast", 6) then
		delegateEvent(player, quest, "processEvent020")
		player:EndEvent()
		quest:StartSequence(SEQ_015)
		local p = MIRAGE_ROOM
		warpTo(player, p[1], "PrivateAreaMasterPast", p[2], p[3], p[4], p[5], p[6])
		return
	elseif sequence == SEQ_028 and classId == FLHAMINN_TRIGGER then
		delegateEvent(player, quest, "processEvent030")
		quest:StartSequence(SEQ_030)
	elseif (sequence == SEQ_030 or sequence == SEQ_035) and classId == NATURAL_BRIDGE_TRIGGER and currentZoneId(player) == 170 then
		-- At 35 this replays the crossing for a player who left the echo; the step does not move.
		delegateEvent(player, quest, "processEvent040")
		player:EndEvent()
		if sequence == SEQ_030 then
			quest:StartSequence(SEQ_035)
		end
		local p = THANALAN_ECHO
		warpToPrivateArea(player, p[1], p[2], p[3], p[4], p[5])
		return
	elseif sequence == SEQ_035 and classId == FLHAMINN_TRIGGER then
		delegateEvent(player, quest, "processEvent030")
	elseif (classId == THAUMATURGE_TRIGGER or classId == THAUMATURGE_HALL_TRIGGER) and sequence == SEQ_050 then
		delegateEvent(player, quest, "processEvent070")
		player:EndEvent()
		quest:StartSequence(SEQ_055)
		local p = COMMUNE_SPOT
		bouncePlayer(player, p[1], p[2], p[3], p[4])
		return
	elseif (classId == THAUMATURGE_TRIGGER or classId == THAUMATURGE_HALL_TRIGGER) and sequence == SEQ_060 then
		delegateEvent(player, quest, "processEvent090")
		quest:NewNpcLsMsg(1)
		player:EndEvent()
		quest:StartSequence(SEQ_065)
		local p = COMMUNE_SPOT
		warpToPublic(player, p[1], p[2], p[3], p[4])
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function enterFuneralHall(player)
	local p = FUNERAL_HALL
	warpTo(player, 209, "PrivateAreaMasterPast", p[1], p[2], p[3], p[4], p[5])
end

function onNotice(player, quest, target)
	player:EndEvent()
	quest:UpdateENPCs()
end

function onNpcLS(player, quest, from, msgStep)
	readNpcLs(player, quest, NPCLS_FLOW, from, msgStep)
end

function getJournalInformation(player, quest)
	return
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
