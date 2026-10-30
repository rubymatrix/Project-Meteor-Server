require("Global")
require("Quest")
require("QuestFlow")

local isInWard, workSoil, startAssembly, pressMinfilia, payReward

--[[
Forever Taken (Man304, quest 110016). Follows Toll of the Warden (Man300); level 34.

Toll of the Warden's turn-in hands this quest on silently; Hedyn's pES is the accept. The client's journal
tests 0, 5, 10-19, 20 and 25, so the held quest sits at 1 (no paragraph) and the accepted one moves to 0.
Seq 1:  Held. Zoxio's call on the Ashcrown pearl. Hedyn in the Peasants Ward (report copy, PA 2): pES
        (1 = accepted); the soil asks for one element, rolled then (1-6: fire, ice, wind, earth,
        lightning, water).
Seq 0:  The five Silvertear soil points in Mor Dhona: each asks to bury a crystal of the element
        (processEvent000_20), drains it for five minutes, then gives an Unaspected Crystal (journal int2).
        The fifth moves to 5.
Seq 5:  Hedyn takes the crystals (pE10); the pearl lights with his summons.
Seq 10: The Ul'dah market entrance into the Waking Sands (181 PA 12); the main hall stairs (push): pE20,
        the assembly (content SimpleContentMan30401, QuestDirectorEventMan30401).
Seq 20: The companion in the hall: pE30, out to the Ul'dah street.
Seq 25: The reward as the player lands (onNotice); Minfilia pays it in the Sands if that was lost.

The Peasants Ward is zone 161 when the server has it; until then its copies stand in 181 PA 13/14.
The five soil points share one class (m3g_man304_spot1..5).
Spawns and class fills: Data/sql/seed/seed_quest_man304_01.sql.
--]]

AFTER_WARP_NOTICE = true

local SEQ_000 = 0
local SEQ_001 = 1
local SEQ_005 = 5
local SEQ_010 = 10
local SEQ_020 = 20
local SEQ_025 = 25

local MINFILIA       = 1000843
local TATARU         = 1001046
local SERANELIEN     = 1001378
local SAHJA_ZHWAN    = 1001373
local NENEKANI       = 1001374
local GODFREY        = 1001375
local FENANA         = 1001376
local NONORU         = 1001377
local HEDYN          = 1001047
local SHANGA_MESHANGA = 1001048
local TROXIA         = 1001049
local DILUXIO        = 1001178
local LANXIO         = 1001179
local YOYOKA         = 1001380
local CLIAUX         = 1001381
local CENMIN         = 1001382
local MAUCOLYN       = 1001383
local MEMEZOFU       = 1001384
local NYXIA          = 1001385
local GONAXIA        = 1001386
local ZEXIA          = 1001387
local PANNIXIA       = 1001388
local DAXIA          = 1001389

local ULDAH_ENTRANCE    = 1090265
local GRIDANIA_ENTRANCE = 1090264 -- also the company offices' exits
local SANDS_EXIT_DOOR   = 1090160
local OFFICE_WEST_DOOR  = 1090161
local OFFICE_EAST_DOOR  = 1090162
local SOIL_POINT        = 1090212
local SANDS_HALL_TRIGGER = 1090186

local SNPC_BASE         = 1070000

local MRKR_GRIDANIA_ENTRANCE = 11001601
local MRKR_HEDYN             = 11001603
local MRKR_ULDAH_ENTRANCE    = 11001605
local MRKR_SANDS_MAIN_HALL   = 11001606
local MRKR_SOIL_BASE         = 11001606 -- + point (1-5)

local FLAG_BURIED_BASE    = 0  -- + point - 1 (0-4)
local FLAG_COLLECTED_BASE = 5  -- + point - 1 (5-9)

local CNTR_CRYSTALS  = 0
local CNTR_ELEMENT   = 1
-- Drain stamps, 5 bits per point: points 1-3 in A, 4-5 in B.
local CNTR_DRAIN_A   = 2
local CNTR_DRAIN_B   = 3

local ITEM_UNASPECTED_CRYSTAL = 11000096
local ELEMENT_CRYSTALS = { 1000009, 1000010, 1000011, 1000012, 1000013, 1000014 }
local DRAIN_SECONDS    = 300

local NPCLS_ASHCROWN   = 7
local ZOXIO_DISPLAY_ID = 2450004
local HEDYN_DISPLAY_ID = 1000392
local TEXT_ZOXIO_CALL  = 1
local TEXT_HEDYN_SUMMONS = 506
local TEXT_SOIL_WARM   = 489
local TEXT_NOT_DRAINED = 493
local TEXT_NO_CRYSTALS = 494
local QUEST_LEVEL      = 34

local WAKING_SANDS_ZONE  = 181
local PEASANTS_WARD_ZONE = 161
local WARD_FALLBACK_PA   = 12
local SANDS_ATRIUM_PA    = 12
local GRIDANIA_ZONE      = 206
local MOR_DHONA_ZONE     = 190

local SANDS_ENTRY     = { -205.25, 0, -160, 1.55 }
local WARD_ENTRY      = { -200.970, 0.015, -160.019, 1.575 }
local SOLAR_OUTSIDE   = { -142.75, 1, -160, -1.6 }
local ULDAH_STREET    = { 175, -216.52, 190, 30.5, 2.32 }
local GRIDANIA_STREET = { 206, -180, 22, -1408, 1.5 }
local HALL_ARRIVAL    = { -191.581, -2.0, -184.934, 1.571 }

local function isLevelMet(player)
	return player:GetLevel() >= QUEST_LEVEL
end

local function isInWardArea(player)
	return isInWard(player)
end

local function isInSands(player)
	return currentZoneId(player) == WAKING_SANDS_ZONE and not isInWard(player)
end

local function isInUldah(player)
	return currentZoneId(player) == 175
end

local function isInSandsAtrium(player)
	return inPrivateAreaOf(player, WAKING_SANDS_ZONE, "PrivateAreaMasterPast", SANDS_ATRIUM_PA)
end

local function isUncollected(point)
	return function(player, quest, data)
		return not data:GetFlag(FLAG_COLLECTED_BASE + point - 1)
	end
end

local function isUnburied(point)
	return function(player, quest, data)
		return not data:GetFlag(FLAG_BURIED_BASE + point - 1) and not data:GetFlag(FLAG_COLLECTED_BASE + point - 1)
	end
end

local function anyUncollected(player, quest, data)
	for point = 1, 5 do
		if not data:GetFlag(FLAG_COLLECTED_BASE + point - 1) then
			return true
		end
	end
	return false
end

-- Shanga Meshanga and Troxia have no line of their own: they stand silent.
local WARD_CROWD = { SHANGA_MESHANGA, TROXIA, DILUXIO, LANXIO, NYXIA, GONAXIA, ZEXIA, PANNIXIA, DAXIA, MEMEZOFU, YOYOKA, CENMIN, CLIAUX, MAUCOLYN }
local DELIVERED_CROWD = { HEDYN, MEMEZOFU, CENMIN, CLIAUX, TATARU, SERANELIEN, SAHJA_ZHWAN, NENEKANI, GODFREY, FENANA, NONORU }

local function door(classId)
	return { classId, QFLAG_OFF, talk = false, push = true }
end

local DOORS = { door(SANDS_EXIT_DOOR), door(OFFICE_WEST_DOOR), door(OFFICE_EAST_DOOR) }
local WARD_ENTRANCE = { GRIDANIA_ENTRANCE, QFLAG_OFF, talk = false, push = true }
local SANDS_ENTRANCE = { ULDAH_ENTRANCE, QFLAG_OFF, talk = false, push = isInUldah }

local function soilMarkers()
	local markers = {}
	for point = 1, 5 do
		markers[#markers + 1] = { MRKR_SOIL_BASE + point, when = isUnburied(point) }
	end
	return markers
end

local PHASES = {
	-- Held: below level 34 the quest claims no talk and marks nothing.
	[SEQ_001] = {
		enpcs = {
			{ HEDYN, QFLAG_TALK, when = isLevelMet, talk = isLevelMet }, DOORS[1], DOORS[2], DOORS[3],
			WARD_ENTRANCE, { crowd = WARD_CROWD },
		},
		markers = {
			{ MRKR_GRIDANIA_ENTRANCE, when = function(player) return isLevelMet(player) and not isInWardArea(player); end },
			{ MRKR_HEDYN, when = function(player) return isLevelMet(player) and isInWardArea(player); end },
		},
	},
	[SEQ_000] = {
		enpcs = {
			HEDYN, DOORS[1], DOORS[2], DOORS[3], WARD_ENTRANCE, { crowd = WARD_CROWD },
			{ SOIL_POINT, QFLAG_PUSH, when = anyUncollected, talk = false, push = true, spawn = true },
		},
		markers = soilMarkers(),
	},
	[SEQ_005] = {
		enpcs = { { HEDYN, QFLAG_TALK }, DOORS[1], DOORS[2], DOORS[3], WARD_ENTRANCE },
		markers = {
			{ MRKR_HEDYN, when = isInWardArea },
			{ MRKR_GRIDANIA_ENTRANCE, when = function(player) return not isInWardArea(player); end },
		},
	},
	[SEQ_010] = {
		enpcs = {
			SANDS_ENTRANCE, WARD_ENTRANCE, { SANDS_HALL_TRIGGER, QFLAG_PUSH, talk = false, push = true },
			DOORS[1], DOORS[2], DOORS[3], { crowd = DELIVERED_CROWD },
		},
		markers = {
			{ MRKR_ULDAH_ENTRANCE, when = function(player) return not isInSands(player); end },
			{ MRKR_SANDS_MAIN_HALL, when = isInSands },
		},
	},
	-- A relog drops the content area: the archway and the hall relaunch it. The companion's row is set
	-- in onStateChange.
	[SEQ_020] = {
		enpcs = { SANDS_ENTRANCE, { SANDS_HALL_TRIGGER, QFLAG_PUSH, talk = false, push = true }, DOORS[1], DOORS[2], DOORS[3] },
	},
	-- A lost notice leaves the reward to Minfilia in the atrium copy.
	[SEQ_025] = {
		enpcs = { SANDS_ENTRANCE, { MINFILIA, QFLAG_REWARD, when = isInSandsAtrium }, DOORS[1], DOORS[2], DOORS[3] },
	},
}

local WARD_OFFER_LINES = {
	[DILUXIO] = "processEvent000_2", [LANXIO] = "processEvent000_3", [NYXIA] = "processEvent000_4",
	[GONAXIA] = "processEvent000_5", [ZEXIA] = "processEvent000_6", [PANNIXIA] = "processEvent000_7",
	[DAXIA] = "processEvent000_8", [MEMEZOFU] = "processEvent000_9", [YOYOKA] = "processEvent000_10",
	[CENMIN] = "processEvent000_11", [CLIAUX] = "processEvent000_12", [MAUCOLYN] = "processEvent000_13",
}

-- Memezofu (001_3) and Cliaux (001_6) name the element the soil wants (onTalk passes it).
local CHATTER = {
	[SEQ_001] = WARD_OFFER_LINES,
	[SEQ_000] = {
		[HEDYN] = "processEvent001_2", [MEMEZOFU] = "processEvent001_3", [YOYOKA] = "processEvent001_4",
		[CENMIN] = "processEvent001_5", [CLIAUX] = "processEvent001_6", [MAUCOLYN] = "processEvent000_13",
		[DILUXIO] = "processEvent000_2", [LANXIO] = "processEvent000_3", [NYXIA] = "processEvent000_4",
		[GONAXIA] = "processEvent000_5", [ZEXIA] = "processEvent000_6", [PANNIXIA] = "processEvent000_7",
		[DAXIA] = "processEvent000_8",
	},
	[SEQ_010] = {
		[HEDYN] = "processEvent001_2", [MEMEZOFU] = "processEvent001_3", [CENMIN] = "processEvent005_2",
		[CLIAUX] = "processEvent005_1", [TATARU] = "processEvent010_2", [SERANELIEN] = "processEvent010_3",
		[SAHJA_ZHWAN] = "processEvent010_4", [NENEKANI] = "processEvent010_5", [GODFREY] = "processEvent010_6",
		[FENANA] = "processEvent010_7", [NONORU] = "processEvent010_8",
	},
}

local ELEMENT_TALKS = { processEvent001_3 = true, processEvent001_6 = true }

local function delegateCompanion(player, quest, eventName)
	return delegateEvent(player, quest, eventName, player:GetSNpcNickname(), player:GetSNpcSkin(),
		player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown())
end

local function companionClass(player)
	return SNPC_BASE + player:GetSNpcSkin()
end

local function getElement(quest)
	local element = getQuestCounter(quest, CNTR_ELEMENT)
	if element < 1 or element > 6 then
		return 1
	end
	return element
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

function onStart(player, quest)
	quest:StartSequence(SEQ_001)
	-- Zoxio's call arms once per grant and never advances.
	quest:NewNpcLsMsg(NPCLS_ASHCROWN)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		-- A character who finished Toll of the Warden without the hand-on: the Gridania archway.
		quest:SetENpc(GRIDANIA_ENTRANCE, QFLAG_PUSH, false, true)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
	if sequence == SEQ_020 then
		quest:SetENpc(companionClass(player), QFLAG_TALK)
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if sequence == SEQ_001 and not isLevelMet(player) then
		-- Below level 34 Forever Taken answers nothing.
	elseif sequence == SEQ_001 and classId == HEDYN then
		-- The offer window plays inside man30400 and pES returns its answer.
		local answer = delegateCompanion(player, quest, "pES")
		if answer == 1 or answer == true then
			player:EndEvent()
			if getQuestCounter(quest, CNTR_ELEMENT) == 0 then
				-- Each character gets its own element.
				setQuestCounter(quest, CNTR_ELEMENT, math.random(1, 6))
			end
			quest:StartSequence(SEQ_000)
			return
		end
	elseif sequence == SEQ_005 and classId == HEDYN then
		-- pE10 says its line and plays man30410 in place; the pearl glows before the journal moves.
		delegateCompanion(player, quest, "pE10")
		player:EndEvent()
		quest:NewNpcLsMsg(NPCLS_ASHCROWN)
		quest:StartSequence(SEQ_010)
		return
	elseif sequence == SEQ_020 and classId == companionClass(player) then
		pressMinfilia(player, quest)
		return
	elseif sequence == SEQ_025 and classId == MINFILIA then
		payReward(player, quest)
		return
	else
		local lines = CHATTER[sequence]
		local eventName = lines and lines[classId]
		if eventName ~= nil and ELEMENT_TALKS[eventName] then
			delegateEvent(player, quest, eventName, getElement(quest))
		else
			delegateChatter(player, quest, CHATTER, sequence, classId)
		end
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	-- The door classes (ObjectEventDoor) have asked the move question already.
	if classId == ULDAH_ENTRANCE then
		player:EndEvent()
		local p = SANDS_ENTRY
		warpTo(player, WAKING_SANDS_ZONE, "PrivateAreaMasterPast", SANDS_ATRIUM_PA, p[1], p[2], p[3], p[4])
		return
	elseif classId == GRIDANIA_ENTRANCE then
		player:EndEvent()
		if currentZoneId(player) ~= GRIDANIA_ZONE then
			return
		end
		if sequence == SEQ_ACCEPT then
			player:AcceptQuest(quest, true)
		end
		local zone, level = wardArea(2)
		local p = WARD_ENTRY
		warpTo(player, zone, "PrivateAreaMasterPast", level, p[1], p[2], p[3], p[4])
		return
	elseif classId == SANDS_EXIT_DOOR then
		player:EndEvent()
		local p = isInWard(player) and GRIDANIA_STREET or ULDAH_STREET
		warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
		return
	elseif classId == OFFICE_WEST_DOOR then
		player:EndEvent()
		-- The ward hall's office floor is 1.5, the Sands' 1.2.
		bouncePlayer(player, -126.2, isInWard(player) and 1.5 or 1.2, -160, 1.6)
		return
	elseif classId == OFFICE_EAST_DOOR then
		player:EndEvent()
		local p = SOLAR_OUTSIDE
		bouncePlayer(player, p[1], p[2], p[3], p[4])
		return
	elseif classId == SOIL_POINT and sequence == SEQ_000 and currentZoneId(player) == MOR_DHONA_ZONE then
		local point = tonumber(string.match(npcName(npc), "(%d+)$"))
		if point ~= nil and point >= 1 and point <= 5 then
			workSoil(player, quest, point)
			return
		end
	elseif classId == SANDS_HALL_TRIGGER and (sequence == SEQ_010 or sequence == SEQ_020) then
		startAssembly(player, quest)
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

-- Drain stamps: minutes after the quest's time stamp, 5 bits per point (rounded up so a point never
-- drains early). The stamp moves to now whenever no other point is draining.
local function drainField(point)
	if point <= 3 then
		return CNTR_DRAIN_A, (point - 1) * 5
	end
	return CNTR_DRAIN_B, (point - 4) * 5
end

local function drainMinutes(quest, point)
	local counter, shift = drainField(point)
	return math.floor(getQuestCounter(quest, counter) / (2 ^ shift)) % 32
end

local function setDrainMinutes(quest, point, minutes)
	local counter, shift = drainField(point)
	local value = getQuestCounter(quest, counter)
	local old = math.floor(value / (2 ^ shift)) % 32
	setQuestCounter(quest, counter, value + (minutes - old) * (2 ^ shift))
end

local function anyDraining(quest)
	for point = 1, 5 do
		if getQuestFlag(quest, FLAG_BURIED_BASE + point - 1) then
			return true
		end
	end
	return false
end

local function stampDrain(quest, point)
	local data = quest:GetData()
	if not anyDraining(quest) then
		data:SetTimeNow()
		data:Save()
	end
	local minutes = math.min(31, math.ceil((os.time() - data:GetTime()) / 60))
	setDrainMinutes(quest, point, minutes)
end

local function isDrained(quest, point)
	return os.time() >= quest:GetData():GetTime() + drainMinutes(quest, point) * 60 + DRAIN_SECONDS
end

function workSoil(player, quest, point)
	if getQuestFlag(quest, FLAG_COLLECTED_BASE + point - 1) then
		player:EndEvent()
		return
	end

	if not getQuestFlag(quest, FLAG_BURIED_BASE + point - 1) then
		-- The client never says row 489 itself, so the server prints it as a system line.
		player:SendGameMessage(quest, TEXT_SOIL_WARM, 0x20)
		if delegateEvent(player, quest, "processEvent000_20") ~= 1 then
			player:EndEvent()
			return
		end
		local element = getElement(quest)
		local crystal = ELEMENT_CRYSTALS[element]
		if not player:HasItem(crystal) then
			-- processEvent000_22 calls a worldMaster tell the client lacks, so the server prints row 494.
			player:SendGameMessage(quest, TEXT_NO_CRYSTALS, 0x20, element)
			player:EndEvent()
			return
		end
		player:RemoveItem(crystal, 1)
		stampDrain(quest, point)
		setQuestFlagOn(quest, FLAG_BURIED_BASE + point - 1)
		player:EndEvent()
		quest:UpdateENPCs()
		return
	end

	if not isDrained(quest, point) then
		player:SendGameMessage(quest, TEXT_NOT_DRAINED, 0x20)
		player:EndEvent()
		return
	end

	player:SendGameMessage(GetWorldMaster(), TEXT_KEY_ITEM_OBTAINED, 0x20, ITEM_UNASPECTED_CRYSTAL)
	local collected = getQuestCounter(quest, CNTR_CRYSTALS) + 1
	setQuestCounter(quest, CNTR_CRYSTALS, collected)
	setQuestFlagOn(quest, FLAG_COLLECTED_BASE + point - 1)
	clearQuestFlag(quest, FLAG_BURIED_BASE + point - 1)
	if collected < 5 then
		player:EndEvent()
		quest:UpdateENPCs()
		return
	end
	-- 000_21 is the client's empty beat for the fifth.
	delegateEvent(player, quest, "processEvent000_21")
	player:EndEvent()
	quest:StartSequence(SEQ_005)
end

-- man30420 fades in after a warp, and the content launch is that warp. A relaunch skips the scene.
function startAssembly(player, quest)
	if quest:GetSequence() == SEQ_010 then
		delegateCompanion(player, quest, "pE20")
		quest:StartSequence(SEQ_020)
	end
	local p = HALL_ARRIVAL
	startQuestContent(player, {
		zone = WAKING_SANDS_ZONE, content = "SimpleContentMan30401", director = "Quest/QuestDirectorEventMan30401",
		x = p[1], y = p[2], z = p[3], rot = p[4],
	})
end

-- man30430 fades in after the warp out to the Ul'dah street; the reward is paid as the
-- player lands.
function pressMinfilia(player, quest)
	delegateCompanion(player, quest, "pE30")
	quest:StartSequence(SEQ_025)
	local area = player.CurrentArea
	player:SendGameMessage(GetWorldMaster(), TEXT_UNBOUND_FROM_DUTY, 0x20)
	player:EndEvent()
	pcall(function() area:ContentFinished() end)
	local p = ULDAH_STREET
	kickAfterWarpNotice(player, p[1])
	warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
end

function payReward(player, quest)
	-- An unread summons must not outlive the quest.
	if quest:GetData():GetNpcLsFrom() ~= 0 then
		quest:EndOfNpcLsMsgs()
	end
	if turnInQuest(player, quest, nil) then
		-- Lord Errant's offer plays at the Gold Court; its companion pearl rides this hand-on.
		player:AddQuest(110017, true)
	end
end

function onNotice(player, quest, target)
	if quest:GetSequence() == SEQ_025 and currentZoneId(player) == ULDAH_STREET[1] then
		dismissNowLoadingVeil(player, quest)
		payReward(player, quest)
		return
	end
	player:EndEvent()
	quest:UpdateENPCs()
end

-- Every read ends the glow: Zoxio's call until the hand-over, then Hedyn's summons. The client fills the
-- name itself, so neither row takes an argument.
function onNpcLS(player, quest, from, msgStep)
	if from == NPCLS_ASHCROWN then
		if quest:GetSequence() < SEQ_010 then
			player:SendGameMessageLocalizedDisplayName(quest, TEXT_ZOXIO_CALL, MESSAGE_TYPE_NPC_LINKSHELL, ZOXIO_DISPLAY_ID)
		else
			player:SendGameMessageLocalizedDisplayName(quest, TEXT_HEDYN_SUMMONS, MESSAGE_TYPE_NPC_LINKSHELL, HEDYN_DISPLAY_ID)
		end
		quest:EndOfNpcLsMsgs()
	end
	player:EndEvent()
	quest:UpdateENPCs()
end

-- int2: the Unaspected Crystals (the item line below 10); int6: the companion's name.
function getJournalInformation(player, quest)
	return getQuestCounter(quest, CNTR_CRYSTALS), 0, 0, 0, 0, player:GetSNpcNickname()
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
