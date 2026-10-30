require("Global")
require("Quest")
require("QuestFlow")

--[[
Beckon of the Elementals (Man2g0, 110008). Prereq: Whispers in the Wood (Man1g0); level 13.
Scene re-entries (Nonolato, Soileine, the amphitheatre push) replay the scene into the echo the current
sequence owns without moving the journal. Miounne restates the objective in person.
Walkthrough: Data/Docs/Scripts/Quest/Man/Man2g0.md.
--]]

local startDuty, wardTalk

local SEQ_000	= 0
local SEQ_003	= 3
SEQ_004	= 4
local SEQ_005	= 5
local SEQ_010	= 10
local SEQ_015	= 15
local SEQ_020	= 20
local SEQ_025	= 25
local SEQ_030	= 30
local SEQ_035	= 35
local SEQ_040	= 40
local SEQ_045	= 45
local SEQ_060	= 60

local MIOUNNE 					= 1000230
local MIOUNNE_DISPLAY_ID			= 1300018
local NONOLATO					= 1000463
local ANAIDJAA					= 1000465
local O_APP_PESI					= 1000033	-- the Hold echo, the duty (ward), the Fane echo

-- Stillglade Fane echoes
local FYE							= 1000014
local SOILEINE					= 1000234	-- public, by the Fane
local SOILEINE_ECHO				= 1700030
local WISE_LOOKING_CONJURER		= 1000743
local DISQUIETED_LANCER			= 1000744
local ENTHUSIASTIC_ARCHER			= 1000745
local EMBITTERED_ARCHER			= 1000746
local DISCONCERTED_CONJURER		= 1000747
local SILKY_HAIRED_CONJURER		= 1000748
local ENIGMATIC_CONJURER			= 1000749
local CNJ_GUILD_TRIGGER			= 1090178	-- marker 805, 206 PA 10

-- Mih Khetto's Amphitheatre
local YDA							= 1000009
local PAPALYMO					= 1000010
local NGOLBB						= 1000016
local FARRIMOND					= 1000017
local HANDELOUP					= 1000023
local GRINNAUX					= 1000024
local FUFUCHA						= 1000237
local BURCHARD					= 1000243
local WISPILY_WHISKERED_WOODWORKER = 1000562
local NIALL						= 1000754
local RESPECTABLE_ROEGADYN		= 1000755
local AGING_ELEZEN				= 1000756
local URBANE_ELEZEN				= 1000757
local SUGARSTRUNG_SCHOOLGIRL		= 1000824
local UNDERPRIVILEGED_URCHIN		= 1000825
local SQUEALING_SPRAT				= 1000826
local DESERTED_DAUGHTER			= 1000827
local TROUBLESOME_TOMBOY			= 1000828
local TKEBBE						= 1000876
local OVERANIMATED_HYUR			= 1001485
local GOOD_NATURED_GOODWIFE		= 1001486
local FASTIDIOUS_FELLOW			= 1001487
local MERRY_OLD_MATRON			= 1001488
local WELL_GROOMED_WOMAN			= 1001489
local URSBAEN						= 1001873
local AMPHITHEATRE_TRIGGER		= 1090179	-- marker 808, 206 public
local ECHO_TRIGGER				= 1090180	-- the Echo in the West Shroud, 153 PA 0

local MRKR_NONOLATO			= 11000801
local MRKR_OAPPPESI_HOLD		= 11000802
local MRKR_ANAIDJAA			= 11000803
local MRKR_SOILEINE			= 11000804
local MRKR_CNJ_GUILD			= 11000805
local MRKR_FYE				= 11000806
local MRKR_CNJ_OAPPPESI		= 11000807
local MRKR_AMPHITHEATRE		= 11000808
local MRKR_FYE_FESTIVAL		= 11000809

local FLAG_FYE_MET			= 0	-- Seq 25: Fye's processEvent045
local FLAG_WARD_GIVEN			= 1	-- the duty: the first ward handed over (Trial001 a3 1 -> 2)
CNTR_WARD				= 0	-- the duty: the ward element picked, 1 Wind / 2 Earth / 3 Water

local HOLD_ECHO		= { 206, "PrivateAreaMasterPast", 13, 228.307, 12.01, -1257.005, 0.0 }
local DUTY_ARRIVAL	= { 153, nil, 0, -2011.42, -11.679, -916.309, -2.815 }
local HOLD_OUT		= { 206, nil, 0, 220.416, 10.75, -1248.641, -0.061 }
local FANE_ECHO		= { 206, "PrivateAreaMasterPast", 10, -239.329, 19.495, -1646.319, 3.316 }
local FANE_AFTER		= { 206, "PrivateAreaMasterPast", 11, -322.202, 8.0, -1666.206, 0.775 }
local FESTIVAL_ECHO	= { 206, "PrivateAreaMasterPast", 12, -96.219, 10.356, -1632.551, 3.118 }
local WOOD_ECHO		= { 153, "PrivateAreaMasterPast", 0, -1939.459, 0.147, -891.202, -1.867 }
local ROOST			= { 155, nil, 0, 59.413, 4.0, -1219.275, 0.88 }

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

local PHASES = {
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

local MIOUNNE_REMINDERS = {
	[SEQ_000] = "processEvent005_2",
	[SEQ_003] = "processEvent1000_1", [SEQ_004] = "processEvent1000_1",
	[SEQ_005] = "processEvent010_2",
	[SEQ_010] = "processEvent020_2", [SEQ_015] = "processEvent020_2",
	[SEQ_020] = "processEvent020_2", [SEQ_025] = "processEvent020_2",
	[SEQ_030] = "processEvent050_2", [SEQ_035] = "processEvent050_2",
	[SEQ_040] = "processEvent050_2", [SEQ_045] = "processEvent050_2",
}

local CHATTER = {
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
local NPCLS_AFTER_DUTY = { 65, 66, 67 }
local NPCLS_FANE       = { 112, 113, 114, 115 }

local NPCLS_FLOW = {
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

local function chatter(player, quest, npc)
	delegateChatter(player, quest, CHATTER, quest:GetSequence(), npc:GetActorClassId())
end

-- A player who left the echo re-enters it here; the journal already sits on the duty.
local function reenterHold(player, quest)
	sceneAndWarp(player, quest, "processEvent007_3", nil, HOLD_ECHO)
	return true
end

local function pesiAsk(ask)
	return function(player, quest)
		if inDuty(player) then
			wardTalk(player, quest)
		elseif delegateEvent(player, quest, ask) == 1 then
			startDuty(player, quest)
			return true
		end
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[MIOUNNE] = function(player, quest)
			delegateEvent(player, quest, "processEventMiounneStart")
			player:EndEvent()
			player:AcceptQuest(quest)
			return true
		end,
		-- No chatter before the quest is taken.
		other = function() end,
	},
	[SEQ_000] = {
		[NONOLATO] = function(player, quest)
			sceneAndWarp(player, quest, "processEvent007", SEQ_003, HOLD_ECHO)
			return true
		end,
	},
	[SEQ_003] = {
		[NONOLATO] = reenterHold,
		[O_APP_PESI] = pesiAsk("processEvent007_2"),
	},
	[SEQ_004] = {
		[NONOLATO] = reenterHold,
		[O_APP_PESI] = pesiAsk("processEvent007_2_2"),
	},
	[SEQ_005] = {
		[ANAIDJAA] = function(player, quest)
			delegateEvent(player, quest, "processEvent020")
			quest:NewNpcLsMsg(1)
			quest:StartSequence(SEQ_010)
		end,
	},
	[SEQ_015] = {
		[SOILEINE] = function(player, quest)
			clearQuestFlag(quest, FLAG_FYE_MET)
			sceneAndWarp(player, quest, "processEvent030", SEQ_020, FANE_ECHO)
			return true
		end,
	},
	[SEQ_020] = {
		[SOILEINE] = function(player, quest)
			sceneAndWarp(player, quest, "processEvent030", nil, FANE_ECHO)
			return true
		end,
	},
	[SEQ_025] = {
		[SOILEINE] = function(player, quest)
			sceneAndWarp(player, quest, "processEvent030", nil, FANE_AFTER)
			return true
		end,
		[FYE] = function(player, quest, npc, data)
			if data:GetFlag(FLAG_FYE_MET) then
				delegateEvent(player, quest, "processEvent045_2")
			else
				delegateEvent(player, quest, "processEvent045")
				setQuestFlagOn(quest, FLAG_FYE_MET)
			end
		end,
		[O_APP_PESI] = function(player, quest, npc, data)
			if not data:GetFlag(FLAG_FYE_MET) then
				delegateEvent(player, quest, "processEvent040_4")
				return
			end
			delegateEvent(player, quest, "processEvent050")
			quest:NewNpcLsMsg(1)
			player:EndEvent()
			quest:StartSequence(SEQ_030)
			warpToPublic(player)
			return true
		end,
	},
	[SEQ_040] = {
		[FYE] = function(player, quest)
			sceneAndWarp(player, quest, "processEvent070", SEQ_045, WOOD_ECHO)
			return true
		end,
	},
	[SEQ_060] = {
		[MIOUNNE] = function(player, quest)
			turnInQuest(player, quest, "processEvent080_01", player:GetHighestLevel())
			return true
		end,
	},
	always = {
		[MIOUNNE] = function(player, quest, npc)
			local reminder = MIOUNNE_REMINDERS[quest:GetSequence()]
			if reminder ~= nil then
				delegateEvent(player, quest, reminder)
			else
				chatter(player, quest, npc)
			end
		end,
	},
	other = chatter,
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc, quest:GetData()) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

-- From 40 on, the push only replays the scene.
local function festivalEntrance(advanceTo)
	return function(player, quest)
		sceneAndWarp(player, quest, "processEvent060", advanceTo, FESTIVAL_ECHO)
		return true
	end
end

local push = {
	[SEQ_020] = {
		[CNJ_GUILD_TRIGGER] = function(player, quest)
			if currentZoneId(player) == 206 then
				sceneAndWarp(player, quest, "processEvent040", SEQ_025, FANE_AFTER)
				return true
			end
		end,
	},
	[SEQ_035] = { [AMPHITHEATRE_TRIGGER] = festivalEntrance(SEQ_040) },
	[SEQ_040] = { [AMPHITHEATRE_TRIGGER] = festivalEntrance(nil) },
	[SEQ_045] = {
		[AMPHITHEATRE_TRIGGER] = function(player, quest)
			sceneAndWarp(player, quest, "processEvent070", nil, WOOD_ECHO)
			return true
		end,
		[ECHO_TRIGGER] = function(player, quest)
			sceneAndWarp(player, quest, "processEvent080", SEQ_060, ROOST)
			return true
		end,
	},
}

function onPush(player, quest, npc)
	if runQuestHandler(push, player, quest, npc) then return end
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
