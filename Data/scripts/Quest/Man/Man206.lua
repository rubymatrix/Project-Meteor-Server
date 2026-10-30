require("Global")
require("Quest")
require("QuestFlow")

--[[

Quest Script

Name:   Together We Stand
Code:   Man206
Id:     110014
Prereq: Fade to White (Man200 - 110013). Level 22.

Fade to White's turn-in hands this quest on silently; its accept is Minfilia's processEvent001.
Seq 0:  Held, no journal paragraph. Tataru's Path pearl calls the player in. The Ul'dah market entrance
        walks into this quest's Waking Sands (181 PA 11, the sylphs in the Solar); at level 22 the west
        office door plays the sylphs' arrival (processEventUdowntownrectStart) once and arms Minfilia,
        whose processEvent001 asks (1 = accepted).
Seq 5:  The companion's farewell on the Path pearl (one pack per personality); its last line moves to 10.
Seq 10: The rendezvous at the Gridania aetheryte plaza (push): pE12.
Seq 15: Camp Nine Ivies (push): the join ask, then pE13 (the sylphs' plea, first time only), then the
        grove duty (content SimpleContentMan20601, QuestDirectorMan20601).
Seq 20: In the grove: processEvent016 (HQ MAN20610) near the grove's mouth, then Dokixia hands over the
        podling (pE20).
Seq 25: Carrying the podling back to Flaxio: pE30, out to the camp.
Seq 30: Tataru in the Waking Sands: processEvent040, then the reward on the street outside.

The duty is a stealth run (QuestDirectorMan20601): imperial sentries see the player at 10 yalms (3 while
the sylphs' magicks hold), the companion walks along and warns of them, a talk with a sylph renews the
cover. A failed run (time up, the companion left behind) returns the step to 15 at the camp; the
camp trigger asks again without the plea.

--]]

local startGroveDuty, currentDuty, dropPodling

local AFTER_WARP_NOTICE = true

local SEQ_000 = 0
local SEQ_005 = 5
local SEQ_010 = 10
local SEQ_015 = 15
SEQ_020 = 20
SEQ_025 = 25
local SEQ_030 = 30

local MINFILIA            = 1000843
local TATARU              = 1001046
local SERANELIEN          = 1001378
local SAHJA_ZHWAN         = 1001373
local NENEKANI            = 1001374
local GODFREY             = 1001375
local FENANA              = 1001376
local NONORU              = 1001377
local ALMXIO              = 1001085
local ZOXIO               = 1001086
local DILUXIO             = 1001178
local FLAXIO              = 1001237
local DOKIXIA             = 1001238

local MARKET_ENTRANCE     = 1090265 -- the Ul'dah archway (MarketEntrance)
local SANDS_EXIT_DOOR     = 1090160 -- ObjectEventDoor
local OFFICE_WEST_DOOR    = 1090161 -- ObjectEventDoor
local OFFICE_EAST_DOOR    = 1090162 -- ObjectEventDoor
local RENDEZVOUS_TRIGGER  = 1090177 -- Gridania aetheryte plaza (public 206)
local NINE_IVIES_TRIGGER  = 1090296 -- Camp Nine Ivies (public 151)

local SNPC_BASE           = 1070000

local MRKR_GRIDANIA           = 11001402
local MRKR_NINE_IVIES         = 11001403
local MRKR_MOONSPORE_APPROACH = 11001404
local MRKR_DOKIXIA            = 11001405
local MRKR_FLAXIO             = 11001406
local MRKR_MARKET_ENTRANCE    = 11001407
local MRKR_SANDS_TATARU       = 11001303 -- the client ships no Man206 Tataru marker: Fade to White's

FLAG_CARRYING_PODLING = 0
FLAG_GROVE_SCENE      = 1
local FLAG_NINE_IVIES_SCENE = 2
local FLAG_OFFICE_SCENE     = 3

CNTR_CONCEAL = 0 -- bumped by a sylph's talk in the duty; the director answers each change

local ITEM_PODLING        = 11000091
local STATUS_PODLING      = 223993  -- Intact Podling Toting
local NPCLS_PATH          = 6
local TATARU_DISPLAY_ID   = 1500054
local TEXT_TATARU_CALL    = 1
local TEXT_FAREWELL_BASE  = 330     -- 330 + (personality - 1) + 9 * (line - 1), four lines
local FAREWELL_LINES      = 4
local QUEST_LEVEL         = 22

local WAKING_SANDS_ZONE   = 181
local SANDS_PA            = 11
local GROVE_ZONE          = 151

local SANDS_ENTRY     = { -205.25, 0, -160, 1.55 }
local SOLAR_INSIDE    = { -126.2, 1.2, -160, 1.6 }
local SOLAR_OUTSIDE   = { -142.75, 1, -160, -1.6 }
local ULDAH_STREET    = { 175, -216.52, 190, 30.5, 2.32 }
local GROVE_LANDING   = { 1882.422, 34.153, -1018.115, 1.392 }
local CAMP_RETURN     = { 1700.337, 20.022, -866.217, 1.483 }

local function isLevelMet(player)
	return player:GetLevel() >= QUEST_LEVEL
end

local function isOfficeSceneSeen(player, quest, data)
	return isLevelMet(player) and data:GetFlag(FLAG_OFFICE_SCENE)
end

local function isOfficeSceneUnseen(player, quest, data)
	return isLevelMet(player) and not data:GetFlag(FLAG_OFFICE_SCENE)
end

local function isGroveSceneSeen(player, quest, data)
	return data:GetFlag(FLAG_GROVE_SCENE)
end

local function isGroveSceneUnseen(player, quest, data)
	return not data:GetFlag(FLAG_GROVE_SCENE)
end

local function isInWakingSands(player)
	return currentZoneId(player) == WAKING_SANDS_ZONE
end

local function isOutOfWakingSands(player)
	return currentZoneId(player) ~= WAKING_SANDS_ZONE
end

local SANDS_CROWD = { SERANELIEN, SAHJA_ZHWAN, NENEKANI, GODFREY, FENANA, NONORU, ALMXIO, ZOXIO, DILUXIO }
local RETURN_CROWD = { SERANELIEN, SAHJA_ZHWAN, GODFREY, FENANA, NONORU }
local GROVE_SYLPHS = { ALMXIO, ZOXIO, DILUXIO }

local function door(classId)
	return { classId, QFLAG_OFF, talk = false, push = true }
end

local ENTRANCE = door(MARKET_ENTRANCE)
local CAMP_TRIGGER = { NINE_IVIES_TRIGGER, QFLAG_PUSH, talk = false, push = true }

local PHASES = {
	-- Below level 22 the quest leaves the archway and the Sands alone.
	[SEQ_000] = {
		enpcs = {
			{ MINFILIA, QFLAG_TALK, when = isOfficeSceneSeen, talk = isOfficeSceneSeen }, TATARU,
			{ OFFICE_WEST_DOOR, QFLAG_PUSH, when = isOfficeSceneUnseen, talk = false, push = true },
			door(OFFICE_EAST_DOOR), door(SANDS_EXIT_DOOR),
			{ MARKET_ENTRANCE, QFLAG_OFF, talk = false, push = isLevelMet },
			{ crowd = SANDS_CROWD },
		},
	},
	[SEQ_005] = {
		enpcs = {
			MINFILIA, TATARU, door(OFFICE_WEST_DOOR), door(OFFICE_EAST_DOOR), door(SANDS_EXIT_DOOR), ENTRANCE,
			{ crowd = SANDS_CROWD },
		},
	},
	[SEQ_010] = {
		enpcs = {
			MINFILIA, TATARU, door(OFFICE_WEST_DOOR), door(OFFICE_EAST_DOOR), door(SANDS_EXIT_DOOR), ENTRANCE,
			{ RENDEZVOUS_TRIGGER, QFLAG_PUSH, talk = false, push = true }, { crowd = SANDS_CROWD },
		},
		markers = { MRKR_GRIDANIA },
	},
	[SEQ_015] = {
		enpcs = { MINFILIA, TATARU, door(OFFICE_WEST_DOOR), door(OFFICE_EAST_DOOR), door(SANDS_EXIT_DOOR), CAMP_TRIGGER },
		markers = { MRKR_NINE_IVIES },
	},
	-- The duty's actors; the companion's row is set in onStateChange (its class is the player's choice).
	[SEQ_020] = {
		enpcs = {
			CAMP_TRIGGER, { DOKIXIA, QFLAG_TALK, when = isGroveSceneSeen }, FLAXIO, { crowd = GROVE_SYLPHS },
		},
		markers = {
			{ MRKR_MOONSPORE_APPROACH, when = isGroveSceneUnseen }, { MRKR_DOKIXIA, when = isGroveSceneSeen },
		},
	},
	[SEQ_025] = {
		enpcs = { CAMP_TRIGGER, { FLAXIO, QFLAG_TALK }, DOKIXIA, { crowd = GROVE_SYLPHS } },
		markers = { MRKR_FLAXIO },
	},
	[SEQ_030] = {
		enpcs = {
			{ TATARU, QFLAG_REWARD }, MINFILIA, door(OFFICE_WEST_DOOR), door(OFFICE_EAST_DOOR),
			door(SANDS_EXIT_DOOR), ENTRANCE, { crowd = RETURN_CROWD },
		},
		markers = { { MRKR_SANDS_TATARU, when = isInWakingSands }, { MRKR_MARKET_ENTRANCE, when = isOutOfWakingSands } },
	},
}

local EARLY_LINES = {
	[TATARU] = "processEvent000_2", [SERANELIEN] = "processEvent000_3", [SAHJA_ZHWAN] = "processEvent000_4",
	[NENEKANI] = "processEvent000_5", [GODFREY] = "processEvent000_6", [FENANA] = "processEvent000_7",
	[NONORU] = "processEvent000_8", [ALMXIO] = "processEvent000_9", [ZOXIO] = "processEvent000_10",
	[DILUXIO] = "processEvent000_11",
}

-- Nenekani and the sylphs have no 001_x line and keep their 000_x one.
local WAITING_LINES = {
	[SERANELIEN] = "processEvent001_3", [SAHJA_ZHWAN] = "processEvent001_4", [NENEKANI] = "processEvent000_5",
	[GODFREY] = "processEvent001_5", [FENANA] = "processEvent001_6", [NONORU] = "processEvent001_7",
	[ALMXIO] = "processEvent000_9", [ZOXIO] = "processEvent000_10", [DILUXIO] = "processEvent000_11",
}

local CHATTER = {
	[SEQ_000] = EARLY_LINES,
	[SEQ_005] = WAITING_LINES,
	[SEQ_010] = WAITING_LINES,
	[SEQ_030] = {
		[SERANELIEN] = "processEvent030_2", [SAHJA_ZHWAN] = "processEvent030_3", [GODFREY] = "processEvent030_4",
		[FENANA] = "processEvent030_5", [NONORU] = "processEvent030_6",
	},
}

-- The sylphs' talk in the grove renews the cover (the director answers the counter).
local GROVE_SYLPH_LINES = { [ZOXIO] = "processEvent016_1", [ALMXIO] = "processEvent016_2", [DILUXIO] = "processEvent016_3" }

local function delegateCompanion(player, quest, eventName)
	return delegateEvent(player, quest, eventName, player:GetSNpcNickname(), player:GetSNpcSkin(),
		player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown())
end

-- Text parameter 1 is the companion's name, parameter 2 its personality.
local function delegateCompanionTopic(player, quest, eventName)
	return delegateEvent(player, quest, eventName, player:GetSNpcNickname(), player:GetSNpcPersonality())
end

local function companionClass(player)
	return SNPC_BASE + player:GetSNpcSkin()
end

-- Personality 1-9; anything else reads as 1.
function companionPersonality(player)
	local p = player:GetSNpcPersonality()
	if p == nil or p < 1 or p > 9 then
		return 1
	end
	return p
end

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
	-- The pearl belongs to 0 and arms once per grant; Tataru's call never advances.
	quest:NewNpcLsMsg(NPCLS_PATH)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		-- Held but not accepted: the archway takes them in.
		quest:SetENpc(MARKET_ENTRANCE, QFLAG_PUSH, false, true)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
	if sequence == SEQ_020 or sequence == SEQ_025 then
		quest:SetENpc(companionClass(player))
	end
end

local function groveTalk(player, quest, npc)
	local classId = npc:GetActorClassId()
	local line = GROVE_SYLPH_LINES[classId]
	if line ~= nil then
		setQuestCounter(quest, CNTR_CONCEAL, getQuestCounter(quest, CNTR_CONCEAL) + 1)
		delegateEvent(player, quest, line)
	elseif classId == companionClass(player) then
		-- The companion's own warning, one line per personality.
		player:SendGameMessage(npc, quest, 560 + companionPersonality(player) - 1, MESSAGE_TYPE_SAY)
	end
end

local talk = {
	[SEQ_000] = {
		[MINFILIA] = function(player, quest, npc)
			if not isOfficeSceneSeen(player, quest, quest:GetData()) then
				delegateChatter(player, quest, CHATTER, SEQ_000, MINFILIA)
				return
			end
			-- The decline plays inside the scene: anything but 1 leaves her armed.
			if delegateEvent(player, quest, "processEvent001") == 1 then
				player:EndEvent()
				quest:StartSequence(SEQ_005)
				quest:NewNpcLsMsg(NPCLS_PATH)
				local p = SOLAR_OUTSIDE
				bouncePlayer(player, p[1], p[2], p[3], p[4])
				return true
			end
		end,
	},
	[SEQ_005] = {
		[TATARU] = function(player, quest) delegateCompanionTopic(player, quest, "processEvent001_2") end,
		[MINFILIA] = function(player, quest) delegateCompanionTopic(player, quest, "processEvent001_2") end,
	},
	[SEQ_010] = {
		[TATARU] = function(player, quest) delegateCompanionTopic(player, quest, "processEvent010_2") end,
		[MINFILIA] = function(player, quest) delegateCompanionTopic(player, quest, "processEvent001_2") end,
	},
	[SEQ_020] = {
		-- After the grove scene her talk hands the podling over for a player who stops short of her.
		[DOKIXIA] = function(player, quest)
			if getQuestFlag(quest, FLAG_GROVE_SCENE) then
				takePodling(player, quest)
				return true
			end
		end,
		other = groveTalk,
	},
	[SEQ_025] = {
		[DOKIXIA] = function(player, quest)
			setQuestCounter(quest, CNTR_CONCEAL, getQuestCounter(quest, CNTR_CONCEAL) + 1)
			delegateEvent(player, quest, "processEvent020_2")
		end,
		[FLAXIO] = function(player, quest)
			local fight, area = currentDuty(player)
			deliverPodling(player, quest, fight, area)
			return true
		end,
		other = groveTalk,
	},
	[SEQ_030] = {
		-- man20640 fades in only after a warp: the reward is paid on the street (onNotice).
		[TATARU] = function(player, quest)
			delegateEvent(player, quest, "processEvent040")
			player:EndEvent()
			kickAfterWarpNotice(player, ULDAH_STREET[1])
			local p = ULDAH_STREET
			warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
			return true
		end,
	},
	other = function(player, quest, npc)
		delegateChatter(player, quest, CHATTER, quest:GetSequence(), npc:GetActorClassId())
	end,
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

local function warpIntoSands(player)
	local p = SANDS_ENTRY
	warpTo(player, WAKING_SANDS_ZONE, "PrivateAreaMasterPast", SANDS_PA, p[1], p[2], p[3], p[4])
	return true
end

local function enterSolar(player, quest)
	player:EndEvent()
	quest:UpdateENPCs()
	local p = SOLAR_INSIDE
	bouncePlayer(player, p[1], p[2], p[3], p[4])
	return true
end

local function campTrigger(player, quest)
	if currentZoneId(player) == GROVE_ZONE and not inPrivateArea(player) then
		startGroveDuty(player, quest)
		return true
	end
end

-- The door classes (ObjectEventDoor) have asked the move question already.
local push = {
	[SEQ_ACCEPT] = {
		[MARKET_ENTRANCE] = function(player, quest)
			player:EndEvent()
			player:AcceptQuest(quest, true)
			return warpIntoSands(player)
		end,
	},
	[SEQ_000] = {
		[OFFICE_WEST_DOOR] = function(player, quest)
			if isLevelMet(player) and not getQuestFlag(quest, FLAG_OFFICE_SCENE) then
				delegateEvent(player, quest, "processEventUdowntownrectStart")
				setQuestFlagOn(quest, FLAG_OFFICE_SCENE)
			end
			return enterSolar(player, quest)
		end,
	},
	-- pE12 fades back in on its own: no warp.
	[SEQ_010] = {
		[RENDEZVOUS_TRIGGER] = function(player, quest)
			delegateCompanion(player, quest, "pE12")
			quest:StartSequence(SEQ_015)
		end,
	},
	[SEQ_015] = { [NINE_IVIES_TRIGGER] = campTrigger },
	[SEQ_020] = { [NINE_IVIES_TRIGGER] = campTrigger },
	[SEQ_025] = { [NINE_IVIES_TRIGGER] = campTrigger },
	always = {
		[MARKET_ENTRANCE] = function(player)
			player:EndEvent()
			return warpIntoSands(player)
		end,
		[SANDS_EXIT_DOOR] = function(player)
			player:EndEvent()
			local p = ULDAH_STREET
			warpTo(player, p[1], nil, 0, p[2], p[3], p[4], p[5])
			return true
		end,
		[OFFICE_WEST_DOOR] = enterSolar,
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

-- The camp ask and the launch. A retry skips the sylphs' plea and only asks again.
function startGroveDuty(player, quest)
	if delegateEvent(player, quest, "contentsJoinAskInBasaClass") ~= 1 then
		player:EndEvent()
		return
	end
	if not getQuestFlag(quest, FLAG_NINE_IVIES_SCENE) then
		if delegateCompanion(player, quest, "pE13") ~= 1 then
			player:EndEvent()
			return
		end
		setQuestFlagOn(quest, FLAG_NINE_IVIES_SCENE)
	end

	-- A run starts clean: the carry and the grove scene belong to one run.
	dropPodling(player, quest)
	clearQuestFlag(quest, FLAG_GROVE_SCENE)
	if quest:GetSequence() ~= SEQ_020 then
		quest:StartSequence(SEQ_020)
	end
	local p = GROVE_LANDING
	startQuestContent(player, {
		zone = GROVE_ZONE, content = "SimpleContentMan20601", director = "Quest/QuestDirectorMan20601",
		x = p[1], y = p[2], z = p[3], rot = p[4],
	})
end

function currentDuty(player)
	local director = player:GetDirector("Quest/QuestDirectorMan20601")
	local fight = director and director:GetEncounter()
	return fight, player.CurrentArea
end

function dropPodling(player, quest)
	takeKeyItem(player, ITEM_PODLING)
	pcall(function() player.statusEffects:RemoveStatusEffect(STATUS_PODLING) end)
	clearQuestFlag(quest, FLAG_CARRYING_PODLING)
end

-- The grove's mouth (director, on approach): the HQ cutscene, then Dokixia shows the "!".
function playGroveScene(player, quest)
	delegateEvent(player, quest, "processEvent016")
	setQuestFlagOn(quest, FLAG_GROVE_SCENE)
	player:EndEvent()
	quest:UpdateENPCs()
end

-- Dokixia's hand-over (her talk, or the director on approach).
function takePodling(player, quest)
	delegateCompanion(player, quest, "pE20")
	giveKeyItem(player, ITEM_PODLING)
	pcall(function() player.statusEffects:AddStatusEffect(STATUS_PODLING, 1, 0, 3600, 0) end)
	setQuestFlagOn(quest, FLAG_CARRYING_PODLING)
	player:EndEvent()
	quest:StartSequence(SEQ_025)
end

-- Flaxio takes the podling (his talk, or the director on approach); pE30 fades in after the warp out.
function deliverPodling(player, quest, fight, area)
	dropPodling(player, quest)
	delegateCompanion(player, quest, "pE30")
	quest:StartSequence(SEQ_030)
	if fight ~= nil and fight.IsRunning then
		fight:Win("delivered")
	end
	local p = CAMP_RETURN
	leaveQuestContent(player, fight, area, { zone = GROVE_ZONE, x = p[1], y = p[2], z = p[3], rot = p[4] })
end

-- A lost run: the journal goes back to the camp, the podling is lost with it.
function failGroveDuty(player, quest, fight, area)
	dropPodling(player, quest)
	quest:StartSequence(SEQ_015)
	local p = GROVE_LANDING
	leaveQuestContent(player, fight, area, { zone = GROVE_ZONE, x = p[1], y = p[2], z = p[3], rot = p[4] })
end

-- The run is won by the delivery, not by the fight ending.
function onDutyGmWin(player, quest, director, fight)
	local sequence = quest:GetSequence()
	if sequence ~= SEQ_020 and sequence ~= SEQ_025 then
		return
	end
	kickEventContinue(player, director, "noticeEvent", "noticeEvent")
	deliverPodling(player, quest, fight, player.CurrentArea)
end

function onNotice(player, quest, target)
	if quest:GetSequence() == SEQ_030 and currentZoneId(player) == ULDAH_STREET[1] then
		dismissNowLoadingVeil(player, quest)
		if turnInQuest(player, quest, nil) then
			-- Toll of the Warden's accept is a Waking Sands step of its own.
			player:AddQuest(110015, true)
		end
		return
	end
	player:EndEvent()
	quest:UpdateENPCs()
end

-- Tataru's call at 0 (no advance); at 5 the companion's farewell, one personality pack, with the
-- companion's own name as the sender. The last line moves to 10.
function onNpcLS(player, quest, from, msgStep)
	local sequence = quest:GetSequence()
	if from ~= NPCLS_PATH then
		player:EndEvent()
		return
	end
	if sequence == SEQ_000 then
		player:SendGameMessageLocalizedDisplayName(quest, TEXT_TATARU_CALL, MESSAGE_TYPE_NPC_LINKSHELL, TATARU_DISPLAY_ID)
		quest:EndOfNpcLsMsgs()
	elseif sequence == SEQ_005 or sequence == SEQ_010 then
		local step = math.max(1, math.min(msgStep, FAREWELL_LINES))
		local textId = TEXT_FAREWELL_BASE + (companionPersonality(player) - 1) + 9 * (step - 1)
		player:SendGameMessageDisplayName(quest, textId, MESSAGE_TYPE_NPC_LINKSHELL, player:GetSNpcNickname())
		if step >= FAREWELL_LINES then
			quest:EndOfNpcLsMsgs()
			if sequence == SEQ_005 then
				quest:StartSequenceForNpcLs(SEQ_010)
			end
		else
			quest:ReadNpcLsMsg()
		end
	end
	player:EndEvent()
end

-- int6 is the companion's name (journal rows 201-203).
function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0, player:GetSNpcNickname()
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
