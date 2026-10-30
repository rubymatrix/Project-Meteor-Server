require("Global")
require("Quest")
require("QuestFlow")

--[[
Of Men They Sing (Man402, 110018). Prereq: Lord Errant (Man308); level 42.
Lord Errant's payout grants it silently; Tataru offers it in the Waking Sands. The search at Camp Nine
Ivies is a duty (QuestDirectorMan40201). Walkthrough: Data/Docs/Scripts/Quest/Man/Man402.md.
--]]

local offerAtTataru, payReward, startSearch, reportToTataru, sandsPush

local SEQ_000 = 0
local SEQ_001 = 1
SEQ_005 = 5
local SEQ_015 = 15

local TATARU                 = 1001046
local SERANELIEN             = 1001378
local SAHJA_ZHWAN            = 1001373
local NENEKANI               = 1001374
local GODFREY                = 1001375
local FENANA                 = 1001376
local NONORU                 = 1001377
local NINE_IVIES_TRIGGER     = 1090218
local WOUNDED_REBEL_WARRIOR  = 1001239
local SNPC_BASE              = 1070000

local MARKET_ENTRANCE_ULDAH  = 1090265
local SANDS_EXIT_DOOR        = 1090160
local OFFICE_WEST_DOOR       = 1090161
local OFFICE_EAST_DOOR       = 1090162

local MRKR_TATARU            = 11001801
local MRKR_NINE_IVIES        = 11001802
local MRKR_MARKET_ENTRANCE   = 11001803
local MRKR_TATARU_REPORT     = 11001804
local MRKR_SEARCH_POINT      = 11001805

local FLAG_CAMP_SCENE_SEEN   = 0
local FLAG_REWARD_SCENE_SEEN = 1
FLAG_HOUNDS_DEFEATED   = 2

local CNTR_DEAD_RELATIVE     = 0  -- 1..4, the switch slot of man402 rows 132-158

-- man402 row 1, said by "???" (display name 4000257).
local TEXT_DISTRESS_CALL       = 1
local DISPLAY_UNKNOWN_SENDER   = 4000257
local NPCLS_PATH_OF_THE_TWELVE = 6

local SANDS_ZONE = 181
local DUTY_ZONE  = 151

local QUEST_LEVEL = 42

-- Points: { zone, x, y, z, rot }
local DUTY_LANDING     = { 151, 1970.677, 34.22, -1465.982, 3.033 }
local DUTY_EXIT        = { 151, 1870.347, 20.411, -1731.395, 1.457 }
local ULDAH_STREET     = { 175, -216.52, 190.0, 30.5, 2.32 }
local SANDS_ENTRY      = { 181, -205.25, 0.0, -160.0, 1.55 }
local OFFICE_INSIDE    = { -126.2, 1.2, -160.0, 1.6 }
local OFFICE_OUTSIDE   = { -142.75, 1.0, -160.0, -1.6 }

local AFTER_WARP_NOTICE = true

local function companionClass(player)
	return SNPC_BASE + player:GetSNpcSkin()
end

-- The companion tuple the pE functions take as a3..a7.
local function companionEvent(player, quest, eventName, ...)
	return delegateEvent(player, quest, eventName, player:GetSNpcNickname(), player:GetSNpcSkin(),
		player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown(), ...)
end

local function inSands(player)
	return currentZoneId(player) == SANDS_ZONE
end

local function outOfSands(player)
	return currentZoneId(player) ~= SANDS_ZONE
end

-- The camp trigger spawns only in the public East Shroud; the duty's copy shares the zone id.
local function atCampNineIvies(player)
	return currentZoneId(player) == DUTY_ZONE and not inPrivateArea(player)
end

-- The duty map shows no marker during the search.
local function outOfDuty(player)
	return not inPrivateArea(player)
end

local function push(classId, icon)
	return { classId, icon or QFLAG_OFF, talk = false, push = true }
end

local SANDS_CROWD = { SERANELIEN, SAHJA_ZHWAN, NENEKANI, GODFREY, FENANA, NONORU }

local function sandsEnpcs(tataru)
	return {
		tataru,
		{ crowd = SANDS_CROWD },
		push(MARKET_ENTRANCE_ULDAH), push(SANDS_EXIT_DOOR), push(OFFICE_WEST_DOOR), push(OFFICE_EAST_DOOR),
	}
end

local function withCampTrigger(list)
	-- The minimap shows the invisible trigger's "!".
	list[#list + 1] = { NINE_IVIES_TRIGGER, QFLAG_PUSH, talk = false, push = atCampNineIvies, spawn = true }
	return list
end

local function isLevelMet(player)
	return player:GetLevel() >= QUEST_LEVEL
end

-- The offer on an old character: no journal yet, so no markers.
local OFFER_PHASE = { [SEQ_ACCEPT] = { enpcs = sandsEnpcs({ TATARU, QFLAG_TALK }) } }

local PHASES = {
	-- Held: below the level Tataru's "!" stays dark and her talk offers nothing.
	[SEQ_000] = {
		enpcs = sandsEnpcs({ TATARU, QFLAG_TALK, when = isLevelMet }),
		markers = { { MRKR_TATARU, when = isLevelMet } },
	},
	[SEQ_001] = { enpcs = withCampTrigger(sandsEnpcs(TATARU)), markers = { MRKR_NINE_IVIES } },
	[SEQ_005] = {
		enpcs = withCampTrigger(sandsEnpcs(TATARU)),
		markers = { { MRKR_SEARCH_POINT, when = outOfDuty } },
	},
	[SEQ_015] = {
		enpcs = sandsEnpcs({ TATARU, QFLAG_REWARD }),
		markers = {
			{ MRKR_MARKET_ENTRANCE, when = outOfSands },
			{ MRKR_TATARU_REPORT, when = inSands },
		},
	},
}

-- The Sands before the duty (rows 108-119, 250) and after it (rows 120-131). Nenekani's pE03/pE23 take
-- the companion tuple.
local SANDS_LINES = {
	[SERANELIEN] = "processEvent000_1", [SAHJA_ZHWAN] = "processEvent000_2", [GODFREY] = "processEvent000_4",
	[FENANA] = "processEvent000_5", [NONORU] = "processEvent000_6", [TATARU] = "processEvent000_7",
}
local CHATTER = {
	[SEQ_000] = SANDS_LINES,
	[SEQ_001] = SANDS_LINES,
	[SEQ_005] = SANDS_LINES,
	[SEQ_015] = {
		[SERANELIEN] = "processEvent020_1", [SAHJA_ZHWAN] = "processEvent020_2", [GODFREY] = "processEvent020_4",
		[FENANA] = "processEvent020_5", [NONORU] = "processEvent020_6",
	},
}

-- No rule picks the dead relative, so each character rolls one of the four.
local function rollDeadRelative()
	return math.random(1, 4)
end

local function deadRelative(quest)
	local r = getQuestCounter(quest, CNTR_DEAD_RELATIVE)
	return (r >= 1 and r <= 4) and r or 1
end

-- Granted (Lord Errant's hand-on) or accepted on an old character's offer: held either way; the offer
-- moves a held quest to 1.
function onStart(player, quest)
	setQuestCounter(quest, CNTR_DEAD_RELATIVE, rollDeadRelative())
	quest:StartSequenceForNpcLs(SEQ_000)
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
	if sequence == SEQ_005 then
		-- The companion leads the search; she has no line of her own there.
		quest:SetENpc(companionClass(player))
		quest:SetENpc(WOUNDED_REBEL_WARRIOR)
	end
end

local function chatter(player, quest, npc)
	delegateChatter(player, quest, CHATTER, quest:GetSequence(), npc:GetActorClassId())
end

local function tataruOffer(player, quest)
	if isLevelMet(player) then
		offerAtTataru(player, quest)
		return true
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[TATARU] = tataruOffer,
		[NENEKANI] = function() end,
		other = function() end,
	},
	[SEQ_000] = {
		[TATARU] = function(player, quest, npc)
			if tataruOffer(player, quest) then return true end
			chatter(player, quest, npc)
		end,
		[NENEKANI] = chatter,
	},
	[SEQ_005] = {
		-- The client ships no scout line: after both kills a talk ends the duty without the settle wait.
		[WOUNDED_REBEL_WARRIOR] = function(player, quest)
			if getQuestFlag(quest, FLAG_HOUNDS_DEFEATED) then
				sendPlayerSignal(player, "man402ScoutSafe")
			end
		end,
	},
	[SEQ_015] = {
		[TATARU] = function(player, quest)
			if not getQuestFlag(quest, FLAG_REWARD_SCENE_SEEN) then
				reportToTataru(player, quest)
			else
				-- The after-warp notice never came: pay here.
				payReward(player, quest)
			end
			return true
		end,
		[NENEKANI] = function(player, quest) companionEvent(player, quest, "pE23") end,
	},
	always = {
		[NENEKANI] = function(player, quest) companionEvent(player, quest, "pE03") end,
	},
	other = chatter,
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

local function campPush(player, quest)
	if atCampNineIvies(player) then
		startSearch(player, quest)
		return true
	end
end

local pushBySequence = {
	[SEQ_001] = { [NINE_IVIES_TRIGGER] = campPush },
	[SEQ_005] = { [NINE_IVIES_TRIGGER] = campPush },
}

function onPush(player, quest, npc, eventName)
	if sandsPush(player, npc:GetActorClassId()) then return end
	if runQuestHandler(pushBySequence, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

-- pES returns the man40200 scene's result on accept, the window's 2 on decline.
function offerAtTataru(player, quest)
	local answer = delegateEvent(player, quest, "pES", player:GetSNpcNickname(), companionClass(player),
		player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown())
	player:EndEvent()
	if answer ~= 1 and answer ~= true then
		return
	end
	if quest:GetSequence() == SEQ_ACCEPT then
		player:AcceptQuest(quest)
		quest = player:GetQuest(110018)
	end
	if quest ~= nil then
		if quest:GetData():GetNpcLsFrom() ~= 0 then
			quest:EndOfNpcLsMsgs()
		end
		quest:StartSequence(SEQ_001)
	end
end

-- Futures Perfect's holder arms Tataru's pearl, so the payout hands the story on silently.
function payReward(player, quest)
	if turnInQuest(player, quest) then
		player:AddQuest(110019, true)
	end
end

-- The ask comes first; man40210 plays once per character.
function startSearch(player, quest)
	if delegateEvent(player, quest, "contentsJoinAskInBasaClass") ~= 1 then
		player:EndEvent()
		return
	end
	if not getQuestFlag(quest, FLAG_CAMP_SCENE_SEEN) then
		companionEvent(player, quest, "pE10", deadRelative(quest))
		setQuestFlagOn(quest, FLAG_CAMP_SCENE_SEEN)
	end
	-- A failed or relogged run re-enters at 5 with no journal line.
	if quest:GetSequence() == SEQ_001 then
		quest:StartSequence(SEQ_005)
	end
	local p = DUTY_LANDING
	startQuestContent(player, { zone = p[1], content = "SimpleContentMan40201", director = "Quest/QuestDirectorMan40201",
		x = p[2], y = p[3], z = p[4], rot = p[5] })
end

-- Called by QuestDirectorMan40201 once the hounds are down: the scout is safe.
function finishSearch(player, quest, duty, area)
	companionEvent(player, quest, "pE20")
	quest:StartSequence(SEQ_015)
	local p = DUTY_EXIT
	leaveQuestContent(player, duty, area, { zone = p[1], x = p[2], y = p[3], z = p[4], rot = p[5] })
end

function failSearch(player, quest, duty, area)
	leaveQuestContent(player, duty, area, { zone = DUTY_ZONE, x = player.positionX, y = player.positionY,
		z = player.positionZ, rot = player.rotation })
end

-- man40230 fades in only after a warp: out to an Ul'dah street, where the notice pays.
function reportToTataru(player, quest)
	companionEvent(player, quest, "pE30")
	player:EndEvent()
	setQuestFlagOn(quest, FLAG_REWARD_SCENE_SEEN)
	local p = ULDAH_STREET
	kickAfterWarpNotice(player, p[1])
	warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
end

function onNotice(player, quest, target)
	if quest:GetSequence() == SEQ_015 and getQuestFlag(quest, FLAG_REWARD_SCENE_SEEN) then
		dismissNowLoadingVeil(player, quest)
		payReward(player, quest)
		return
	end
	player:EndEvent()
	quest:UpdateENPCs()
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

-- The plea repeats on every read while the quest is held; the accept ends it.
function onNpcLS(player, quest, from, msgStep)
	if from == NPCLS_PATH_OF_THE_TWELVE and quest:GetSequence() == SEQ_000 then
		player:SendGameMessageLocalizedDisplayName(quest, TEXT_DISTRESS_CALL, MESSAGE_TYPE_NPC_LINKSHELL,
			DISPLAY_UNKNOWN_SENDER)
		if msgStep <= 1 then
			quest:ReadNpcLsMsg()
		end
	end
	player:EndEvent()
end

-- Only row 224 reads a parameter: the companion's name.
function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0, player:GetSNpcNickname()
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
