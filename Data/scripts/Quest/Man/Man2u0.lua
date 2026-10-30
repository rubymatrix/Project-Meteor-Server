require("Global")
require("Quest")
require("QuestFlow")

--[[
Calamity Cometh (Man2u0, quest 110012). Follows Golden Sacrifices (Man1u0); offered by Momodi.

Seq 0:  Rururaji at the chocobo stables: the coach ride (processEvent005) straight into the fight.
Seq 5:  Set on boarding; a logout mid-scene lands here, so the stables route stays armed.
Seq 10: The minemite fight (content SimpleContentMan2u001, QuestDirectorMan2u001); a lost fight keeps 10
        and Rururaji takes the player back (processEvent005_2).
Seq 15: Nogeloix at the Phrontistery; the ward door leads into the Phrontistery (PA 181/8).
Seq 20: The sickroom antechamber: the sickroom door (PA 181/9).
Seq 25: F'lhaminn's sickroom; the corridor (PA 181/10) and the collapse.
Seq 30: Momodi's linkpearl; the read moves to 35.
Seq 35: The Camp Black Brush sighting.
Seq 40: The Arrzaneth Ossuary approach into the crypt echo (PA 209/7).
Seq 45: The crypt: the closing chain plays and lands at the Quicksand.
Seq 50: Stepped through on the way to 55.
Seq 55: Momodi pays out the tale.

Completion: processEventSystemMessage (a3 = level: "travel to Ul'dah" at 18+), then the reward window
(500 EXP, 30000 gil, Parley from the client reward sheet). Spawns, private areas and class fills:
Data/sql/seed/seed_msq_uldah_01_npcs.sql.
--]]

local warpToEcho, warpToFloor, startMinemiteFight

local SEQ_000 = 0
local SEQ_005 = 5
SEQ_010 = 10
local SEQ_015 = 15
local SEQ_020 = 20
local SEQ_025 = 25
local SEQ_030 = 30
local SEQ_035 = 35
local SEQ_040 = 40
local SEQ_045 = 45
local SEQ_050 = 50
local SEQ_055 = 55

local MOMODI                      = 1000841
local RURURAJI                    = 1000840
local NOGELOIX                    = 1000597
local WARD_DOOR                   = 1090119
local SICKROOM_TRIGGER            = 1090118
local PHRONTISTERY_RETURN_TRIGGER = 1090144
local SICKROOM_EXIT_TRIGGER       = 1090141
local PHRONTISTERY_EXIT_TRIGGER   = 1090168
local FLHAMINN                    = 1000038
local WORRISOME_ASSISTANT         = 1001207
local WELL_WASHED_LEECH           = 1001210
local CHAPEAUED_CHAP              = 1001277
local BLACKBRUSH_TRIGGER          = 1090169
local ARRZANETH_TRIGGER           = 1090253
local CRYPT_TRIGGER               = 1090131
local ASCILIA                     = 1000042

local MRKR_RURURAJI      = 11001201
local MRKR_PHRONTISTERY  = 11001202
local MRKR_SICKROOM_DOOR = 11001203
local MRKR_SICKROOM      = 11001204
local MRKR_BLACKBRUSH    = 11001205
local MRKR_ARRZANETH     = 11001206
local MRKR_CRYPT         = 11001207

local ITEM_NIELLEFRESNES_GOLD_DUST = 11000081
local MOMODI_DISPLAY_ID = 1500014

local FIGHT_ARRIVAL       = { -117.242, 215.653, -769.757, 1.442 }
local PHRONTISTERY_LOBBY  = { 181, 8, -193.517, 0, -160.175, 1.591 }
local SICKROOM            = { 181, 9, -160.687, 0, -131.861, -0.578 }
local CORRIDOR            = { 181, 10, -148.108, 2, -178.924, -1.62 }
local PHRONTISTERY_FLOOR  = { 209, -215.248, 229.5, 297.833, 2.895 }
local CRYPT_ECHO          = { 7, -250.265, 202, 209.839, -0.181 }
local QUICKSAND_AWAKENING = { 175, -63.546, 195, 76.404, -2.847 }

local function isInEcho(player)
	return inPrivateArea(player)
end

local function isOutOfEcho(player)
	return not inPrivateArea(player)
end

local WARD_CROWD = { WORRISOME_ASSISTANT, WELL_WASHED_LEECH, CHAPEAUED_CHAP }

local function push(classId, icon)
	return { classId, icon or QFLAG_PUSH, talk = false, push = true }
end

local PHASES = {
	[SEQ_000] = { enpcs = { { RURURAJI, QFLAG_TALK }, MOMODI }, markers = { MRKR_RURURAJI } },
	[SEQ_005] = { enpcs = { { RURURAJI, QFLAG_TALK }, MOMODI }, markers = { MRKR_RURURAJI } },
	-- The fight keeps 10 across a loss and its retry, so the stables stay armed.
	[SEQ_010] = {
		-- F'lhaminn and Ascilia lie wounded in the fight's area: a talk gets nothing said.
		enpcs = { { RURURAJI, QFLAG_TALK }, MOMODI, FLHAMINN, ASCILIA },
		markers = { { MRKR_RURURAJI, when = isOutOfEcho } },
	},
	[SEQ_015] = { enpcs = { push(WARD_DOOR), NOGELOIX }, markers = { MRKR_PHRONTISTERY } },
	[SEQ_020] = {
		-- A push that only moves the player shows no icon; one that moves the story keeps the trigger's.
		enpcs = {
			push(SICKROOM_TRIGGER), push(PHRONTISTERY_RETURN_TRIGGER, QFLAG_OFF), push(WARD_DOOR),
			NOGELOIX, { crowd = WARD_CROWD },
		},
		markers = { { MRKR_SICKROOM_DOOR, when = isInEcho }, { MRKR_PHRONTISTERY, when = isOutOfEcho } },
	},
	[SEQ_025] = {
		enpcs = {
			push(SICKROOM_EXIT_TRIGGER, QFLAG_OFF), push(PHRONTISTERY_EXIT_TRIGGER), push(WARD_DOOR),
			NOGELOIX, FLHAMINN, { crowd = WARD_CROWD },
		},
		markers = { { MRKR_SICKROOM, when = isInEcho }, { MRKR_PHRONTISTERY, when = isOutOfEcho } },
	},
	-- The pearl carries this step: only the corridor's way out is armed.
	[SEQ_030] = { enpcs = { push(PHRONTISTERY_RETURN_TRIGGER, QFLAG_OFF), { crowd = WARD_CROWD } } },
	[SEQ_035] = {
		enpcs = {
			{ BLACKBRUSH_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true },
			push(PHRONTISTERY_RETURN_TRIGGER, QFLAG_OFF), MOMODI, { crowd = WARD_CROWD },
		},
		markers = { MRKR_BLACKBRUSH },
	},
	[SEQ_040] = { enpcs = { push(ARRZANETH_TRIGGER), MOMODI }, markers = { MRKR_ARRZANETH } },
	[SEQ_045] = {
		enpcs = { push(CRYPT_TRIGGER), push(ARRZANETH_TRIGGER), MOMODI },
		markers = { { MRKR_CRYPT, when = isInEcho }, { MRKR_ARRZANETH, when = isOutOfEcho } },
	},
	[SEQ_050] = { enpcs = { MOMODI } },
	[SEQ_055] = { enpcs = { { MOMODI, QFLAG_REWARD } } },
}

-- Lines that answer in place (the reminder owners follow the client's man2u0 text sheet).
local WARD_LINES = {
	[WORRISOME_ASSISTANT] = "processEvent040_2", [WELL_WASHED_LEECH] = "processEvent040_4",
	[CHAPEAUED_CHAP] = "processEvent040_5",
}

local CHATTER = {
	[SEQ_000] = { [MOMODI] = "processEvent000_2" },
	[SEQ_005] = { [MOMODI] = "processEvent000_2" },
	[SEQ_010] = { [MOMODI] = "processEvent000_2" },
	[SEQ_015] = { [NOGELOIX] = "processEvent030_2" },
	[SEQ_020] = { [NOGELOIX] = "processEvent030_2", [WORRISOME_ASSISTANT] = "processEvent040_2",
		[WELL_WASHED_LEECH] = "processEvent040_4", [CHAPEAUED_CHAP] = "processEvent040_5" },
	[SEQ_025] = { [NOGELOIX] = "processEvent030_2", [FLHAMINN] = "processEvent050_2",
		[WORRISOME_ASSISTANT] = "processEvent040_2", [WELL_WASHED_LEECH] = "processEvent040_4",
		[CHAPEAUED_CHAP] = "processEvent040_5" },
	[SEQ_030] = WARD_LINES,
	[SEQ_035] = { [MOMODI] = "processEvent065_2", [WORRISOME_ASSISTANT] = "processEvent040_2",
		[WELL_WASHED_LEECH] = "processEvent040_4", [CHAPEAUED_CHAP] = "processEvent040_5" },
	[SEQ_040] = { [MOMODI] = "processEvent070_2" },
	[SEQ_045] = { [MOMODI] = "processEvent070_2" },
	[SEQ_050] = { [MOMODI] = "processEvent070_2" },
}

local NPCLS_BLACKBRUSH = { 72, 73, 154 }
local NPCLS_FLOW = {
	from = 1,
	sender = MOMODI_DISPLAY_ID,
	packs = { [SEQ_030] = NPCLS_BLACKBRUSH, [SEQ_035] = NPCLS_BLACKBRUSH },
	advances = { [SEQ_030] = SEQ_035 },
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		if player:IsQuestCompleted(110011) then
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
	elseif classId == RURURAJI and (sequence == SEQ_000 or sequence == SEQ_005 or sequence == SEQ_010) then
		-- The coach ride: the scenes on the way out, or the coachman's line on a retry.
		delegateEvent(player, quest, (sequence == SEQ_010) and "processEvent005_2" or "processEvent005")
		startMinemiteFight(player, quest)
		return
	elseif sequence == SEQ_055 and classId == MOMODI then
		if turnInQuest(player, quest, "processEventSystemMessage", player:GetHighestLevel()) then
			takeKeyItem(player, ITEM_NIELLEFRESNES_GOLD_DUST)
		end
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

	-- Door classes (ObjectEventDoor) have already asked the move question in their own script.
	if sequence == SEQ_015 and classId == WARD_DOOR then
		delegateEvent(player, quest, "processEvent040")
		player:EndEvent()
		quest:StartSequence(SEQ_020)
		warpToEcho(player, PHRONTISTERY_LOBBY)
		return
	elseif sequence == SEQ_020 then
		if classId == SICKROOM_TRIGGER then
			delegateEvent(player, quest, "processEvent050")
			player:EndEvent()
			quest:StartSequence(SEQ_025)
			warpToEcho(player, SICKROOM)
			return
		elseif classId == PHRONTISTERY_RETURN_TRIGGER then
			player:EndEvent()
			warpToFloor(player)
			return
		elseif classId == WARD_DOOR then
			-- The Damielliot scene played on the first entry; later entries only walk back in.
			player:EndEvent()
			warpToEcho(player, PHRONTISTERY_LOBBY)
			return
		end
	elseif sequence == SEQ_025 then
		if classId == SICKROOM_EXIT_TRIGGER then
			player:EndEvent()
			warpToEcho(player, CORRIDOR)
			return
		elseif classId == PHRONTISTERY_EXIT_TRIGGER then
			-- The collapse plays where the player stands and lights the pearl.
			delegateEvent(player, quest, "processEvent060")
			quest:NewNpcLsMsg(1)
			quest:StartSequence(SEQ_030)
		elseif classId == WARD_DOOR then
			player:EndEvent()
			warpToEcho(player, SICKROOM)
			return
		end
	elseif (sequence == SEQ_030 or sequence == SEQ_035) and classId == PHRONTISTERY_RETURN_TRIGGER then
		-- The corridor has no other way out once the collapse scene has closed.
		player:EndEvent()
		warpToFloor(player)
		return
	elseif sequence == SEQ_035 and classId == BLACKBRUSH_TRIGGER then
		delegateEvent(player, quest, "processEvent070")
		quest:StartSequence(SEQ_040)
	elseif (sequence == SEQ_040 or sequence == SEQ_045) and classId == ARRZANETH_TRIGGER then
		-- At 45 this replays the approach for a player who left the echo; the step does not move.
		delegateEvent(player, quest, "processEvent080")
		player:EndEvent()
		if sequence == SEQ_040 then
			quest:StartSequence(SEQ_045)
		end
		local p = CRYPT_ECHO
		warpTo(player, 209, "PrivateAreaMasterPast", p[1], p[2], p[3], p[4], p[5])
		return
	elseif sequence == SEQ_045 and classId == CRYPT_TRIGGER then
		-- The closing chain walks the player from the crypt echo to the Quicksand awakening.
		delegateEvent(player, quest, "processEvent085")
		player:EndEvent()
		quest:StartSequence(SEQ_050)
		quest:StartSequence(SEQ_055)
		local p = QUICKSAND_AWAKENING
		warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function warpToEcho(player, p)
	warpTo(player, p[1], "PrivateAreaMasterPast", p[2], p[3], p[4], p[5], p[6])
end

function warpToFloor(player)
	local p = PHRONTISTERY_FLOOR
	warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
end

function onNotice(player, quest, target)
	player:EndEvent()
	quest:UpdateENPCs()
end

function onNpcLS(player, quest, from, msgStep)
	readNpcLs(player, quest, NPCLS_FLOW, from, msgStep)
end

-- Boarding at 0 records the coach ride (5) and the fight (10) together; a retry from 10 moves nothing.
function startMinemiteFight(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_000 then
		quest:StartSequence(SEQ_005)
	end
	if quest:GetSequence() ~= SEQ_010 then
		quest:StartSequence(SEQ_010)
	end
	local a = FIGHT_ARRIVAL
	startQuestContent(player, {
		zone = 170, content = "SimpleContentMan2u001", director = "Quest/QuestDirectorMan2u001",
		x = a[1], y = a[2], z = a[3], rot = a[4],
	})
end

-- Called by QuestDirectorMan2u001 once the last minemite is down. F'lhaminn is wounded.
function finishMinemiteFight(player, quest, duty, area)
	delegateEvent(player, quest, "processEvent030")
	quest:StartSequence(SEQ_015)
	leaveQuestContent(player, duty, area, { zone = 175, x = -36.571, y = 192, z = 19.598, rot = -3.019 })
end

function failMinemiteFight(player, quest, duty, area)
	player:SetHP(player:GetMaxHP())
	leaveQuestContent(player, duty, area, { zone = 175, x = -36.571, y = 192, z = 19.598, rot = -3.019 })
end

function getJournalInformation(player, quest)
	return
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
