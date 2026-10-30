require("Global")
require("Quest")
require("Tutorial")
require("Modifiers")

--[[

Quest Script

Name:   Court in the Sands
Code:   Man0u1
Id:     110010
Prereq: Flowers for All (Man0u0 - 110009)
Notes:


Vid refs -
https://www.youtube.com/watch?v=WNRLrwZ3BJY&t=284s
https://www.youtube.com/watch?v=eZgcq-FMpfw&t=504s

Coliseum fight - https://www.youtube.com/watch?v=Jcv9I2Bk46w

A LOT - https://www.youtube.com/watch?v=gySHO1Be9OM

]]

local setWardCrowd, seq015_checkLegs, wardCrowd_onTalk, startColiseumMatch, startEscort, startContent, endContent, warpTo, giveKeyItem, saveFlag

AFTER_WARP_NOTICE = true

-- Sequence Numbers
SEQ_000 = 0    -- Ul'dah Adventurer's Guild
SEQ_005 = 5    -- Run to Camp Black Brush & Attune
SEQ_010 = 10   -- Return to the Guild
SEQ_012 = 12   -- Speak to Momodi
SEQ_015 = 15   -- Visiting guilds (GSM, GLD)
local SEQ_045 = 45   -- Linette at Amajina & Sons
SEQ_050 = 50   -- F'lhaminn teaches six emotes
local SEQ_057 = 57   -- Calm the manic and the maddened miner
local SEQ_058 = 58   -- F'lhaminn after the miners
SEQ_060 = 60   -- Gate of Nald
SEQ_065 = 65   -- Escort F'lhaminn to Camp Black Brush
SEQ_070 = 70   -- Ascilia at the camp
SEQ_080 = 80   -- The stage at the Concern
SEQ_085 = 85   -- Contact Momodi on LS
SEQ_090 = 90   -- Nogeloix at Frondale's Phrontistery
SEQ_095 = 95   -- The ward door
SEQ_100 = 100  -- The ward rounds
SEQ_105 = 105  -- Contact Momodi on LS
local SEQ_110 = 110  -- Return to Momodi

-- Actor Class Ids
local OVERCOMPETITIVE_ADVENTURER  = 1000807
local MOMODI                      = 1000841
local OTOPA_POTTOPA               = 1000864
local UNDAUNTED_ADVENTURER        = 1000936
local GREEDY_MERCHANT             = 1000937
local LIONHEARTED_ADVENTURER      = 1000938
local SPRY_SALESMAN               = 1000939
local UPBEAT_ADVENTURER           = 1000940
local SEEMINGLY_CALM_ADVENTURER   = 1000941
local THANCRED                    = 1000948

-- Sequence 015
local ELECOTTE                    = 1000950
local HNAUFRID                    = 1000635
local PAMISOLAUX                  = 1600040
local LULUTSU                     = 1000863
local PAPAWA                      = 1000962
local ABYLGO_HAMYLGO              = 1000965
local FRUHYBOLG                   = 1000964
local SWERDAHRM                   = 1000967
local QMHALAWI                    = 1000969
local UNDEFEATED_GLADIATOR        = 1001020
local POORLY_OUTFITTED_GLADIATOR  = 1000995
local DISHEARTENED_GLADIATOR      = 1000999
local AGGRIEVED_GLADIATOR         = 1000997
local ARENA_TRIGGER               = 1090283
local STAIRS_TRIGGER              = 1090286

-- Sequence 045 - 058
local LINETTE                     = 1000861
local SHILGEN                     = 1000637
local TYAGO_MOUI                  = 1001203
local NORTMOEN                    = 1600042
local NITTMA_GUTTMA               = 1001286
local CORGUEVAIS                  = 1001054
local FLHAMINN_SCENE              = 1000842
local MANIC_MINER                 = 1001283
local MADDENED_MINER              = 1001284
local MAUDLIN_MINER               = 1001287
local MOCKING_MINER               = 1001288
local MONITORING_MINER            = 1001289
local DISPLEASED_DANCER           = 1001290
local MUSCULAR_MINER              = 1000690
local CLOSE_FISTED_WOMAN          = 1000981
local ASTONISHED_ADVENTURER       = 1000895

-- Sequence 060 - 070
local GATE_OF_NALD_TRIGGER        = 1090285
local CAMP_ECHO_TRIGGER           = 1090077
local ASCILIA                     = 1000042
local FLHAMINN                    = 1000038
local UNTIDY_OUTLANDER            = 1000808
local MALNOURISHED_MIDLANDER      = 1000809
local HELPLESS_HYUR               = 1000817

-- Sequence 080 - 110
local STAGE_TRIGGER               = 1090288
local NOGELOIX                    = 1000597
local WARD_DOOR                   = 1090119
local WARD_ROUNDS_TRIGGER         = 1090121
local WARD_EXIT_TRIGGER           = 1090120
local SLOW_WITTED_MINER           = 1000689
local QUALMISH_MINER              = 1000699
local WORRISOME_ASSISTANT         = 1001207
local WELL_WASHED_LEECH           = 1001210

-- Quest Markers
local MRKR_MOMODI             = 11001001
local MRKR_CAMP_BLACK_BRUSH   = 11001002
local MRKR_ESHTAIME           = 11001005
local MRKR_COLISEUM           = 11001006
local MRKR_LINETTE            = 11001009
local MRKR_FLHAMINN_TEACH     = 11001010
local MRKR_MANIC_MINER        = 11001011
local MRKR_MADDENED_MINER     = 11001012
local MRKR_GATE_OF_NALD       = 11001014
local MRKR_ASCILIA_CAMP       = 11001015
local MRKR_CONCERN_STAGE      = 11001017
local MRKR_PHRONTISTERY       = 11001018
local MRKR_WARD_DOOR          = 11001019

-- Quest Items
local ITEM_COLISEUM_PASS  = 11000126
local GIL_FLOWER_SOLD     = 2000
local GIL_STAGE_PAID      = 3000

-- Quest Counters
local CNTR_GOLDSMITH = 0 -- 1 once the flower is sold
local CNTR_GLADIATOR = 1 -- 1 recruit scene, 2 pass shown, 3 in the match, 4 match lost, 5 done
local CNTR_TEACH     = 2 -- emotes taught (0 - 6)
local CNTR_MANIC     = 3 -- manic miner progress (0 - 3)

-- Quest Flags
local FLAG_MADDENED_CALMED = 1
local FLAG_STAGE_PAID      = 2

-- Journal values for the flower and Coliseum legs once done.
local JOURNAL_FLOWER_SOLD   = 5
local JOURNAL_COLISEUM_DONE = 15

-- The six taught emotes in teach order: Furious, Beckon, Laugh, Deny, Upset, Soothe.
local EMOTE_STEPS = {
	{ eventName = "emoteDefault1", doEmoteId = 3,  motionMsg = 21021 },
	{ eventName = "emoteDefault2", doEmoteId = 8,  motionMsg = 21071 },
	{ eventName = "emoteDefault3", doEmoteId = 21, motionMsg = 21201 },
	{ eventName = "emoteDefault4", doEmoteId = 25, motionMsg = 21241 },
	{ eventName = "emoteDefault5", doEmoteId = 40, motionMsg = 21391 },
	{ eventName = "emoteDefault6", doEmoteId = 35, motionMsg = 21341 },
}
local MANIC_SEQUENCE = { 6, 1, 3 } -- Soothe, Furious, Laugh
local MADDENED_STEP  = 2           -- Beckon

local MOMODI_DISPLAY_ID = 1500014
local TEXT_KEY_ITEM_OBTAINED = 25117

-- Lines the escort duty sends (QuestDirectorMan0u102)
local TEXT_ESCORT_DANGERS_AHEAD  = 365
local TEXT_ESCORT_NOT_TOO_STRONG = 366
local TEXT_ESCORT_WELL_DONE      = 367
local TEXT_ESCORT_AMAZING        = 368
local TEXT_ESCORT_ARE_YOU_HURT   = 369
local TEXT_ESCORT_IM_HURT        = 371
local TEXT_ESCORT_RETREAT        = 372
local TEXT_ESCORT_SO_CLOSE       = 374
local TEXT_ESCORT_JUST_AHEAD     = 375

-- Msg packs for the Npc LS
NPCLS_MSGS = {
	{320},
	{301, 302, 303},
	{184, 185, 186},
	{307, 308}
}

-- Warp points
local QUICKSAND_ECHO   = { 175, "PrivateAreaMasterPast", 4, -75.242, 195.009, 74.572, -0.046 }
local ARENA_LOBBY_ECHO = { 209, "PrivateAreaMasterPast", 10, -192.241, 194.5, 195.317, -0.008 }
local ARENA_AFTER_ECHO = { 209, "PrivateAreaMasterPast", 6, -177.767, 189.973, 216.744, 3.118 }
local COLISEUM_FLOOR   = { 209, nil, 0, -192.279, 194.5, 203.949, 2.947 }
local TEACH_SCENE      = { 209, "PrivateAreaMasterPast", 5, -94.85, 195.5, 316.685, 2.965 }
local RECOVERED_SCENE  = { 209, "PrivateAreaMasterPast", 8, -106.69, 194.2, 322.54, -0.275 }
local CAMP_ECHO        = { 170, "PrivateAreaMasterPast", 4, 51.855, 200.027, -482.399, -2.953 }
local CAMP_BLACK_BRUSH = { 170, nil, 0, 34.8, 201, -480.5, -1.5 }
local GATE_OF_NALD     = { 170, nil, 0, -34.5, 183, -68.9, -3.0 }
local WARD_ENTRY       = { 180, nil, 0, -204.944, 0, -159.944, 1.591 }
local PHRONTISTERY     = { 209, nil, 0, -215.248, 229.5, 297.833, 2.895 }
local ARENA_FLOOR      = { -199.878, 175.024, 160.217, 1.549 }

local TEACH_CROWD = {
	LINETTE, CORGUEVAIS, NITTMA_GUTTMA, TYAGO_MOUI, SHILGEN, NORTMOEN, MAUDLIN_MINER, MOCKING_MINER,
	MONITORING_MINER, DISPLEASED_DANCER, MUSCULAR_MINER, CLOSE_FISTED_WOMAN, ASTONISHED_ADVENTURER,
}

local WARD_CROWD = { SLOW_WITTED_MINER, MUSCULAR_MINER, QUALMISH_MINER, WORRISOME_ASSISTANT, WELL_WASHED_LEECH }

function onStart(player, quest)
	quest:StartSequence(SEQ_000)

	callClientFunction(player, "delegateEvent", player, quest, "processEventMomodiStart")
	player:SendGameMessage(quest, 329, 0x20)
	player:SendGameMessage(quest, 330, 0x20)
	player:EndEvent()
	warpTo(player, QUICKSAND_ECHO)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	local data = quest:GetData()

	if sequence == SEQ_000 then
		quest:SetENpc(MOMODI, QFLAG_TALK)
		quest:SetENpc(OTOPA_POTTOPA)
		quest:SetENpc(UNDAUNTED_ADVENTURER)
		quest:SetENpc(GREEDY_MERCHANT)
		quest:SetENpc(SPRY_SALESMAN)
		quest:SetENpc(LIONHEARTED_ADVENTURER)
		quest:SetENpc(UPBEAT_ADVENTURER)
		quest:SetENpc(SEEMINGLY_CALM_ADVENTURER)
		quest:SetENpc(OVERCOMPETITIVE_ADVENTURER)
		quest:SetENpc(THANCRED)
	elseif sequence == SEQ_005 then
		quest:SetENpc(MOMODI)
	elseif sequence == SEQ_010 or sequence == SEQ_012 then
		quest:SetENpc(MOMODI, QFLAG_TALK)
	elseif sequence == SEQ_015 then
		local flower = data:GetCounter(CNTR_GOLDSMITH)
		local arena = data:GetCounter(CNTR_GLADIATOR)
		-- Step 3 is mid-match: an abandoned match re-arms the gate for a fresh one.
		local arenaArmed = (arena == 0 or arena == 2 or arena == 3)
		quest:SetENpc(MOMODI)
		quest:SetENpc(ELECOTTE, flower == 0 and QFLAG_TALK or QFLAG_OFF)
		quest:SetENpc(LULUTSU, arena == 1 and QFLAG_TALK or QFLAG_OFF)
		quest:SetENpc(ARENA_TRIGGER, arenaArmed and QFLAG_PUSH or QFLAG_OFF, false, arenaArmed)
		quest:SetENpc(STAIRS_TRIGGER, arena == 4 and QFLAG_PUSH or QFLAG_OFF, false, arena == 4)
		for _, id in ipairs({ HNAUFRID, PAMISOLAUX, PAPAWA, ABYLGO_HAMYLGO, FRUHYBOLG, SWERDAHRM, QMHALAWI,
				UNDEFEATED_GLADIATOR, POORLY_OUTFITTED_GLADIATOR, DISHEARTENED_GLADIATOR, AGGRIEVED_GLADIATOR }) do
			quest:SetENpc(id)
		end
	elseif sequence == SEQ_045 then
		quest:SetENpc(LINETTE, QFLAG_TALK)
	elseif sequence == SEQ_050 then
		quest:SetENpc(FLHAMINN_SCENE, QFLAG_TALK, true, false, true)
		quest:SetENpc(MANIC_MINER)
		quest:SetENpc(MADDENED_MINER)
		for _, id in ipairs(TEACH_CROWD) do
			quest:SetENpc(id)
		end
	elseif sequence == SEQ_057 then
		local manicDone = data:GetCounter(CNTR_MANIC) >= #MANIC_SEQUENCE
		local maddenedOpen = not data:GetFlag(FLAG_MADDENED_CALMED)
		quest:SetENpc(FLHAMINN_SCENE)
		quest:SetENpc(MANIC_MINER, (not manicDone) and QFLAG_TALK or QFLAG_OFF, true, false, not manicDone)
		-- No talk icon until the manic miner is calm, but he still answers an early Beckon.
		quest:SetENpc(MADDENED_MINER, (manicDone and maddenedOpen) and QFLAG_TALK or QFLAG_OFF, true, false, maddenedOpen)
		for _, id in ipairs(TEACH_CROWD) do
			quest:SetENpc(id)
		end
	elseif sequence == SEQ_058 then
		quest:SetENpc(FLHAMINN_SCENE, QFLAG_TALK)
		for _, id in ipairs({ CORGUEVAIS, LINETTE, TYAGO_MOUI, DISPLEASED_DANCER, NITTMA_GUTTMA, MAUDLIN_MINER,
				MONITORING_MINER, MUSCULAR_MINER }) do
			quest:SetENpc(id)
		end
	elseif sequence == SEQ_060 or sequence == SEQ_065 then
		quest:SetENpc(GATE_OF_NALD_TRIGGER, QFLAG_PUSH, false, true)
	elseif sequence == SEQ_070 then
		quest:SetENpc(ASCILIA, QFLAG_TALK)
		quest:SetENpc(CAMP_ECHO_TRIGGER, QFLAG_PUSH, false, true)
		for _, id in ipairs({ CORGUEVAIS, UNTIDY_OUTLANDER, MALNOURISHED_MIDLANDER, HELPLESS_HYUR, FLHAMINN }) do
			quest:SetENpc(id)
		end
	elseif sequence == SEQ_080 then
		quest:SetENpc(STAGE_TRIGGER, QFLAG_PUSH, false, true)
	elseif sequence == SEQ_090 then
		quest:SetENpc(NOGELOIX, QFLAG_TALK)
	elseif sequence == SEQ_095 then
		quest:SetENpc(WARD_DOOR, QFLAG_PUSH, false, true)
	elseif sequence == SEQ_100 then
		quest:SetENpc(WARD_ROUNDS_TRIGGER, QFLAG_PUSH, false, true)
		-- For a player who left the ward: Nogeloix sends them in again.
		quest:SetENpc(NOGELOIX, QFLAG_TALK)
		setWardCrowd(quest)
	elseif sequence == SEQ_105 then
		quest:SetENpc(WARD_EXIT_TRIGGER, QFLAG_OFF, false, true)
		-- Momodi lights the pearl again for a player who lost the call.
		if data:GetNpcLsFrom() == 0 then
			quest:SetENpc(MOMODI, QFLAG_TALK)
		end
		setWardCrowd(quest)
	elseif sequence == SEQ_110 then
		quest:SetENpc(MOMODI, QFLAG_REWARD)
		quest:SetENpc(WARD_EXIT_TRIGGER, QFLAG_OFF, false, true)
		setWardCrowd(quest)
	end
end

function setWardCrowd(quest)
	for _, id in ipairs(WARD_CROWD) do
		quest:SetENpc(id)
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	local data = quest:GetData()

	if sequence == SEQ_000 then
		if seq000_onTalk(player, quest, npc, classId) == true then
			return
		end
	elseif sequence == SEQ_005 then
		if classId == MOMODI then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_2")
		end
	elseif sequence == SEQ_010 then
		if classId == MOMODI then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent015")
			player:EndEvent()
			quest:StartSequence(SEQ_012)
			return
		end
	elseif sequence == SEQ_012 then
		if classId == MOMODI then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent017")
			giveKeyItem(player, ITEM_COLISEUM_PASS)
			player:EndEvent()
			quest:StartSequence(SEQ_015)
			return
		end
	elseif sequence == SEQ_015 then
		seq015_onTalk(player, quest, npc, classId)
	elseif sequence == SEQ_045 then
		if classId == LINETTE then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050")
			player:EndEvent()
			quest:StartSequence(SEQ_050)
			warpTo(player, TEACH_SCENE)
			return
		end
	elseif sequence == SEQ_050 then
		if classId == FLHAMINN_SCENE then
			local step = data:GetCounter(CNTR_TEACH)
			callClientFunction(player, "delegateEvent", player, quest, step < #EMOTE_STEPS and ("processEvent051_" .. (step + 1)) or "processEvent051_8")
		else
			seq050_onTalk(player, quest, npc, classId)
		end
	elseif sequence == SEQ_057 then
		if classId == FLHAMINN_SCENE then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent051_8")
		elseif classId == MADDENED_MINER then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050_14")
		elseif classId == MANIC_MINER then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050_13")
		else
			seq050_onTalk(player, quest, npc, classId)
		end
	elseif sequence == SEQ_058 then
		if classId == FLHAMINN_SCENE then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent070")
			player:EndEvent()
			quest:StartSequence(SEQ_060)
			warpTo(player, { 209, nil, 0, player.positionX, player.positionY, player.positionZ, player.rotation })
			return
		end
		callClientFunction(player, "delegateEvent", player, quest, "processEvent060_7")
	elseif sequence == SEQ_070 then
		if classId == ASCILIA then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent090")
			player:EndEvent()
			quest:StartSequence(SEQ_080)
			warpTo(player, CAMP_BLACK_BRUSH)
			return
		elseif classId == CORGUEVAIS or classId == FLHAMINN or classId == HELPLESS_HYUR
				or classId == MALNOURISHED_MIDLANDER or classId == UNTIDY_OUTLANDER then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent080_2")
		end
	elseif sequence == SEQ_090 or sequence == SEQ_100 then
		if classId == NOGELOIX then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent210")
			player:EndEvent()
			quest:StartSequence(SEQ_095)
			return
		end
		wardCrowd_onTalk(player, quest, classId)
	elseif sequence == SEQ_105 then
		if classId == MOMODI then
			quest:NewNpcLsMsg(1)
		else
			wardCrowd_onTalk(player, quest, classId)
		end
	elseif sequence == SEQ_110 then
		if classId == MOMODI then
			callClientFunction(player, "delegateEvent", player, quest, "processEventComplete")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 300, 1, 1, 2)
			player:EndEvent()
			player:CompleteQuest(quest)
			return
		end
		wardCrowd_onTalk(player, quest, classId)
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function seq000_onTalk(player, quest, npc, classId)
	if classId == MOMODI then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010")
		quest:NewNpcLsMsg(1)
		quest:StartSequence(SEQ_005)
		player:EndEvent()

		-- The linkpearl tutorial plays from the after-warp notice once the player is out of the echo.
		local director = GetWorldManager():GetArea(175):CreateDirector("AfterQuestWarpDirector", false)
		player:AddDirector(director)
		director:StartDirector(true)
		player:SetLoginDirector(director)
		player:KickEvent(director, "noticeEvent", true)

		GetWorldManager():DoZoneChange(player, 175, nil, 0, 15, player.positionX, player.positionY, player.positionZ, player.rotation)
		return true
	elseif classId == UNDAUNTED_ADVENTURER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2")
	elseif classId == GREEDY_MERCHANT then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_3")
	elseif classId == SPRY_SALESMAN then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_4")
	elseif classId == LIONHEARTED_ADVENTURER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_5")
	elseif classId == UPBEAT_ADVENTURER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_6")
	elseif classId == SEEMINGLY_CALM_ADVENTURER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_7")
	elseif classId == OVERCOMPETITIVE_ADVENTURER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_8")
	elseif classId == OTOPA_POTTOPA then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_9")
	elseif classId == THANCRED then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_10")
	end
end

function seq015_onTalk(player, quest, npc, classId)
	local data = quest:GetData()
	local flower = data:GetCounter(CNTR_GOLDSMITH)
	local arena = data:GetCounter(CNTR_GLADIATOR)

	if classId == MOMODI then
		if flower >= 1 and arena < 5 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent017_3")
		elseif arena >= 5 and flower == 0 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent017_4")
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent017_2")
		end
	elseif classId == ELECOTTE then
		if flower == 0 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020")
			saveCounter(quest, CNTR_GOLDSMITH, 1)
			player:GetItemPackage(INVENTORY_CURRENCY):AddItem(1000001, GIL_FLOWER_SOLD, 1)
			seq015_checkLegs(quest)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_2")
		end
	elseif classId == LULUTSU then
		if arena == 1 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030_2")
			saveCounter(quest, CNTR_GLADIATOR, 2)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent1000_1")
		end
	elseif classId == ABYLGO_HAMYLGO then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030_3")
	elseif classId == PAPAWA then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030_4")
	elseif classId == FRUHYBOLG then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030_5")
	elseif classId == SWERDAHRM then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030_6")
	elseif classId == QMHALAWI then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030_7")
	elseif classId == AGGRIEVED_GLADIATOR then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030_8")
	elseif classId == UNDEFEATED_GLADIATOR then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030_9")
	elseif classId == POORLY_OUTFITTED_GLADIATOR then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030_10")
	elseif classId == DISHEARTENED_GLADIATOR then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030_11")
	elseif classId == HNAUFRID then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent032_2")
	elseif classId == PAMISOLAUX then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent032_3")
	end
end

-- Both legs done, in either order: Momodi's call.
function seq015_checkLegs(quest)
	local data = quest:GetData()
	if data:GetCounter(CNTR_GOLDSMITH) >= 1 and data:GetCounter(CNTR_GLADIATOR) >= 5 then
		quest:NewNpcLsMsg(1)
	end
end

function seq050_onTalk(player, quest, npc, classId)
	if classId == LINETTE then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_2")
	elseif classId == MAUDLIN_MINER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_3")
	elseif classId == MOCKING_MINER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_4")
	elseif classId == MONITORING_MINER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_5")
	elseif classId == DISPLEASED_DANCER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_6")
	elseif classId == MUSCULAR_MINER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_7")
	elseif classId == CLOSE_FISTED_WOMAN then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_8")
	elseif classId == ASTONISHED_ADVENTURER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_9")
	elseif classId == NITTMA_GUTTMA then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_10")
	elseif classId == CORGUEVAIS then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_11")
	elseif classId == TYAGO_MOUI then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_12")
	elseif classId == MANIC_MINER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_13")
	elseif classId == MADDENED_MINER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_14")
	elseif classId == SHILGEN or classId == NORTMOEN then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent051_8")
	end
end

function wardCrowd_onTalk(player, quest, classId)
	if classId == WORRISOME_ASSISTANT then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent210_3")
	elseif classId == WELL_WASHED_LEECH then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent210_5")
	elseif classId == QUALMISH_MINER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent210_6")
	elseif classId == MUSCULAR_MINER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent210_7")
	elseif classId == SLOW_WITTED_MINER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent210_8")
	end
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	local data = quest:GetData()

	if sequence == SEQ_015 then
		local arena = data:GetCounter(CNTR_GLADIATOR)
		if classId == ARENA_TRIGGER and arena == 0 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030")
			player:EndEvent()
			saveCounter(quest, CNTR_GLADIATOR, 1)
			quest:UpdateENPCs()
			warpTo(player, ARENA_LOBBY_ECHO)
			return
		elseif classId == ARENA_TRIGGER and (arena == 2 or arena == 3) then
			if callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass") == 1 then
				startColiseumMatch(player, quest)
				return
			end
		elseif classId == STAIRS_TRIGGER and arena == 4 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040")
			player:EndEvent()
			saveCounter(quest, CNTR_GLADIATOR, 5)
			seq015_checkLegs(quest)
			quest:UpdateENPCs()
			warpTo(player, COLISEUM_FLOOR)
			return
		end
	elseif sequence == SEQ_060 or sequence == SEQ_065 then
		if classId == GATE_OF_NALD_TRIGGER then
			if callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass") == 1 then
				startEscort(player, quest)
				return
			end
		end
	elseif sequence == SEQ_070 then
		-- The escort's arrival plays this scene; the trigger is for a player left outside the echo.
		if classId == CAMP_ECHO_TRIGGER and not player.CurrentArea:IsPrivate() then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent080")
			player:EndEvent()
			warpTo(player, CAMP_ECHO)
			return
		end
	elseif sequence == SEQ_080 then
		if classId == STAGE_TRIGGER then
			local alreadyPaid = data:GetFlag(FLAG_STAGE_PAID)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent205")
			player:EndEvent()
			saveFlag(quest, FLAG_STAGE_PAID)
			quest:StartSequence(SEQ_085)
			quest:NewNpcLsMsg(1)
			-- Paid on the flag, not the step: a disconnect mid-scene replays it without paying again.
			if not alreadyPaid then
				player:GetItemPackage(INVENTORY_CURRENCY):AddItem(1000001, GIL_STAGE_PAID, 1)
			end
			warpTo(player, { 209, nil, 0, player.positionX, player.positionY, player.positionZ, player.rotation })
			return
		end
	elseif sequence == SEQ_095 then
		if classId == WARD_DOOR then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent220")
			player:EndEvent()
			quest:StartSequence(SEQ_100)
			warpTo(player, WARD_ENTRY)
			return
		end
	elseif sequence == SEQ_100 then
		if classId == WARD_ROUNDS_TRIGGER then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent230")
			player:EndEvent()
			quest:StartSequence(SEQ_105)
			quest:NewNpcLsMsg(1)
			return
		end
	elseif sequence == SEQ_105 or sequence == SEQ_110 then
		if classId == WARD_EXIT_TRIGGER then
			player:EndEvent()
			warpTo(player, PHRONTISTERY)
			return
		end
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onEmote(player, quest, npc, eventName)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	local data = quest:GetData()

	local performed = nil
	for i, step in ipairs(EMOTE_STEPS) do
		if step.eventName == eventName then
			performed = i
		end
	end
	if performed == nil then
		player:EndEvent()
		return
	end
	player:DoEmote(npc.Id, EMOTE_STEPS[performed].doEmoteId, EMOTE_STEPS[performed].motionMsg)
	wait(2.5)

	if sequence == SEQ_050 and classId == FLHAMINN_SCENE then
		local step = data:GetCounter(CNTR_TEACH)
		if step < #EMOTE_STEPS and performed == step + 1 then
			-- Her answer demonstrates the next emote; after the last she sends the player to the miners.
			callClientFunction(player, "delegateEvent", player, quest, (step + 1 < #EMOTE_STEPS) and ("processEvent051_" .. (step + 2)) or "processEvent051_8")
			saveCounter(quest, CNTR_TEACH, step + 1)
			if step + 1 >= #EMOTE_STEPS then
				player:EndEvent()
				quest:StartSequence(SEQ_057)
				return
			end
		elseif step < #EMOTE_STEPS then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent051_7", 50 + step + 1)
		end
	elseif sequence == SEQ_057 then
		local manic = data:GetCounter(CNTR_MANIC)
		if classId == MANIC_MINER and manic < #MANIC_SEQUENCE then
			if performed == MANIC_SEQUENCE[manic + 1] then
				saveCounter(quest, CNTR_MANIC, manic + 1)
			else
				callClientFunction(player, "delegateEvent", player, quest, "processEvent055_" .. ((performed % 3) + 1))
			end
		elseif classId == MADDENED_MINER and not data:GetFlag(FLAG_MADDENED_CALMED) then
			-- He answers only once the manic miner is calm.
			if manic >= #MANIC_SEQUENCE and performed == MADDENED_STEP then
				saveFlag(quest, FLAG_MADDENED_CALMED)
			else
				callClientFunction(player, "delegateEvent", player, quest, "processEvent056_" .. ((performed % 3) + 1))
			end
		end

		if data:GetFlag(FLAG_MADDENED_CALMED) and data:GetCounter(CNTR_MANIC) >= #MANIC_SEQUENCE then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060")
			player:EndEvent()
			quest:StartSequence(SEQ_058)
			warpTo(player, RECOVERED_SCENE)
			return
		end
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onNotice(player, quest, target)
	local sequence = quest:GetSequence()
	if sequence == SEQ_000 then
		-- Describes what an instance is. The client sends no reply to it, so don't wait for one.
		player:RunEventFunction("delegateEvent", player, quest, "processEvent000_1")
	elseif sequence == SEQ_005 then
		callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting")
		callClientFunction(player, "delegateEvent", player, quest, "processEventTu_001")
	end
	player:EndEvent()
	quest:UpdateENPCs()
end

function onNpcLS(player, quest, from, msgStep)
	local sequence = quest:GetSequence()
	local msgPack

	if from == 1 then
		if sequence == SEQ_005 or sequence == SEQ_010 or sequence == SEQ_012 then
			msgPack = 1
		elseif sequence == SEQ_015 or sequence == SEQ_045 then
			msgPack = 2
		elseif sequence == SEQ_085 or sequence == SEQ_090 then
			msgPack = 3
		elseif sequence == SEQ_105 or sequence == SEQ_110 then
			msgPack = 4
		end

		if msgPack == nil then
			player:EndEvent()
			return
		end

		local msgs = NPCLS_MSGS[msgPack]
		local step = math.max(1, math.min(msgStep, #msgs))
		player:SendGameMessageLocalizedDisplayName(quest, msgs[step], MESSAGE_TYPE_NPC_LINKSHELL, MOMODI_DISPLAY_ID)
		if step >= #msgs then
			quest:EndOfNpcLsMsgs()
		else
			quest:ReadNpcLsMsg()
		end

		if msgPack == 1 then
			showTutorialSuccessWidget(player, 9080)
			closeTutorialWidget(player)
			endTutorialMode(player)
		elseif sequence == SEQ_015 then
			quest:StartSequenceForNpcLs(SEQ_045)
		elseif sequence == SEQ_085 then
			quest:StartSequenceForNpcLs(SEQ_090)
		elseif sequence == SEQ_105 then
			quest:StartSequenceForNpcLs(SEQ_110)
		end
	end

	player:EndEvent()
end

function startColiseumMatch(player, quest)
	saveCounter(quest, CNTR_GLADIATOR, 3)
	quest:UpdateENPCs()
	local f = ARENA_FLOOR
	startContent(player, 209, "SimpleContentMan0u101", "Quest/QuestDirectorMan0u101", f[1], f[2], f[3], f[4])
end

-- Called by QuestDirectorMan0u101 from its noticeEvent.
function finishColiseumMatch(player, quest, duty, contentArea)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent035")
	saveCounter(quest, CNTR_GLADIATOR, 4)
	quest:UpdateENPCs()
	endContent(player, duty, contentArea)
	warpTo(player, ARENA_AFTER_ECHO)
end

function startEscort(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent075")
	if quest:GetSequence() ~= SEQ_065 then
		quest:StartSequence(SEQ_065)
	end
	local g = GATE_OF_NALD
	startContent(player, 170, "SimpleContentMan0u102", "Quest/QuestDirectorMan0u102", g[4], g[5], g[6], g[7])
end

-- Called by QuestDirectorMan0u102 from its noticeEvent.
function finishEscort(player, quest, duty, contentArea)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent080")
	quest:StartSequence(SEQ_070)
	endContent(player, duty, contentArea)
	warpTo(player, CAMP_ECHO)
end

function failEscort(player, quest, duty, contentArea)
	player:SendGameMessage(quest, TEXT_ESCORT_IM_HURT, 0x20)
	player:SendGameMessage(quest, TEXT_ESCORT_RETREAT, 0x20)
	player:SetHP(player:GetMaxHP())
	endContent(player, duty, contentArea)
	warpTo(player, GATE_OF_NALD)
end

function startContent(player, zoneId, contentName, directorName, x, y, z, rot)
	local contentArea = GetWorldManager():GetZone(zoneId):CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", string.lower(contentName), contentName, directorName)
	if contentArea == nil then
		player:EndEvent()
		return
	end

	local director = contentArea:GetContentDirector()
	player:AddDirector(director)
	director:StartDirector(false)
	player:SetLoginDirector(director)
	player:EndEvent()
	-- The kick must ride the warp: sent earlier, the client's notice record is corrupted.
	player:KickEvent(director, "noticeEvent", true)
	GetWorldManager():DoZoneChangeContent(player, contentArea, x, y, z, rot, 15)
end

function endContent(player, duty, contentArea)
	player:SetMod(Modifier.MinimumHpLock, 0)
	player:EndEvent()
	if duty ~= nil then
		duty:Close()
	end
	if contentArea ~= nil then
		pcall(function() contentArea:ContentFinished() end)
	end
end

function warpTo(player, p)
	GetWorldManager():DoZoneChange(player, p[1], p[2], p[3], 15, p[4], p[5], p[6], p[7])
end

function giveKeyItem(player, itemId)
	local keyItems = player:GetItemPackage(INVENTORY_KEYITEMS)
	if not keyItems:HasItem(itemId) then
		keyItems:AddItem(itemId, 1, 1)
		player:SendGameMessage(GetWorldMaster(), TEXT_KEY_ITEM_OBTAINED, 0x20, itemId)
	end
end

function saveCounter(quest, counter, value)
	local data = quest:GetData()
	data:SetCounter(counter, value)
	data:Save()
end

function saveFlag(quest, flag)
	local data = quest:GetData()
	data:SetFlag(flag)
	data:Save()
end

function getJournalInformation(player, quest)
	local sequence = quest:GetSequence()
	local data = quest:GetData()
	local attuned = (sequence >= SEQ_010) and 1 or 0
	local flower = 0
	local coliseum = 0
	if sequence > SEQ_015 or data:GetCounter(CNTR_GOLDSMITH) >= 1 then
		flower = JOURNAL_FLOWER_SOLD
	end
	if sequence > SEQ_015 or data:GetCounter(CNTR_GLADIATOR) >= 4 then
		coliseum = JOURNAL_COLISEUM_DONE
	end
	return attuned, flower, coliseum
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	local data = quest:GetData()
	local possibleMarkers = {}

	if sequence == SEQ_000 or sequence == SEQ_010 or sequence == SEQ_012 then
		table.insert(possibleMarkers, MRKR_MOMODI)
	elseif sequence == SEQ_005 or sequence == SEQ_065 then
		table.insert(possibleMarkers, MRKR_CAMP_BLACK_BRUSH)
	elseif sequence == SEQ_015 then
		if data:GetCounter(CNTR_GOLDSMITH) == 0 then
			table.insert(possibleMarkers, MRKR_ESHTAIME)
		end
		if data:GetCounter(CNTR_GLADIATOR) < 5 then
			table.insert(possibleMarkers, MRKR_COLISEUM)
		end
	elseif sequence == SEQ_045 then
		table.insert(possibleMarkers, MRKR_LINETTE)
	elseif sequence == SEQ_050 then
		table.insert(possibleMarkers, MRKR_FLHAMINN_TEACH)
	elseif sequence == SEQ_057 then
		if data:GetCounter(CNTR_MANIC) < #MANIC_SEQUENCE then
			table.insert(possibleMarkers, MRKR_MANIC_MINER)
		elseif not data:GetFlag(FLAG_MADDENED_CALMED) then
			table.insert(possibleMarkers, MRKR_MADDENED_MINER)
		end
	elseif sequence == SEQ_060 then
		table.insert(possibleMarkers, MRKR_GATE_OF_NALD)
	elseif sequence == SEQ_070 then
		table.insert(possibleMarkers, MRKR_ASCILIA_CAMP)
	elseif sequence == SEQ_080 then
		table.insert(possibleMarkers, MRKR_CONCERN_STAGE)
	elseif sequence == SEQ_090 or sequence == SEQ_100 then
		table.insert(possibleMarkers, MRKR_PHRONTISTERY)
	elseif sequence == SEQ_095 then
		table.insert(possibleMarkers, MRKR_WARD_DOOR)
	elseif sequence == SEQ_110 then
		table.insert(possibleMarkers, MRKR_MOMODI)
	end

	return unpack(possibleMarkers)
end
