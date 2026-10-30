require("Global")
require("Quest")
require("QuestFlow")

--[[

Quest Script

Name: 	Beckon of the Elementals
Code: 	Man2g0
Id: 	110008
Prereq: Whispers in the Wood (Man1g0 - 110007), Level 13

Seq 65535: offered by Miounne.
Seq 0:  Nonolato at the Quiver's Hold: processEvent007 (man1g900, after warp) into the Hold echo, 206 PA 13.
Seq 3/4: O-App-Pesi asks (processEvent007_2 the first time, 007_2_2 on a retry; 1 = set forth) and the
        duty starts (QuestDirectorMan2g001, content SimpleContentMan2g001, the West Shroud). Nonolato
        (processEvent007_3) puts a player who left back into the echo. In the duty O-App-Pesi hands out
        the ward (processEventTrial001 a3 = 1 the first time, 2 after; returns 1 Wind, 2 Earth, 3 Water).
Seq 5:  Won: processEvent010 (after warp), back to the Hold; A'naidjaa (processEvent020); Miounne calls.
Seq 15/20/25: Soileine (processEvent030, after warp) into the Fane echo, 206 PA 10; the guild push
        (processEvent040, after warp) into PA 11; Fye (processEvent045), then O-App-Pesi
        (processEvent050, after warp) back out; Miounne calls.
Seq 35/40/45: The amphitheatre push (processEvent060) into the grand rite, 206 PA 12; Fye
        (processEvent070) into the Echo in the West Shroud, 153 PA 0; the push there (processEvent080, the
        ending) wakes the player at the Roost.
Seq 60: Miounne's turn-in (processEvent080_01, a3 = the player's highest level: 279 at 18 or more, else
        280).

Scene re-entries (Nonolato, Soileine, the amphitheatre push) replay the scene into the echo the current
sequence owns without moving the journal. Miounne restates the objective in person.

--]]

SEQ_000	= 0
SEQ_003	= 3
SEQ_004	= 4
SEQ_005	= 5
SEQ_010	= 10
SEQ_015	= 15
SEQ_020	= 20
SEQ_025	= 25
SEQ_030	= 30
SEQ_035	= 35
SEQ_040	= 40
SEQ_045	= 45
SEQ_060	= 60

MIOUNNE 					= 1000230
MIOUNNE_DISPLAY_ID			= 1300018
NONOLATO					= 1000463
ANAIDJAA					= 1000465
O_APP_PESI					= 1000033	-- the Hold echo, the duty (ward), the Fane echo

-- Stillglade Fane echoes
FYE							= 1000014
SOILEINE					= 1000234	-- public, by the Fane
SOILEINE_ECHO				= 1700030
WISE_LOOKING_CONJURER		= 1000743
DISQUIETED_LANCER			= 1000744
ENTHUSIASTIC_ARCHER			= 1000745
EMBITTERED_ARCHER			= 1000746
DISCONCERTED_CONJURER		= 1000747
SILKY_HAIRED_CONJURER		= 1000748
ENIGMATIC_CONJURER			= 1000749
CNJ_GUILD_TRIGGER			= 1090178	-- marker 805, 206 PA 10

-- Mih Khetto's Amphitheatre
YDA							= 1000009
PAPALYMO					= 1000010
NGOLBB						= 1000016
FARRIMOND					= 1000017
HANDELOUP					= 1000023
GRINNAUX					= 1000024
FUFUCHA						= 1000237
BURCHARD					= 1000243
WISPILY_WHISKERED_WOODWORKER = 1000562
NIALL						= 1000754
RESPECTABLE_ROEGADYN		= 1000755
AGING_ELEZEN				= 1000756
URBANE_ELEZEN				= 1000757
SUGARSTRUNG_SCHOOLGIRL		= 1000824
UNDERPRIVILEGED_URCHIN		= 1000825
SQUEALING_SPRAT				= 1000826
DESERTED_DAUGHTER			= 1000827
TROUBLESOME_TOMBOY			= 1000828
TKEBBE						= 1000876
OVERANIMATED_HYUR			= 1001485
GOOD_NATURED_GOODWIFE		= 1001486
FASTIDIOUS_FELLOW			= 1001487
MERRY_OLD_MATRON			= 1001488
WELL_GROOMED_WOMAN			= 1001489
URSBAEN						= 1001873
AMPHITHEATRE_TRIGGER		= 1090179	-- marker 808, 206 public
ECHO_TRIGGER				= 1090180	-- the Echo in the West Shroud, 153 PA 0

MRKR_NONOLATO			= 11000801
MRKR_OAPPPESI_HOLD		= 11000802
MRKR_ANAIDJAA			= 11000803
MRKR_SOILEINE			= 11000804
MRKR_CNJ_GUILD			= 11000805
MRKR_FYE				= 11000806
MRKR_CNJ_OAPPPESI		= 11000807
MRKR_AMPHITHEATRE		= 11000808
MRKR_FYE_FESTIVAL		= 11000809

FLAG_FYE_MET			= 0	-- Seq 25: Fye's processEvent045
FLAG_WARD_GIVEN			= 1	-- the duty: the first ward handed over (Trial001 a3 1 -> 2)
CNTR_WARD				= 0	-- the duty: the ward element picked, 1 Wind / 2 Earth / 3 Water

HOLD_ECHO		= { 206, "PrivateAreaMasterPast", 13, 228.307, 12.01, -1257.005, 0.0 }
DUTY_ARRIVAL	= { 153, nil, 0, -2011.42, -11.679, -916.309, -2.815 }
HOLD_OUT		= { 206, nil, 0, 220.416, 10.75, -1248.641, -0.061 }
FANE_ECHO		= { 206, "PrivateAreaMasterPast", 10, -239.329, 19.495, -1646.319, 3.316 }
FANE_AFTER		= { 206, "PrivateAreaMasterPast", 11, -322.202, 8.0, -1666.206, 0.775 }
FESTIVAL_ECHO	= { 206, "PrivateAreaMasterPast", 12, -96.219, 10.356, -1632.551, 3.118 }
WOOD_ECHO		= { 153, "PrivateAreaMasterPast", 0, -1939.459, 0.147, -891.202, -1.867 }
ROOST			= { 155, nil, 0, 59.413, 4.0, -1219.275, 0.88 }

DUTY_CONTENT = "SimpleContentMan2g001"

local function inEcho(player, quest, data) return inPrivateArea(player) end
local function outOfEcho(player, quest, data) return not inPrivateArea(player) end
local function fyeUnmet(player, quest, data) return not data:GetFlag(FLAG_FYE_MET) end
local function fyeMet(player, quest, data) return data:GetFlag(FLAG_FYE_MET) end
local function inEchoFyeUnmet(player, quest, data) return inPrivateArea(player) and fyeUnmet(player, quest, data) end
local function inEchoFyeMet(player, quest, data) return inPrivateArea(player) and fyeMet(player, quest, data) end

local FESTIVAL_CROWD = {
	NIALL, YDA, PAPALYMO, FUFUCHA, BURCHARD, URSBAEN, NGOLBB, FARRIMOND, TKEBBE, HANDELOUP, GRINNAUX,
	SQUEALING_SPRAT, UNDERPRIVILEGED_URCHIN, SUGARSTRUNG_SCHOOLGIRL, DESERTED_DAUGHTER, TROUBLESOME_TOMBOY,
	AGING_ELEZEN, WISPILY_WHISKERED_WOODWORKER, RESPECTABLE_ROEGADYN, URBANE_ELEZEN, MERRY_OLD_MATRON,
	WELL_GROOMED_WOMAN, GOOD_NATURED_GOODWIFE, OVERANIMATED_HYUR, FASTIDIOUS_FELLOW,
}

PHASES = {
	[SEQ_000] = {
		enpcs = { { NONOLATO, QFLAG_TALK }, MIOUNNE },
		markers = { MRKR_NONOLATO },
	},
	[SEQ_003] = {
		enpcs = { { O_APP_PESI, QFLAG_TALK }, { NONOLATO, QFLAG_TALK }, MIOUNNE },
		markers = { { MRKR_OAPPPESI_HOLD, when = inEcho }, { MRKR_NONOLATO, when = outOfEcho } },
	},
	-- The duty owns the journal at 4 across a loss and its retry: both ways back stay armed.
	[SEQ_004] = {
		enpcs = { { O_APP_PESI, QFLAG_TALK }, { NONOLATO, QFLAG_TALK }, MIOUNNE },
		markers = { { MRKR_NONOLATO, when = outOfEcho } },
	},
	[SEQ_005] = {
		enpcs = { { ANAIDJAA, QFLAG_TALK }, MIOUNNE },
		markers = { MRKR_ANAIDJAA },
	},
	-- The linkpearl carries this step.
	[SEQ_010] = {
		enpcs = { MIOUNNE },
	},
	[SEQ_015] = {
		enpcs = { { SOILEINE, QFLAG_TALK }, MIOUNNE },
		markers = { MRKR_SOILEINE },
	},
	[SEQ_020] = {
		enpcs = {
			{ SOILEINE, QFLAG_TALK },
			DISQUIETED_LANCER, ENTHUSIASTIC_ARCHER, EMBITTERED_ARCHER, SILKY_HAIRED_CONJURER,
			WISE_LOOKING_CONJURER, DISCONCERTED_CONJURER, ENIGMATIC_CONJURER, SOILEINE_ECHO,
			{ CNJ_GUILD_TRIGGER, QFLAG_PUSH, talk = false, push = true },
			MIOUNNE,
		},
		markers = { { MRKR_CNJ_GUILD, when = inEcho }, { MRKR_SOILEINE, when = outOfEcho } },
	},
	[SEQ_025] = {
		enpcs = {
			{ SOILEINE, QFLAG_TALK },
			SILKY_HAIRED_CONJURER, DISCONCERTED_CONJURER, ENIGMATIC_CONJURER, SOILEINE_ECHO,
			{ FYE, QFLAG_TALK, when = fyeUnmet },
			{ O_APP_PESI, QFLAG_TALK, when = fyeMet },
			MIOUNNE,
		},
		markers = {
			{ MRKR_FYE, when = inEchoFyeUnmet },
			{ MRKR_CNJ_OAPPPESI, when = inEchoFyeMet },
			{ MRKR_SOILEINE, when = outOfEcho },
		},
	},
	[SEQ_030] = {
		enpcs = { MIOUNNE },
	},
	[SEQ_035] = {
		enpcs = { { AMPHITHEATRE_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true }, MIOUNNE },
		markers = { MRKR_AMPHITHEATRE },
	},
	[SEQ_040] = {
		enpcs = {
			{ FYE, QFLAG_TALK },
			{ AMPHITHEATRE_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true },
			{ crowd = FESTIVAL_CROWD },
			MIOUNNE,
		},
		markers = { { MRKR_FYE_FESTIVAL, when = inEcho }, { MRKR_AMPHITHEATRE, when = outOfEcho } },
	},
	-- The client draws marker 810 well past the walk to the push, so the echo shows none.
	[SEQ_045] = {
		enpcs = {
			{ ECHO_TRIGGER, QFLAG_PUSH, talk = false, push = true },
			{ AMPHITHEATRE_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true },
			YDA, PAPALYMO, MIOUNNE,
		},
		markers = { { MRKR_AMPHITHEATRE, when = outOfEcho } },
	},
	[SEQ_060] = {
		enpcs = { { MIOUNNE, QFLAG_REWARD } },
	},
}

MIOUNNE_REMINDERS = {
	[SEQ_000] = "processEvent005_2",
	[SEQ_003] = "processEvent1000_1", [SEQ_004] = "processEvent1000_1",
	[SEQ_005] = "processEvent010_2",
	[SEQ_010] = "processEvent020_2", [SEQ_015] = "processEvent020_2",
	[SEQ_020] = "processEvent020_2", [SEQ_025] = "processEvent020_2",
	[SEQ_030] = "processEvent050_2", [SEQ_035] = "processEvent050_2",
	[SEQ_040] = "processEvent050_2", [SEQ_045] = "processEvent050_2",
}

CHATTER = {
	[SEQ_020] = {
		[SOILEINE_ECHO]         = "processEvent030_2",
		[DISQUIETED_LANCER]     = "processEvent030_3",
		[DISCONCERTED_CONJURER] = "processEvent030_4",
		[WISE_LOOKING_CONJURER] = "processEvent030_5",
		[ENIGMATIC_CONJURER]    = "processEvent030_6",
		[SILKY_HAIRED_CONJURER] = "processEvent030_7",
		[ENTHUSIASTIC_ARCHER]   = "processEvent030_8",
		[EMBITTERED_ARCHER]     = "processEvent030_9",
	},
	[SEQ_025] = {
		[SOILEINE_ECHO]         = "processEvent030_2",
		[ENIGMATIC_CONJURER]    = "processEvent030_6",
		[SILKY_HAIRED_CONJURER] = "processEvent040_2",
		[DISCONCERTED_CONJURER] = "processEvent040_3",
	},
	[SEQ_040] = {
		[NIALL]                        = "processEvent060_2",
		[YDA]                          = "processEvent060_3",
		[PAPALYMO]                     = "processEvent060_4",
		[FUFUCHA]                      = "processEvent060_5",
		[BURCHARD]                     = "processEvent060_6",
		[URSBAEN]                      = "processEvent060_7",
		[NGOLBB]                       = "processEvent060_8",
		[FARRIMOND]                    = "processEvent060_9",
		[TKEBBE]                       = "processEvent060_10",
		[HANDELOUP]                    = "processEvent060_11",
		[GRINNAUX]                     = "processEvent060_12",
		[SQUEALING_SPRAT]              = "processEvent060_13",
		[UNDERPRIVILEGED_URCHIN]       = "processEvent060_14",
		[SUGARSTRUNG_SCHOOLGIRL]       = "processEvent060_15",
		[DESERTED_DAUGHTER]            = "processEvent060_16",
		[TROUBLESOME_TOMBOY]           = "processEvent060_17",
		[AGING_ELEZEN]                 = "processEvent060_18",
		[WISPILY_WHISKERED_WOODWORKER] = "processEvent060_19",
		[RESPECTABLE_ROEGADYN]         = "processEvent060_20",
		[URBANE_ELEZEN]                = "processEvent060_21",
		[MERRY_OLD_MATRON]             = "processEvent060_22",
		[WELL_GROOMED_WOMAN]           = "processEvent060_23",
		[GOOD_NATURED_GOODWIFE]        = "processEvent060_24",
		[OVERANIMATED_HYUR]            = "processEvent060_25",
		[FASTIDIOUS_FELLOW]            = "processEvent060_26",
	},
	-- Both stand inside the push circle; the lines are for a push that does not fire.
	[SEQ_045] = {
		[YDA]      = "processEvent070_2",
		[PAPALYMO] = "processEvent070_3",
	},
}

-- Linkpearl packs (man2g0 text sheet, sender Miounne).
NPCLS_AFTER_DUTY = { 65, 66, 67 }
NPCLS_FANE       = { 112, 113, 114, 115 }

NPCLS_FLOW = {
	from = 1,
	sender = MIOUNNE_DISPLAY_ID,
	packs = {
		[SEQ_010] = NPCLS_AFTER_DUTY, [SEQ_015] = NPCLS_AFTER_DUTY,
		[SEQ_030] = NPCLS_FANE, [SEQ_035] = NPCLS_FANE,
	},
	advances = { [SEQ_010] = SEQ_015, [SEQ_030] = SEQ_035 },
}

local function warpToPoint(player, p)
	warpTo(player, p[1], p[2], p[3], p[4], p[5], p[6], p[7])
end

local function inDuty(player)
	return player.CurrentArea:GetPrivateAreaName() == DUTY_CONTENT
end

-- Plays a scene that ends in a fade-in after warp, then the warp. advanceTo nil: a replay.
local function sceneAndWarp(player, quest, eventName, advanceTo, point)
	delegateEvent(player, quest, eventName)
	player:EndEvent()
	if advanceTo ~= nil then
		quest:StartSequence(advanceTo)
	end
	warpToPoint(player, point)
end

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		if player:IsQuestCompleted(110007) then
			quest:SetENpc(MIOUNNE, QFLAG_TALK)
		end
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	local data = quest:GetData()

	if sequence == SEQ_ACCEPT then
		if classId == MIOUNNE then
			delegateEvent(player, quest, "processEventMiounneStart")
			player:EndEvent()
			player:AcceptQuest(quest)
			return
		end
	elseif sequence == SEQ_060 and classId == MIOUNNE then
		turnInQuest(player, quest, "processEvent080_01", player:GetHighestLevel())
		return
	elseif classId == MIOUNNE and MIOUNNE_REMINDERS[sequence] ~= nil then
		delegateEvent(player, quest, MIOUNNE_REMINDERS[sequence])
	elseif sequence == SEQ_000 and classId == NONOLATO then
		sceneAndWarp(player, quest, "processEvent007", SEQ_003, HOLD_ECHO)
		return
	elseif (sequence == SEQ_003 or sequence == SEQ_004) and classId == NONOLATO then
		-- A player who left the echo re-enters it here; the journal already sits on the duty.
		sceneAndWarp(player, quest, "processEvent007_3", nil, HOLD_ECHO)
		return
	elseif (sequence == SEQ_003 or sequence == SEQ_004) and classId == O_APP_PESI then
		if inDuty(player) then
			wardTalk(player, quest)
		else
			local ask = (sequence == SEQ_003) and "processEvent007_2" or "processEvent007_2_2"
			if delegateEvent(player, quest, ask) == 1 then
				startDuty(player, quest)
				return
			end
		end
	elseif sequence == SEQ_005 and classId == ANAIDJAA then
		delegateEvent(player, quest, "processEvent020")
		quest:NewNpcLsMsg(1)
		quest:StartSequence(SEQ_010)
	elseif sequence == SEQ_015 and classId == SOILEINE then
		clearQuestFlag(quest, FLAG_FYE_MET)
		sceneAndWarp(player, quest, "processEvent030", SEQ_020, FANE_ECHO)
		return
	elseif sequence == SEQ_020 and classId == SOILEINE then
		sceneAndWarp(player, quest, "processEvent030", nil, FANE_ECHO)
		return
	elseif sequence == SEQ_025 and classId == SOILEINE then
		sceneAndWarp(player, quest, "processEvent030", nil, FANE_AFTER)
		return
	elseif sequence == SEQ_025 and classId == FYE then
		if data:GetFlag(FLAG_FYE_MET) then
			delegateEvent(player, quest, "processEvent045_2")
		else
			delegateEvent(player, quest, "processEvent045")
			setQuestFlagOn(quest, FLAG_FYE_MET)
		end
	elseif sequence == SEQ_025 and classId == O_APP_PESI then
		if not data:GetFlag(FLAG_FYE_MET) then
			delegateEvent(player, quest, "processEvent040_4")
		else
			delegateEvent(player, quest, "processEvent050")
			quest:NewNpcLsMsg(1)
			player:EndEvent()
			quest:StartSequence(SEQ_030)
			warpToPublic(player)
			return
		end
	elseif sequence == SEQ_040 and classId == FYE then
		sceneAndWarp(player, quest, "processEvent070", SEQ_045, WOOD_ECHO)
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

	if sequence == SEQ_020 and classId == CNJ_GUILD_TRIGGER and currentZoneId(player) == 206 then
		sceneAndWarp(player, quest, "processEvent040", SEQ_025, FANE_AFTER)
		return
	elseif (sequence == SEQ_035 or sequence == SEQ_040) and classId == AMPHITHEATRE_TRIGGER then
		-- At 40 a replay of the festival entrance.
		sceneAndWarp(player, quest, "processEvent060", (sequence == SEQ_035) and SEQ_040 or nil, FESTIVAL_ECHO)
		return
	elseif sequence == SEQ_045 and classId == AMPHITHEATRE_TRIGGER then
		sceneAndWarp(player, quest, "processEvent070", nil, WOOD_ECHO)
		return
	elseif sequence == SEQ_045 and classId == ECHO_TRIGGER then
		sceneAndWarp(player, quest, "processEvent080", SEQ_060, ROOST)
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onNpcLS(player, quest, from, msgStep)
	readNpcLs(player, quest, NPCLS_FLOW, from, msgStep)
end

-- The ask answered yes (event still open). A retry from 4 moves nothing; the ward starts over.
function startDuty(player, quest)
	clearQuestFlag(quest, FLAG_WARD_GIVEN)
	setQuestCounter(quest, CNTR_WARD, 0)
	if quest:GetSequence() ~= SEQ_004 then
		quest:StartSequence(SEQ_004)
	end
	local a = DUTY_ARRIVAL
	startQuestContent(player, {
		zone = a[1], content = DUTY_CONTENT, director = "Quest/QuestDirectorMan2g001",
		x = a[4], y = a[5], z = a[6], rot = a[7],
	})
end

-- O-App-Pesi in the duty: the ward (a3 = 1 the first handing, 2 after), then the attuning line. The
-- element picked is what QuestDirectorMan2g001 checks against the spirit's aspect.
function wardTalk(player, quest)
	local handing = getQuestFlag(quest, FLAG_WARD_GIVEN) and 2 or 1
	local element = delegateEvent(player, quest, "processEventTrial001", handing)
	if element == 1 or element == 2 or element == 3 then
		setQuestCounter(quest, CNTR_WARD, element)
		if handing == 1 then
			setQuestFlagOn(quest, FLAG_WARD_GIVEN)
		end
		delegateEvent(player, quest, "processEventTrial002")
	end
end

-- Called by QuestDirectorMan2g001 once the spirit falls, with its noticeEvent open.
function finishSpirit(player, quest, fight, area)
	delegateEvent(player, quest, "processEvent010")
	quest:StartSequence(SEQ_005)
	local o = HOLD_OUT
	leaveQuestContent(player, fight, area, { zone = o[1], x = o[4], y = o[5], z = o[6], rot = o[7] })
end

-- A lost fight keeps 4: back to the Hold, where O-App-Pesi asks again.
function failSpirit(player, quest, fight, area)
	player:SetHP(player:GetMaxHP())
	local o = HOLD_OUT
	leaveQuestContent(player, fight, area, { zone = o[1], x = o[4], y = o[5], z = o[6], rot = o[7] })
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
