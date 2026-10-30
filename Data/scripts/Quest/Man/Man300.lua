require("Global")
require("Quest")
require("QuestFlow")

--[[
Toll of the Warden (Man300, 110015). Prereq: Together We Stand (Man206); level 30.
Man206's turn-in hands it on held at 5 (the journal has no paragraph for 5); Tataru's pEStart accepts.
The Peasants Ward stands in 181 PA 13/14 until the server has zone 161. Each tribe is settled by force
or by a Parley won with its shaman. Walkthrough: Data/Docs/Scripts/Quest/Man/Man300.md.
--]]

local isInWard, talkToShaman, startMesaDuty

local AFTER_WARP_NOTICE = true

local SEQ_000 = 0
local SEQ_005 = 5
local SEQ_010 = 10
local SEQ_015 = 15
local SEQ_020 = 20
SEQ_025 = 25
SEQ_030 = 30
local SEQ_035 = 35

local MINFILIA             = 1000843
local TATARU               = 1001046
local SERANELIEN           = 1001378
local SAHJA_ZHWAN          = 1001373
local NENEKANI             = 1001374
local GODFREY              = 1001375
local FENANA               = 1001376
local NONORU               = 1001377
local HEDYN                = 1001047
local SHANGA_MESHANGA      = 1001048
local TROXIA               = 1001049
local NANANOBY             = 1001050
local ALMXIO               = 1001085
local ZOXIO                = 1001086
local LOYAL_IXAL           = 1001095
local ABLE_BODIED_AMALJAA  = 1001098
local DILUXIO              = 1001178
local LANXIO               = 1001179
local YOYOKA               = 1001380
local CLIAUX               = 1001381
local CENMIN               = 1001382
local MAUCOLYN             = 1001383
local MEMEZOFU             = 1001384
local NYXIA                = 1001385
local GONAXIA              = 1001386
local ZEXIA                = 1001387
local PANNIXIA             = 1001388
local DAXIA                = 1001389

local ULDAH_ENTRANCE       = 1090265 -- MarketEntrance
local GRIDANIA_ENTRANCE    = 1090264 -- MarketEntrance; also the company offices' exits
local SANDS_EXIT_DOOR      = 1090160 -- ObjectEventDoor (the ward's copy too)
local OFFICE_WEST_DOOR     = 1090161
local OFFICE_EAST_DOOR     = 1090162
local DRYBONE_TRIGGER      = 1090241 -- Camp Drybone (public 171)
local MESA_TRIGGER         = 1090211 -- the excavation mesa (public 171, quest-gated)

local SNPC_BASE            = 1070000

local MRKR_MARKET_ENTRANCE   = 11001501
local MRKR_HEDYN             = 11001502
local MRKR_CAMP_DRYBONE      = 11001503
local MRKR_MESA              = 11001505
local MRKR_NANANOBY          = 11001506
local MRKR_HEDYN_REPORT      = 11001507
-- The client ships no holder marker for 110015: the sibling quests' rows stand in.
local MRKR_SANDS_MINFILIA    = 11001301
local MRKR_SANDS_TATARU      = 11001303
local MRKR_ULDAH_ENTRANCE    = 11001407

local FLAG_OFFICE_SCENE   = 0
local FLAG_HEDYN_FOLLOWUP = 1
local FLAG_MESA_SCENE     = 2
FLAG_BRIEFING       = 3
FLAG_AMALJAA_DONE   = 4
FLAG_IXAL_DONE      = 5
local FLAG_AMALJAA_MET    = 6  -- the shaman's first talk at 30 opens its Parley
local FLAG_IXAL_MET       = 7
local FLAG_PARLEY_SHOWN   = 8  -- the "select Parley" pointer was shown this run

-- Parley with the shamans: negotiationTable rows 5101 / 5001 (both "Toll of the Warden"; which row
-- goes with which shaman is a server choice). Topics are negotiationItem keys.
local TEXT_MAY_PARLEY     = 51034 -- worldMaster "You may now parley with <name> as part of <quest>."
local TEXT_PARLEY_TARGET  = 51050 -- worldMaster "Target <name> and select Parley from the interaction menu."
local TEXT_WILL_TO_FIGHT  = 51002 -- worldMaster "<name> has / have lost the will to fight."
local SHAMANS = {
	[1001098] = { met = FLAG_AMALJAA_MET, done = FLAG_AMALJAA_DONE, displayNameId = 4000508, row = 5101,
		topics = { 1002, 1008, 1022, 1007, 1023, 2007, 3036, 3034, 2001 } },
	[1001095] = { met = FLAG_IXAL_MET, done = FLAG_IXAL_DONE, displayNameId = 4000505, row = 5001,
		topics = { 1003, 1007, 1002, 1023, 2010, 3007, 3018, 3014, 3016, 3021, 2002 } },
}

local CNTR_DRYBONE_PEARL = 0 -- 5 once the pearl glows at Camp Drybone (journal int2, row 266)

local NPCLS_PATH          = 6
local NPCLS_ASHCROWN      = 7
local MINFILIA_DISPLAY_ID = 1100449
local TEXT_MINFILIA_CALL  = 1
local TEXT_DRYBONE_BASE   = 533  -- + pack position - 1
local TEXT_MESA_LINE_BASE = 426  -- the companion's mesa line, + pack position - 1
local QUEST_LEVEL         = 30

local WAKING_SANDS_ZONE   = 181
local PEASANTS_WARD_ZONE  = 161
local WARD_FALLBACK_PA    = 12   -- ward PA n stands in 181 PA 12 + n while zone 161 is missing
local SANDS_BRIEFING_PA   = 12
local SANDS_PA            = 11
local MESA_ZONE           = 171
local GRIDANIA_ZONE       = 206

local SANDS_ENTRY      = { -205.25, 0, -160, 1.55 }
local WARD_ENTRY       = { -200.970, 0.015, -160.019, 1.575 }
local SOLAR_OUTSIDE    = { -142.75, 1, -160, -1.6 }
local AFTER_BRIEFING   = { -141.0, 1, -160, 1.57 }
local AFTER_RECEPTION  = { -143.258, 1.015, -160.029, -1.599 }
local ULDAH_STREET     = { 175, -216.52, 190, 30.5, 2.32 }
local GRIDANIA_STREET  = { 206, -180, 22, -1408, 1.5 }     -- the archway's own ward exit point
local MESA_ARRIVAL     = { 1001.755, 252.750, -280.197, 1.010 }
local MESA_EXIT        = { 1034.830, 251.660, -269.040, -2.860 }

local function isLevelMet(player)
	return player:GetLevel() >= QUEST_LEVEL
end

local function isInWakingSands(player)
	return currentZoneId(player) == WAKING_SANDS_ZONE and not isInWard(player)
end

local function isOutOfWakingSands(player)
	return not isInWakingSands(player)
end

local function isOfficeSceneSeen(player, quest, data)
	return isLevelMet(player) and data:GetFlag(FLAG_OFFICE_SCENE)
end

local function isOfficeSceneUnseen(player, quest, data)
	return isLevelMet(player) and not data:GetFlag(FLAG_OFFICE_SCENE)
end

local function isPearlUnrung(player, quest, data)
	return data:GetCounter(CNTR_DRYBONE_PEARL) ~= 5
end

-- The archway class also stands in the Ul'dah market copies and Gridania's in the company offices.
local function isInUldah(player)
	return currentZoneId(player) == 175
end

local function isOutsideContent(player)
	return not inPrivateArea(player)
end

local SANDS_CROWD = { SERANELIEN, SAHJA_ZHWAN, NENEKANI, GODFREY, FENANA, NONORU }
-- Shanga Meshanga and Troxia have no line of their own: they stand silent.
local WARD_ARRIVAL_CROWD = { SHANGA_MESHANGA, TROXIA, MEMEZOFU, YOYOKA, CENMIN, CLIAUX, MAUCOLYN }
local WARD_BRIEFED_CROWD = {
	SHANGA_MESHANGA, TROXIA, MEMEZOFU, YOYOKA, CENMIN, CLIAUX, MAUCOLYN, DILUXIO, LANXIO, NYXIA, GONAXIA, ZEXIA, PANNIXIA, DAXIA,
}
local WARD_REPORT_CROWD = {
	SHANGA_MESHANGA, TROXIA, NANANOBY, MEMEZOFU, YOYOKA, CENMIN, CLIAUX, MAUCOLYN, DILUXIO, LANXIO, NYXIA, GONAXIA, ZEXIA, PANNIXIA, DAXIA,
}
local MESA_CAST = { ALMXIO, ZOXIO, LOYAL_IXAL, ABLE_BODIED_AMALJAA }

local function door(classId)
	return { classId, QFLAG_OFF, talk = false, push = true }
end

local WARD_DOORS = { door(SANDS_EXIT_DOOR), door(OFFICE_WEST_DOOR), door(OFFICE_EAST_DOOR) }
local WARD_ENTRANCE = { GRIDANIA_ENTRANCE, QFLAG_OFF, talk = false, push = true }
local MESA = { MESA_TRIGGER, QFLAG_PUSH, talk = false, push = isOutsideContent, spawn = true }

local PHASES = {
	[SEQ_005] = {
		enpcs = {
			{ TATARU, QFLAG_TALK, when = isOfficeSceneSeen },
			{ OFFICE_WEST_DOOR, QFLAG_PUSH, when = isOfficeSceneUnseen, talk = false, push = true },
			door(OFFICE_EAST_DOOR), door(SANDS_EXIT_DOOR),
			{ ULDAH_ENTRANCE, QFLAG_OFF, talk = false, push = function(player) return isLevelMet(player) and isInUldah(player); end },
			{ crowd = SANDS_CROWD },
		},
		markers = {
			{ MRKR_SANDS_MINFILIA, when = function(player, quest, data)
				return isInWakingSands(player) and isOfficeSceneUnseen(player, quest, data);
			end },
			{ MRKR_SANDS_TATARU, when = function(player, quest, data)
				return isInWakingSands(player) and isOfficeSceneSeen(player, quest, data);
			end },
			{ MRKR_ULDAH_ENTRANCE, when = function(player) return isLevelMet(player) and isOutOfWakingSands(player); end },
		},
	},
	[SEQ_000] = {
		enpcs = {
			TATARU, door(OFFICE_WEST_DOOR), door(OFFICE_EAST_DOOR), door(SANDS_EXIT_DOOR),
			{ ULDAH_ENTRANCE, QFLAG_OFF, talk = false, push = isInUldah }, WARD_ENTRANCE, { crowd = SANDS_CROWD },
		},
		markers = { MRKR_MARKET_ENTRANCE },
	},
	[SEQ_010] = {
		enpcs = {
			{ HEDYN, QFLAG_TALK }, WARD_DOORS[1], WARD_DOORS[2], WARD_DOORS[3], WARD_ENTRANCE,
			{ crowd = WARD_ARRIVAL_CROWD },
		},
		markers = { MRKR_HEDYN },
	},
	-- Hedyn's follow-up carries no icon.
	[SEQ_015] = {
		enpcs = {
			HEDYN, { DRYBONE_TRIGGER, QFLAG_PUSH, when = isPearlUnrung, talk = false, push = isPearlUnrung },
			WARD_DOORS[1], WARD_DOORS[2], WARD_DOORS[3], WARD_ENTRANCE, { crowd = WARD_BRIEFED_CROWD },
		},
		markers = { { MRKR_CAMP_DRYBONE, when = isPearlUnrung } },
	},
	[SEQ_020] = {
		enpcs = { HEDYN, MESA, WARD_DOORS[1], WARD_DOORS[2], WARD_DOORS[3], WARD_ENTRANCE, { crowd = WARD_BRIEFED_CROWD } },
		markers = { MRKR_MESA },
	},
	-- Inside the duty; the mesa stays armed for a player who left the content without a result.
	[SEQ_025] = {
		enpcs = { { NANANOBY, QFLAG_TALK }, MESA, { crowd = MESA_CAST } },
		markers = { { MRKR_NANANOBY, when = inPrivateArea }, { MRKR_MESA, when = isOutsideContent } },
	},
	[SEQ_030] = {
		enpcs = { NANANOBY, MESA, { crowd = MESA_CAST } },
		markers = { { MRKR_MESA, when = isOutsideContent } },
	},
	[SEQ_035] = {
		enpcs = {
			{ HEDYN, QFLAG_REWARD }, WARD_DOORS[1], WARD_DOORS[2], WARD_DOORS[3], WARD_ENTRANCE,
			{ crowd = WARD_REPORT_CROWD },
		},
		markers = { MRKR_HEDYN_REPORT },
	},
}

local WARD_ARRIVAL_LINES = {
	[MEMEZOFU] = "processEvent010_2", [YOYOKA] = "processEvent010_3", [CENMIN] = "processEvent010_4",
	[CLIAUX] = "processEvent010_5", [MAUCOLYN] = "processEvent010_6",
}

local WARD_BRIEFED_LINES = {
	[MEMEZOFU] = "processEvent010_2", [YOYOKA] = "processEvent010_3", [CENMIN] = "processEvent010_4",
	[CLIAUX] = "processEvent010_5", [MAUCOLYN] = "processEvent010_6", [DILUXIO] = "processEvent020_3",
	[LANXIO] = "processEvent020_4", [NYXIA] = "processEvent020_5", [GONAXIA] = "processEvent020_6",
	[ZEXIA] = "processEvent020_7", [PANNIXIA] = "processEvent020_8", [DAXIA] = "processEvent020_9",
}

local CHATTER = {
	[SEQ_005] = {
		[SERANELIEN] = "processEvent000_3", [SAHJA_ZHWAN] = "processEvent000_4", [NENEKANI] = "processEvent000_5",
		[GODFREY] = "processEvent000_6", [FENANA] = "processEvent000_7", [NONORU] = "processEvent000_8",
	},
	[SEQ_000] = {
		[GODFREY] = "processEvent005_2", [FENANA] = "processEvent005_3", [NENEKANI] = "processEvent005_4",
		[SAHJA_ZHWAN] = "processEvent005_5", [SERANELIEN] = "processEvent005_6", [NONORU] = "processEvent005_7",
	},
	[SEQ_010] = WARD_ARRIVAL_LINES,
	[SEQ_015] = WARD_BRIEFED_LINES,
	[SEQ_020] = WARD_BRIEFED_LINES,
	[SEQ_025] = { [ALMXIO] = "processEvent030_2", [ZOXIO] = "processEvent030_3" },
	[SEQ_030] = { [ALMXIO] = "processEvent040_3", [ZOXIO] = "processEvent040_4" },
	-- The 050_3..7 speakers run a talk motion the client script owns.
	[SEQ_035] = {
		[NANANOBY] = "processEvent050_2", [MEMEZOFU] = "processEvent050_3", [YOYOKA] = "processEvent050_4",
		[CENMIN] = "processEvent050_5", [CLIAUX] = "processEvent050_6", [MAUCOLYN] = "processEvent050_7",
		[DILUXIO] = "processEvent050_8", [LANXIO] = "processEvent050_9", [NYXIA] = "processEvent050_10",
		[GONAXIA] = "processEvent050_11", [ZEXIA] = "processEvent050_12", [PANNIXIA] = "processEvent050_13",
		[DAXIA] = "processEvent050_14",
	},
}

-- The companion block (name, skin, personality, coordinate, home town); pE30 and pE50 take one more.
local function delegateCompanion(player, quest, eventName, ...)
	return delegateEvent(player, quest, eventName, player:GetSNpcNickname(), player:GetSNpcSkin(),
		player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown(), ...)
end

-- pEStart and processEvent005_8 read the name as text parameter 1; parameter 2 is unknown (the
-- personality is a guess).
local function delegateCompanionTopic(player, quest, eventName)
	return delegateEvent(player, quest, eventName, player:GetSNpcNickname(), player:GetSNpcPersonality())
end

local function companionClass(player)
	return SNPC_BASE + player:GetSNpcSkin()
end

-- The companion's nine-line packs run by pack position, which swaps personalities 7 and 8.
local function companionPackPosition(player)
	local p = player:GetSNpcPersonality()
	if p == nil or p < 1 or p > 9 then
		return 1
	elseif p == 7 then
		return 8
	elseif p == 8 then
		return 7
	end
	return p
end

-- The Peasants Ward: zone 161 PA n, or its stand-in 181 PA 12 + n.
local function wardArea(level)
	if GetWorldManager():GetZone(PEASANTS_WARD_ZONE) ~= nil then
		return PEASANTS_WARD_ZONE, level
	end
	return WAKING_SANDS_ZONE, WARD_FALLBACK_PA + level
end

function isInWard(player)
	local area = player.CurrentArea
	if area.ZoneId == PEASANTS_WARD_ZONE then
		return true
	end
	return area.ZoneId == WAKING_SANDS_ZONE and area:IsPrivate() and area:GetPrivateAreaName() == "PrivateAreaMasterPast"
		and area:GetPrivateAreaType() > WARD_FALLBACK_PA
end

local function warpToWard(player, level)
	local zone, paLevel = wardArea(level)
	local p = WARD_ENTRY
	warpTo(player, zone, "PrivateAreaMasterPast", paLevel, p[1], p[2], p[3], p[4])
end

function onStart(player, quest)
	quest:StartSequence(SEQ_005)
	-- Minfilia's call arms once per grant and never advances.
	quest:NewNpcLsMsg(NPCLS_PATH)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		-- A character who finished Together We Stand before the hand-on existed: the Ul'dah archway.
		quest:SetENpc(ULDAH_ENTRANCE, QFLAG_PUSH, false, true)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
	if sequence == SEQ_025 or sequence == SEQ_030 then
		quest:SetENpc(companionClass(player))
	end
end

local function chatter(player, quest, npc)
	delegateChatter(player, quest, CHATTER, quest:GetSequence(), npc:GetActorClassId())
end

-- He follows up once, then repeats the short form; from 20 only the short form.
local function hedynFollowUp(player, quest)
	if quest:GetSequence() == SEQ_020 or getQuestFlag(quest, FLAG_HEDYN_FOLLOWUP) then
		delegateEvent(player, quest, "processEvent022_1")
	else
		delegateEvent(player, quest, "processEvent020_2")
		setQuestFlagOn(quest, FLAG_HEDYN_FOLLOWUP)
	end
end

local function nananobyTalk(player, quest)
	if quest:GetSequence() == SEQ_025 and not getQuestFlag(quest, FLAG_BRIEFING) then
		playBriefing(player, quest)
		return true
	end
	delegateEvent(player, quest, "processEvent040_2")
end

local function mesaTalk(player, quest, npc)
	if npc:GetActorClassId() == companionClass(player) then
		player:SendGameMessage(npc, quest, TEXT_MESA_LINE_BASE + companionPackPosition(player) - 1, MESSAGE_TYPE_SAY)
	else
		chatter(player, quest, npc)
	end
end

local talk = {
	[SEQ_005] = {
		[TATARU] = function(player, quest)
			if isOfficeSceneSeen(player, quest, quest:GetData()) then
				-- The decline plays inside the scene.
				if delegateCompanionTopic(player, quest, "pEStart") == 1 then
					player:EndEvent()
					quest:StartSequence(SEQ_000)
					return true
				end
			elseif isLevelMet(player) then
				delegateEvent(player, quest, "processEvent000_2")
			end
		end,
	},
	[SEQ_000] = {
		[TATARU] = function(player, quest) delegateCompanionTopic(player, quest, "processEvent005_8") end,
	},
	[SEQ_010] = {
		[HEDYN] = function(player, quest)
			delegateCompanion(player, quest, "pE20")
			player:EndEvent()
			quest:StartSequence(SEQ_015)
			local p = AFTER_RECEPTION
			bouncePlayer(player, p[1], p[2], p[3], p[4])
			return true
		end,
	},
	[SEQ_015] = { [HEDYN] = hedynFollowUp },
	[SEQ_020] = { [HEDYN] = hedynFollowUp },
	[SEQ_025] = { [NANANOBY] = nananobyTalk, other = mesaTalk },
	[SEQ_030] = { [NANANOBY] = nananobyTalk, other = mesaTalk },
	[SEQ_035] = {
		-- man30060 fades in only after a warp: the reward is paid on the Gridania street (onNotice).
		[HEDYN] = function(player, quest)
			delegateCompanion(player, quest, "pE60")
			player:EndEvent()
			local p = GRIDANIA_STREET
			kickAfterWarpNotice(player, p[1])
			warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
			return true
		end,
	},
	always = {
		[LOYAL_IXAL] = function(player, quest, npc) talkToShaman(player, quest, npc) end,
		[ABLE_BODIED_AMALJAA] = function(player, quest, npc) talkToShaman(player, quest, npc) end,
	},
	other = chatter,
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

-- SEQ_030 at the mesa: a shaman's first talk opens its Parley (the pointer the first time in a run); a
-- settled tribe's shaman has nothing more to parley about.
function talkToShaman(player, quest, npc)
	local shaman = SHAMANS[npc:GetActorClassId()]
	if shaman == nil or quest:GetSequence() ~= SEQ_030 then
		return
	end
	if getQuestFlag(quest, shaman.done) then
		player:SendGameMessage(GetWorldMaster(), TEXT_UNABLE_TO_PARLEY, 0x20, 0, 0, npc)
	elseif not getQuestFlag(quest, shaman.met) then
		player:SendGameMessage(GetWorldMaster(), TEXT_MAY_PARLEY, 0x20, quest:GetQuestId(), shaman.displayNameId)
		if not getQuestFlag(quest, FLAG_PARLEY_SHOWN) then
			player:SendGameMessage(GetWorldMaster(), TEXT_PARLEY_TARGET, 0x20, 0, shaman.displayNameId)
			setQuestFlagOn(quest, FLAG_PARLEY_SHOWN)
		end
		setQuestFlagOn(quest, shaman.met)
		parleyAfterSetup(player, quest, npc)
	else
		player:SendGameMessage(GetWorldMaster(), TEXT_PARLEY_TARGET, 0x20, 0, shaman.displayNameId)
	end
end

-- Parley (questflow.lua): open on a shaman once met, until its tribe is settled.
function canParley(player, quest, npc)
	local shaman = SHAMANS[npc:GetActorClassId()]
	if shaman == nil or quest:GetSequence() ~= SEQ_030 then
		return nil
	end
	if not getQuestFlag(quest, shaman.met) or getQuestFlag(quest, shaman.done) then
		return nil
	end
	return { row = shaman.row, displayNameId = shaman.displayNameId, topics = shaman.topics }
end

-- A won Parley settles the tribe; QuestDirectorMan30001 stands its fighters down.
function onParleyEnd(player, quest, npc, outcome)
	local shaman = SHAMANS[npc:GetActorClassId()]
	if shaman == nil or outcome ~= "won" or quest:GetSequence() ~= SEQ_030 then
		return
	end
	setQuestFlagOn(quest, shaman.done)
	player:SendGameMessage(GetWorldMaster(), TEXT_WILL_TO_FIGHT, 0x20, shaman.displayNameId, 2)
end

local function gridaniaEntrance(player, quest)
	if currentZoneId(player) ~= GRIDANIA_ZONE then
		player:EndEvent()
		return true
	end
	local sequence = quest:GetSequence()
	if sequence == SEQ_000 then
		delegateEvent(player, quest, "processEvent010")
		player:EndEvent()
		quest:StartSequence(SEQ_010)
	else
		player:EndEvent()
	end
	-- Nananoby waits at the door only in the report copy.
	warpToWard(player, sequence >= SEQ_035 and 2 or 1)
	return true
end

local function officeWestDoor(player)
	player:EndEvent()
	-- The ward hall's office floor is 1.5, the Sands' 1.2.
	bouncePlayer(player, -126.2, isInWard(player) and 1.5 or 1.2, -160, 1.6)
	return true
end

local function mesaTrigger(player, quest)
	if currentZoneId(player) == MESA_ZONE and not inPrivateArea(player) then
		startMesaDuty(player, quest)
		return true
	end
end

-- The door classes (ObjectEventDoor) have asked the move question already.
local push = {
	[SEQ_005] = {
		[OFFICE_WEST_DOOR] = function(player, quest)
			if not isLevelMet(player) or getQuestFlag(quest, FLAG_OFFICE_SCENE) then
				return officeWestDoor(player)
			end
			delegateEvent(player, quest, "processEvent000")
			player:EndEvent()
			setQuestFlagOn(quest, FLAG_OFFICE_SCENE)
			quest:UpdateENPCs()
			local p = AFTER_BRIEFING
			if inPrivateAreaOf(player, WAKING_SANDS_ZONE, "PrivateAreaMasterPast", SANDS_BRIEFING_PA) then
				warpTo(player, WAKING_SANDS_ZONE, "PrivateAreaMasterPast", SANDS_PA, p[1], p[2], p[3], p[4])
			else
				bouncePlayer(player, p[1], p[2], p[3], p[4])
			end
			return true
		end,
	},
	[SEQ_015] = {
		-- The companion's pearl glows on arrival; the journal turns to row 266 and the step holds at 15.
		[DRYBONE_TRIGGER] = function(player, quest)
			if getQuestCounter(quest, CNTR_DRYBONE_PEARL) == 5 then return end
			setQuestCounter(quest, CNTR_DRYBONE_PEARL, 5)
			quest:NewNpcLsMsg(NPCLS_PATH)
			quest:StartSequence(SEQ_015)
		end,
	},
	[SEQ_020] = { [MESA_TRIGGER] = mesaTrigger },
	[SEQ_025] = { [MESA_TRIGGER] = mesaTrigger },
	[SEQ_030] = { [MESA_TRIGGER] = mesaTrigger },
	always = {
		[ULDAH_ENTRANCE] = function(player, quest)
			player:EndEvent()
			local sequence = quest:GetSequence()
			if sequence == SEQ_ACCEPT then
				player:AcceptQuest(quest, true)
				sequence = quest:GetSequence()
			end
			local level = (sequence == SEQ_005 and not getQuestFlag(quest, FLAG_OFFICE_SCENE)) and SANDS_BRIEFING_PA or SANDS_PA
			local p = SANDS_ENTRY
			warpTo(player, WAKING_SANDS_ZONE, "PrivateAreaMasterPast", level, p[1], p[2], p[3], p[4])
			return true
		end,
		[GRIDANIA_ENTRANCE] = gridaniaEntrance,
		[SANDS_EXIT_DOOR] = function(player)
			player:EndEvent()
			local p = isInWard(player) and GRIDANIA_STREET or ULDAH_STREET
			warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
			return true
		end,
		[OFFICE_WEST_DOOR] = officeWestDoor,
		[OFFICE_EAST_DOOR] = function(player)
			player:EndEvent()
			local p = SOLAR_OUTSIDE
			bouncePlayer(player, p[1], p[2], p[3], p[4])
			return true
		end,
	},
}

function onPush(player, quest, npc)
	if runQuestHandler(push, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

-- The join ask, the cave-mouth scene the first time (its trailing false keeps the after-warp fade-in),
-- then the content. A retry resumes past what was already seen.
function startMesaDuty(player, quest)
	if delegateEvent(player, quest, "contentsJoinAskInBasaClass") ~= 1 then
		player:EndEvent()
		return
	end
	if not getQuestFlag(quest, FLAG_MESA_SCENE) then
		delegateCompanion(player, quest, "pE30", false)
		setQuestFlagOn(quest, FLAG_MESA_SCENE)
	end
	clearQuestFlag(quest, FLAG_AMALJAA_DONE)
	clearQuestFlag(quest, FLAG_IXAL_DONE)
	clearQuestFlag(quest, FLAG_AMALJAA_MET)
	clearQuestFlag(quest, FLAG_IXAL_MET)
	clearQuestFlag(quest, FLAG_PARLEY_SHOWN)
	local target = getQuestFlag(quest, FLAG_BRIEFING) and SEQ_030 or SEQ_025
	if quest:GetSequence() ~= target then
		quest:StartSequence(target)
	end
	local p = MESA_ARRIVAL
	startQuestContent(player, {
		zone = MESA_ZONE, content = "SimpleContentMan30001", director = "Quest/QuestDirectorMan30001",
		x = p[1], y = p[2], z = p[3], rot = p[4],
	})
end

-- Nananoby's briefing (man30040, in place), on landing or at his talk.
function playBriefing(player, quest)
	delegateCompanion(player, quest, "pE40")
	setQuestFlagOn(quest, FLAG_BRIEFING)
	player:EndEvent()
	quest:StartSequence(SEQ_030)
end

-- QuestDirectorMan30001 with its noticeEvent open: both tribes stood down. man30050 fades in after the
-- warp out; its trailing 10 is the client's cutReplay value.
function finishMesaDuty(player, quest, duty, area)
	delegateCompanion(player, quest, "pE50", 10)
	quest:StartSequence(SEQ_035)
	local p = MESA_EXIT
	leaveQuestContent(player, duty, area, { zone = MESA_ZONE, x = p[1], y = p[2], z = p[3], rot = p[4] })
end

-- A lost run: the journal goes back to the mesa; what was seen stays seen.
function failMesaDuty(player, quest, duty, area)
	if player:IsDead() or player:GetHP() <= 0 then
		player:SetHP(player:GetMaxHP())
	end
	quest:StartSequence(SEQ_020)
	local p = MESA_EXIT
	leaveQuestContent(player, duty, area, { zone = MESA_ZONE, x = p[1], y = p[2], z = p[3], rot = p[4] })
end

function onNotice(player, quest, target)
	if quest:GetSequence() == SEQ_035 and currentZoneId(player) == GRIDANIA_STREET[1] then
		dismissNowLoadingVeil(player, quest)
		if turnInQuest(player, quest, nil) then
			player:AddNpcLs(NPCLS_ASHCROWN)
			-- Forever Taken's accept is Hedyn's pES, a Peasants Ward step of its own.
			player:AddQuest(110016, true)
		end
		return
	end
	player:EndEvent()
	quest:UpdateENPCs()
end

-- Minfilia's call while held (the companion's name as text parameter 1; no advance); at Camp Drybone
-- the companion's own call, one line by pack position, which moves to 20.
function onNpcLS(player, quest, from, msgStep)
	local sequence = quest:GetSequence()
	if from == NPCLS_PATH then
		if sequence == SEQ_005 then
			player:SendGameMessageLocalizedDisplayName(quest, TEXT_MINFILIA_CALL, MESSAGE_TYPE_NPC_LINKSHELL,
				MINFILIA_DISPLAY_ID, player:GetSNpcNickname())
			quest:EndOfNpcLsMsgs()
		elseif (sequence == SEQ_015 or sequence == SEQ_020) and getQuestCounter(quest, CNTR_DRYBONE_PEARL) == 5 then
			player:SendGameMessageDisplayName(quest, TEXT_DRYBONE_BASE + companionPackPosition(player) - 1,
				MESSAGE_TYPE_NPC_LINKSHELL, player:GetSNpcNickname())
			quest:EndOfNpcLsMsgs()
			if sequence == SEQ_015 then
				quest:StartSequenceForNpcLs(SEQ_020)
			end
		end
	end
	player:EndEvent()
end

-- int2 swaps journal row 209 for 266 at 15 when it is 5; int6 is the companion's name.
function getJournalInformation(player, quest)
	return getQuestCounter(quest, CNTR_DRYBONE_PEARL), 0, 0, 0, 0, player:GetSNpcNickname()
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
