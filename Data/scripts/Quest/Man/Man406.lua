require("Global")
require("Quest")
require("QuestFlow")

--[[
Futures Perfect (Man406, quest 110019). Follows Of Men They Sing (Man402); level 46.

Seq 1:  held: Of Men They Sing's payout grants the quest silently (player:AddQuest) and Tataru calls on
        the Path of the Twelve pearl. The journal has no paragraph for 1. The Waking Sands office's west
        door (the Hall of the First Step) offers it: pES (man40600 mode 2; 1 = join, fade after warp) -> 0
        and into the Hall content. A decline, or a push below level 46, walks into the solar. A character
        who finished Of Men They Sing without the hand-on gets the same offer at Seq 65535.
Seq 0:  the Hall (content SimpleContentMan40601, QuestDirectorEventMan40601): six Resistance members, each
        with a "!" until heard (processEvent010_1..6); the sixth closes into pE10 (man40610) -> 5.
Seq 5:  the captain's farewell: pE15 (man40615, after warp) -> 10, out to the office hall.
Seq 10: Camp Revenant's Toll (Mor Dhona): the push asks, the first time plays processEvent020 (man40620,
        a3 false = after warp) -> 15 and the field duty.
Seq 15: the field duty (content SimpleContentMan40602, QuestDirectorMan40601): track three imperials to
        the juggernaut, the ambush (processEvent025, HQ MAN40625), outlast the Magitek Cannon and see the
        centurion withdraw. Win: pE30 (man40630 + HQ man40635 + man40645) -> 20 and the cave. A loss
        keeps 15 and the camp push relaunches the duty without the scene.
Seq 20: the cave of the children (content SimpleContentMan40603): the children's lines (processEvent045_x);
        the way out asks, pE50 (man40650) -> 25 and the camp aftermath (content SimpleContentMan40604,
        QuestDirectorEventMan40602), which ends when the player walks out of it.
Seq 25: Tataru: pE60 (man40660, after warp) out to an Ul'dah street, where the after-warp notice pays the
        reward window and completes. The 1.23b story ends here.

Journal phases 0, 5, 10, 15, 20, 25; int3 = the rescuer by starting city (the player's initial town).
Data: Data/sql/seed/seed_quest_man406_01.sql (+ m3g_man406_toll in seed_msq_gridania_10_man3xx.sql).
--]]

local westDoor, eastDoor, captainFarewell, enterAtRevenantsToll, leaveCave, reportToTataru

local SEQ_000 = 0
local SEQ_HELD = 1
local SEQ_005 = 5
local SEQ_010 = 10
SEQ_015 = 15
local SEQ_020 = 20
local SEQ_025 = 25

local TATARU                 = 1001046
local MINFILIA               = 1000843
local SERANELIEN             = 1001378
local SAHJA_ZHWAN            = 1001373
local NENEKANI               = 1001374
local GODFREY                = 1001375
local FENANA                 = 1001376
local NONORU                 = 1001377
local CAPTAIN                = 1000477
local BRUTISH_MEMBER         = 1000478
local STRAPPING_MEMBER       = 1000479
local DISPASSIONATE_MEMBER   = 1000480
local HARDENED_WARRIOR       = 1000481
local CAREWORN_WARRIOR       = 1000483
local SHUDDERING_CHILD       = 1000957
local COWERING_CHILD         = 1000958
local SHIVERING_CHILD        = 1000959
local CRIED_OUT_CHILD        = 1000960
local TERRIFIED_CHILD        = 1000961
local TOLL_TRIGGER           = 1090213
local CAVE_EXIT_TRIGGER      = 1090214
local SNPC_BASE              = 1070000

local MARKET_ENTRANCE_ULDAH  = 1090265
local SANDS_EXIT_DOOR        = 1090160
local OFFICE_WEST_DOOR       = 1090161
local OFFICE_EAST_DOOR       = 1090162

local MRKR_MARKET_ENTRANCE   = 11001901
local MRKR_HALL              = 11001902
local MRKR_REVENANTS_TOLL    = 11001903
local MRKR_ECHO_CAVE         = 11001904
local MRKR_TATARU_REPORT     = 11001905
local MRKR_BATTLEFIELD       = 11001906

local FLAG_CAPTAIN_BRIEFED       = 0
local FLAG_BRUTISH_BRIEFED       = 1
local FLAG_STRAPPING_BRIEFED     = 2
local FLAG_CAREWORN_BRIEFED      = 3
local FLAG_DISPASSIONATE_BRIEFED = 4
local FLAG_HARDENED_BRIEFED      = 5
local FLAG_CAMP_SCENE_SEEN       = 6
FLAG_AMBUSH_SEEN           = 7
local FLAG_REWARD_SCENE_SEEN     = 8

local TEXT_ENTERED_INSTANCE    = 34108
-- worldMaster 51035 reads xtx/npcLsBfrxtx: parameter 1 picks the row, 7 is the row's name string.
local TEXT_PEARL_BEFORE_QUEST  = 51035
local PEARL_ROW_TATARU         = 38
local DISPLAY_TATARU           = 1500054
local NPCLS_PATH_OF_THE_TWELVE = 6

local QUEST_LEVEL = 46

local SANDS_ZONE = 181
local FIELD_ZONE = 190

-- Points: { zone, x, y, z, rot }
local HALL_LANDING      = { 181, -126.2, 1.2, -160.0, 1.6 }
local OFFICE_HALL       = { 181, -142.75, 1.0, -160.0, -1.6 }
local FIELD_LANDING     = { 190, -218.47, 18.542, -666.627, -2.817 }
local CAVE_LANDING      = { 190, 265.47, 56.408, -799.867, -1.654 }
AFTERMATH_LANDING = { 190, -205.201, 18.645, -680.202, 2.266 }
local ULDAH_STREET      = { 175, -216.52, 190.0, 30.5, 2.32 }
local SANDS_ENTRY       = { 181, -205.25, 0.0, -160.0, 1.55 }

local AFTER_WARP_NOTICE = true

local function companionClass(player)
	return SNPC_BASE + player:GetSNpcSkin()
end

-- The companion tuple the pE functions take as a3..a7.
local function companionEvent(player, quest, eventName, ...)
	return delegateEvent(player, quest, eventName, player:GetSNpcNickname(), player:GetSNpcSkin(),
		player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown(), ...)
end

-- The briefing: who says what, and the flag his first talk sets.
local BRIEFINGS = {
	[CAPTAIN]              = { flag = FLAG_CAPTAIN_BRIEFED,       event = "processEvent010_1" },
	[BRUTISH_MEMBER]       = { flag = FLAG_BRUTISH_BRIEFED,       event = "processEvent010_2" },
	[STRAPPING_MEMBER]     = { flag = FLAG_STRAPPING_BRIEFED,     event = "processEvent010_3" },
	[CAREWORN_WARRIOR]     = { flag = FLAG_CAREWORN_BRIEFED,      event = "processEvent010_4" },
	[DISPASSIONATE_MEMBER] = { flag = FLAG_DISPASSIONATE_BRIEFED, event = "processEvent010_5" },
	[HARDENED_WARRIOR]     = { flag = FLAG_HARDENED_BRIEFED,      event = "processEvent010_6" },
}

local function inSands(player)
	return currentZoneId(player) == SANDS_ZONE
end

local function outOfSands(player)
	return currentZoneId(player) ~= SANDS_ZONE
end

local function inContent(player)
	return inPrivateArea(player)
end

local function outOfContent(player)
	return not inPrivateArea(player)
end

-- The camp trigger spawns only in the public zone; the duty's copies share the zone id.
local function atRevenantsToll(player)
	return currentZoneId(player) == FIELD_ZONE and not inPrivateArea(player)
end

local function inField(player)
	return inPrivateAreaOf(player, FIELD_ZONE, "SimpleContentMan40602")
end

local function inCave(player)
	return inPrivateAreaOf(player, FIELD_ZONE, "SimpleContentMan40603")
end

local function notBriefed(flag)
	return function(player, quest, data)
		return not data:GetFlag(flag)
	end
end

local function isFullyBriefed(data)
	for _, b in pairs(BRIEFINGS) do
		if not data:GetFlag(b.flag) then
			return false
		end
	end
	return true
end

local function push(classId, icon)
	return { classId, icon or QFLAG_OFF, talk = false, push = true }
end

local SANDS_CROWD = { SERANELIEN, SAHJA_ZHWAN, NENEKANI, GODFREY, FENANA, NONORU }

local function sandsDoors(list)
	for _, e in ipairs({ push(MARKET_ENTRANCE_ULDAH), push(SANDS_EXIT_DOOR), push(OFFICE_WEST_DOOR), push(OFFICE_EAST_DOOR) }) do
		list[#list + 1] = e
	end
	return list
end

local function hallEnpcs(briefing)
	local list = sandsDoors({ TATARU, MINFILIA, { crowd = SANDS_CROWD } })
	for classId, b in pairs(BRIEFINGS) do
		if briefing then
			list[#list + 1] = { classId, QFLAG_TALK, when = notBriefed(b.flag) }
		elseif classId == CAPTAIN then
			list[#list + 1] = { CAPTAIN, QFLAG_TALK }
		else
			list[#list + 1] = classId
		end
	end
	return list
end

local function lobbyEnpcs(extra)
	local list = sandsDoors({ TATARU, SERANELIEN, MINFILIA, SAHJA_ZHWAN,
		{ TOLL_TRIGGER, QFLAG_PUSH, talk = false, push = atRevenantsToll, spawn = true } })
	if extra ~= nil then
		list[#list + 1] = extra
	end
	return list
end

local function isLevelMet(player)
	return player:GetLevel() >= QUEST_LEVEL
end

local function isHeldInSands(player)
	return isLevelMet(player) and inSands(player)
end

local function isHeldOutOfSands(player)
	return isLevelMet(player) and outOfSands(player)
end

-- The offer on an old character: no journal yet, so no markers. Below level it is not offered at all.
local OFFER_PHASE = { [SEQ_ACCEPT] = { enpcs = sandsDoors({ TATARU, { crowd = SANDS_CROWD } }) } }

local PHASES = {
	-- Held: the west door stays armed below level, where it walks into the solar as the door would.
	[SEQ_HELD] = {
		enpcs = sandsDoors({ TATARU, { crowd = SANDS_CROWD } }),
		markers = { { MRKR_HALL, when = isHeldInSands }, { MRKR_MARKET_ENTRANCE, when = isHeldOutOfSands } },
	},
	[SEQ_000] = { enpcs = hallEnpcs(true), markers = { MRKR_HALL } },
	[SEQ_005] = { enpcs = hallEnpcs(false), markers = { MRKR_HALL } },
	[SEQ_010] = { enpcs = lobbyEnpcs(), markers = { MRKR_REVENANTS_TOLL } },
	[SEQ_015] = {
		enpcs = lobbyEnpcs(),
		markers = { { MRKR_BATTLEFIELD, when = inField }, { MRKR_REVENANTS_TOLL, when = outOfContent } },
	},
	[SEQ_020] = {
		enpcs = lobbyEnpcs({ CAVE_EXIT_TRIGGER, QFLAG_OFF, talk = false, push = inCave }),
		markers = { { MRKR_ECHO_CAVE, when = inCave }, { MRKR_REVENANTS_TOLL, when = outOfContent } },
	},
	[SEQ_025] = {
		enpcs = sandsDoors({ { TATARU, QFLAG_REWARD }, { crowd = SANDS_CROWD } }),
		markers = { { MRKR_TATARU_REPORT, when = inSands }, { MRKR_MARKET_ENTRANCE, when = outOfSands } },
	},
}

-- The Sands while the quest waits (rows 240-251), during the briefing (Tataru rows 370/371) and after the
-- report scene's return (rows 271-281).
local HOLDER_CROWD = {
	[SERANELIEN] = "processEvent000_2", [SAHJA_ZHWAN] = "processEvent000_3", [NENEKANI] = "processEvent000_4",
	[GODFREY] = "processEvent000_5", [FENANA] = "processEvent000_6", [NONORU] = "processEvent000_7",
}
local function withLine(lines, classId, eventName)
	local t = {}
	for k, v in pairs(lines) do t[k] = v end
	t[classId] = eventName
	return t
end
local OFFER_CHATTER = { [SEQ_ACCEPT] = withLine(HOLDER_CROWD, TATARU, "processEvent000_1") }
local CHATTER = {
	[SEQ_HELD] = OFFER_CHATTER[SEQ_ACCEPT],
	[SEQ_000] = withLine(HOLDER_CROWD, TATARU, "processEvent010_8"),
	[SEQ_005] = withLine(HOLDER_CROWD, TATARU, "processEvent010_8"),
	[SEQ_010] = { [SAHJA_ZHWAN] = "processEvent000_3" },
	[SEQ_015] = { [SAHJA_ZHWAN] = "processEvent000_3" },
	[SEQ_020] = {
		[SAHJA_ZHWAN] = "processEvent000_3",
		[SHUDDERING_CHILD] = "processEvent045_1", [COWERING_CHILD] = "processEvent045_2",
		[SHIVERING_CHILD] = "processEvent045_3", [CRIED_OUT_CHILD] = "processEvent045_4",
		[TERRIFIED_CHILD] = "processEvent045_5",
	},
	[SEQ_025] = {
		[SAHJA_ZHWAN] = "processEvent060_2", [NENEKANI] = "processEvent060_3", [GODFREY] = "processEvent060_4",
		[FENANA] = "processEvent060_5", [NONORU] = "processEvent060_6",
	},
}

-- The lobby after man40615 and the return: these take the companion tuple.
local LOBBY_COMPANION_LINES = { [TATARU] = "pE17", [SERANELIEN] = "pE18", [MINFILIA] = "pE16" }
local COMPANION_CHATTER = {
	[SEQ_010] = LOBBY_COMPANION_LINES,
	[SEQ_015] = LOBBY_COMPANION_LINES,
	[SEQ_020] = LOBBY_COMPANION_LINES,
	[SEQ_025] = { [SERANELIEN] = "pE61" },
}

-- Granted (Of Men They Sing's hand-on) or accepted on an old character's offer: held either way; the
-- offer moves a held quest to 0. Tataru's call arms once per grant.
function onStart(player, quest)
	quest:StartSequenceForNpcLs(SEQ_HELD)
	callNpcLs(quest, NPCLS_PATH_OF_THE_TWELVE)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		applyPhase(player, quest, OFFER_PHASE, sequence)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
	if sequence == SEQ_000 or sequence == SEQ_005 or sequence == SEQ_025 then
		-- The Hall and the aftermath companion; her class depends on the player.
		quest:SetENpc(companionClass(player))
	elseif sequence == SEQ_020 then
		quest:SetENpc(SHUDDERING_CHILD)
		quest:SetENpc(COWERING_CHILD)
		quest:SetENpc(SHIVERING_CHILD)
		quest:SetENpc(CRIED_OUT_CHILD)
		quest:SetENpc(TERRIFIED_CHILD)
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if sequence == SEQ_ACCEPT then
		delegateChatter(player, quest, OFFER_CHATTER, sequence, classId)
	elseif (sequence == SEQ_000 or sequence == SEQ_005) and inPrivateArea(player) and BRIEFINGS[classId] ~= nil then
		if sequence == SEQ_005 and classId == CAPTAIN then
			captainFarewell(player, quest)
			return
		end
		local b = BRIEFINGS[classId]
		delegateEvent(player, quest, b.event)
		setQuestFlagOn(quest, b.flag)
		if sequence == SEQ_000 and isFullyBriefed(quest:GetData()) then
			-- The sixth distinct talk closes into man40610 in the same event.
			companionEvent(player, quest, "pE10")
			quest:StartSequence(SEQ_005)
		end
	elseif (sequence == SEQ_000 or sequence == SEQ_005) and inPrivateArea(player) and classId == MINFILIA then
		delegateEvent(player, quest, (sequence == SEQ_000) and "processEvent010_7" or "processEvent010_9")
	elseif (sequence == SEQ_000 or sequence == SEQ_005) and classId == companionClass(player) then
		companionEvent(player, quest, "pE01")
	elseif sequence == SEQ_025 and classId == companionClass(player) then
		companionEvent(player, quest, "pE52")
	elseif sequence == SEQ_025 and classId == TATARU then
		if not getQuestFlag(quest, FLAG_REWARD_SCENE_SEEN) then
			reportToTataru(player, quest)
		else
			-- The after-warp notice never came: pay here.
			turnInQuest(player, quest)
		end
		return
	else
		local lines = COMPANION_CHATTER[sequence]
		if lines ~= nil and lines[classId] ~= nil then
			companionEvent(player, quest, lines[classId])
		else
			delegateChatter(player, quest, CHATTER, sequence, classId)
		end
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

-- The door classes (ObjectEventDoor) have asked the move question before this runs.
function onPush(player, quest, npc, eventName)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if classId == OFFICE_WEST_DOOR then
		westDoor(player, quest, sequence)
		return
	elseif classId == OFFICE_EAST_DOOR then
		eastDoor(player, quest)
		return
	elseif classId == MARKET_ENTRANCE_ULDAH or classId == SANDS_EXIT_DOOR then
		player:EndEvent()
		local p = (classId == MARKET_ENTRANCE_ULDAH) and SANDS_ENTRY or ULDAH_STREET
		warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
		return
	elseif sequence ~= SEQ_ACCEPT and classId == TOLL_TRIGGER and atRevenantsToll(player)
			and (sequence == SEQ_010 or sequence == SEQ_015 or sequence == SEQ_020) then
		enterAtRevenantsToll(player, quest, sequence)
		return
	elseif sequence == SEQ_020 and classId == CAVE_EXIT_TRIGGER and inCave(player) then
		leaveCave(player, quest)
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

local function startHall(player)
	local p = HALL_LANDING
	startQuestContent(player, { zone = p[1], content = "SimpleContentMan40601", director = "Quest/QuestDirectorEventMan40601",
		x = p[2], y = p[3], z = p[4], rot = p[5] })
end

local function walkIntoSolar(player)
	player:EndEvent()
	local p = HALL_LANDING
	bouncePlayer(player, p[2], p[3], p[4], p[5])
end

-- The public west door is the Hall's entrance: the offer, then the briefing (talk flags kept on re-entry).
function westDoor(player, quest, sequence)
	if inPrivateArea(player) then
		walkIntoSolar(player)
	elseif (sequence == SEQ_ACCEPT or sequence == SEQ_HELD) and isLevelMet(player) then
		local answer = companionEvent(player, quest, "pES")
		if answer == 1 or answer == true then
			if sequence == SEQ_ACCEPT then
				player:AcceptQuest(quest)
				quest = player:GetQuest(110019)
			end
			if quest ~= nil then
				if quest:GetData():GetNpcLsFrom() ~= 0 then
					quest:EndOfNpcLsMsgs()
				end
				quest:StartSequence(SEQ_000)
			end
			-- man40600 fades in only after a warp: the Hall warp releases it.
			startHall(player)
		else
			walkIntoSolar(player)
		end
	elseif sequence == SEQ_000 or sequence == SEQ_005 then
		startHall(player)
	else
		walkIntoSolar(player)
	end
end

local function leaveHall(player)
	-- Both lines print on the way out.
	player:SendGameMessage(GetWorldMaster(), TEXT_UNBOUND_FROM_DUTY, 0x20)
	player:SendGameMessage(GetWorldMaster(), TEXT_ENTERED_INSTANCE, 0x20)
	local area = player.CurrentArea
	pcall(function() area:ContentFinished() end)
	local p = OFFICE_HALL
	warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
end

-- Inside the Hall the east door leaves the briefing; outside it walks to the office hall.
function eastDoor(player, quest)
	player:EndEvent()
	if inPrivateAreaOf(player, SANDS_ZONE, "SimpleContentMan40601") then
		leaveHall(player)
		return
	end
	local p = OFFICE_HALL
	bouncePlayer(player, p[2], p[3], p[4], p[5])
end

-- man40615 fades in only after a warp: the way out to the lobby releases it.
function captainFarewell(player, quest)
	companionEvent(player, quest, "pE15")
	player:EndEvent()
	quest:StartSequence(SEQ_010)
	leaveHall(player)
end

local function startField(player)
	local p = FIELD_LANDING
	startQuestContent(player, { zone = p[1], content = "SimpleContentMan40602", director = "Quest/QuestDirectorMan40601",
		x = p[2], y = p[3], z = p[4], rot = p[5] })
end

local function startCave(player)
	local p = CAVE_LANDING
	startQuestContent(player, { zone = p[1], content = "SimpleContentMan40603", director = "Quest/QuestDirectorMan40601",
		x = p[2], y = p[3], z = p[4], rot = p[5] })
end

local function startAftermath(player)
	local p = AFTERMATH_LANDING
	startQuestContent(player, { zone = p[1], content = "SimpleContentMan40604", director = "Quest/QuestDirectorEventMan40602",
		x = p[2], y = p[3], z = p[4], rot = p[5] })
end

-- The ask, then the bind and man40620 the first time; a retry skips the scene and the journal line. At
-- 20 the push relaunches the cave a disconnect dropped.
function enterAtRevenantsToll(player, quest, sequence)
	if delegateEvent(player, quest, "contentsJoinAskInBasaClass") ~= 1 then
		player:EndEvent()
		return
	end
	if sequence == SEQ_020 then
		startCave(player)
		return
	end

	player:SendGameMessage(GetWorldMaster(), TEXT_ENTERED_INSTANCE, 0x20)
	player:SendGameMessage(GetWorldMaster(), TEXT_BOUND_BY_DUTY, 0x20)
	if not getQuestFlag(quest, FLAG_CAMP_SCENE_SEEN) then
		delegateEvent(player, quest, "processEvent020", false)
		setQuestFlagOn(quest, FLAG_CAMP_SCENE_SEEN)
	end
	if sequence == SEQ_010 then
		quest:StartSequence(SEQ_015)
	end
	player:SendGameMessage(GetWorldMaster(), TEXT_UNBOUND_FROM_DUTY, 0x20)
	startField(player)
end

-- Called by QuestDirectorMan40601 once the centurion is gone: man40630, man40635, man40645.
-- The cave warp releases the fade.
function finishField(player, quest, fight, area)
	companionEvent(player, quest, "pE30")
	quest:StartSequence(SEQ_020)
	player:SendGameMessage(GetWorldMaster(), TEXT_UNBOUND_FROM_DUTY, 0x20)
	player:SetMod(MOD_MINIMUM_HP_LOCK, 0)
	fight:Close()
	pcall(function() area:ContentFinished() end)
	startCave(player)
end

-- A loss keeps 15: out where the player stands, or on the landing when that would sit in the camp
-- trigger's circle.
function failField(player, quest, duty, area)
	local x, y, z, rot = player.positionX, player.positionY, player.positionZ, player.rotation
	if math.sqrt((x + 219.0) ^ 2 + (z + 680.0) ^ 2) <= 8.0 then
		local p = FIELD_LANDING
		x, y, z, rot = p[2], p[3], p[4], p[5]
	end
	leaveQuestContent(player, duty, area, { zone = FIELD_ZONE, x = x, y = y, z = z, rot = rot })
end

-- The way out of the cave asks again; man40650 fades in at the camp.
function leaveCave(player, quest)
	if delegateEvent(player, quest, "contentsJoinAskInBasaClass") ~= 1 then
		player:EndEvent()
		return
	end
	companionEvent(player, quest, "pE50")
	quest:StartSequence(SEQ_025)
	local area = player.CurrentArea
	pcall(function() area:ContentFinished() end)
	startAftermath(player)
end

-- man40660 fades in only after a warp: out to an Ul'dah street, where the notice pays.
function reportToTataru(player, quest)
	companionEvent(player, quest, "pE60")
	player:EndEvent()
	setQuestFlagOn(quest, FLAG_REWARD_SCENE_SEEN)
	local p = ULDAH_STREET
	kickAfterWarpNotice(player, p[1])
	warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
end

function onNotice(player, quest, target)
	if quest:GetSequence() == SEQ_025 and getQuestFlag(quest, FLAG_REWARD_SCENE_SEEN) then
		dismissNowLoadingVeil(player, quest)
		turnInQuest(player, quest)
		return
	end
	player:EndEvent()
	quest:UpdateENPCs()
end

-- Tataru's call while the quest is held (xtx/npcLsBfrxtx row 38 through worldMaster 51035, the companion's
-- name as the row's string); the accept ends it.
local PEARL_NAME_LIMIT = 19 -- the message's 52 parameter bytes leave 19 for the name
function onNpcLS(player, quest, from, msgStep)
	if from == NPCLS_PATH_OF_THE_TWELVE and quest:GetSequence() == SEQ_HELD then
		local nickname = player:GetSNpcNickname() or ""
		if nickname ~= "" and #nickname <= PEARL_NAME_LIMIT then
			-- 1 to 5 are the client's defaults for the row's unused parameters.
			player:SendGameMessageLocalizedDisplayName(GetWorldMaster(), TEXT_PEARL_BEFORE_QUEST, MESSAGE_TYPE_NPC_LINKSHELL,
				DISPLAY_TATARU, PEARL_ROW_TATARU, 1, 2, 3, 4, 5, nickname)
		end
		if msgStep <= 1 then
			quest:ReadNpcLsMsg()
		end
	end
	player:EndEvent()
end

-- int3: the rescuer by starting city (the initial town); the rows read the companion's name.
function getJournalInformation(player, quest)
	return 0, player:GetInitialTown(), 0, 0, 0, player:GetSNpcNickname()
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
