require("Global")
require("Quest")
require("Tutorial")
require("Modifiers")

--[[
Treasures of the Main (Man0l1, 110002). Prereq: Shapeless Melody (Man0l0).
--]]

local seq007OnTalk, seq007EndSequence, seq080085OnTalk, startMan0l1Content

AFTER_WARP_NOTICE = true

-- Sequence Numbers
SEQ_000	= 0  	-- (Private Area) Drowning Wench Echo Scene.
SEQ_003	= 3  	-- Go attune to Camp Bearded Rock.
SEQ_005	= 5  	-- Attuned, go back to Baderon. Info: <param1> If 1, Baderon gave you a tutorial guildleve else 0.
local SEQ_006	= 6  	-- Talk to Baderon again
local SEQ_007	= 7  	-- Find the CUL and MSK Guilds. Info: Params '0,5,20' will show the msg that you visited both guilds and to notify Baderon on the LS.
local SEQ_035	= 35	-- Go to the FSH Guild.
SEQ_040	= 40	-- Learn hand signals from the guild
local SEQ_048	= 48	-- Travel to Zephyr Gate
SEQ_050	= 50	-- Escort mission
SEQ_055	= 55	-- Search lighthouse for corpse
SEQ_060	= 60	-- Talk to Sisipu
SEQ_065	= 65	-- Return to FSH Guild
SEQ_070	= 70	-- Contact Baderon on LS
SEQ_075	= 75	-- Go to the ARM and BSM Guilds. Talk to Bodenolf.
SEQ_080	= 80	-- Speak with H'naanza
SEQ_085	= 85	-- Walk into push trigger
SEQ_090	= 90	-- Contact Baderon on LS
local SEQ_092	= 92	-- Return to Baderon.

-- Actor Class Ids
-- Echo in Adv Guild
local YSHTOLA 				= 1000001
local CRAPULOUS_ADVENTURER 	= 1000075
local DUPLICITOUS_TRADER	 	= 1000076
local DEBONAIR_PIRATE 		= 1000077
local ONYXHAIRED_ADVENTURER	= 1000098
local SKITTISH_ADVENTURER		= 1000099
local RELAXING_ADVENTURER 	= 1000100
local BADERON 				= 1000137
local MYTESYN 				= 1000167
local COCKAHOOP_COCKSWAIN 	= 1001643
local SENTENIOUS_SELLSWORD 	= 1001649
local SOLICITOUS_SELLSWORD 	= 1001650

-- Sequence 003
local BEARDEDROCK_AETHERYTE	= 1280002

-- Sequence 007
local CHARLYS					= 1000138
local ISANDOREL				= 1000152
local MERLZIRN				= 1000472
local MSK_TRIGGER				= 1090001

-- Echo in MSK Guild
local NERVOUS_BARRACUDA		= 1000096
local INTIMIDATING_BARRACUDA	= 1000097
local OVEREAGER_BARRACUDA		= 1000107
local SOPHISTICATED_BARRACUDA	= 1000108
local SMIRKING_BARRACUDA		= 1000109
local MANNSKOEN				= 1000142
local TOTORUTO				= 1000161
local ADVENTURER1				= 1000869
local ADVENTURER2				= 1000870
local ADVENTURER3				= 1000871
local ECHO_EXIT_TRIGGER		= 1090003

-- Fsh Guild
local NNMULIKA				= 1000153
local SISIPU_EMOTE			= 1000155
local ZEPHYR_TRIGGER			= 1090004

-- Sequence 055, 060, 065
local SISIPU					= 1000156
local WINDWORN_CORPSE			= 1000091
local GLASSYEYED_CORPSE		= 1000092
local FEARSTRICKEN_CORPSE		= 1000378
local FSH_TRIGGER				= 1090006

-- Echo in the Bsm Guild
local TATTOOED_PIRATE			= 1000111
local IOFA					= 1000135
local BODENOLF				= 1000144
local HNAANZA					= 1000145
local MIMIDOA					= 1000176
local JOELLAUT				= 1000163
local WERNER					= 1000247
local HIHINE					= 1000267
local TRINNE					= 1000268
local ECHO_EXIT_TRIGGER2		= 1090007

-- Quest Markers (block 110001nn: the Limsa opening's two blocks are swapped)
local MRKR_BADERON            = 11000101
local MRKR_BEARDED_ROCK       = 11000102
local MRKR_BADERON2           = 11000103
local MRKR_CHARLYS            = 11000104
local MRKR_ISANDOREL          = 11000105
local MRKR_MSK_TRIGGER        = 11000106
local MRKR_ISANDOREL2         = 11000107
local MRKR_ECHO_EXIT          = 11000108
local MRKR_NNMULIKA           = 11000109
local MRKR_SISIPU_EMOTE       = 11000110
local MRKR_ZEPHYR_TRIGGER     = 11000111
local MRKR_OSCHONS_TORCH      = 11000112
local MRKR_WINDWORN_CORPSE    = 11000113
local MRKR_SISIPU             = 11000114
local MRKR_BODENOLF           = 11000115
local MRKR_HNAANZA            = 11000116
local MRKR_ECHO_EXIT2         = 11000117
local MRKR_BADERON3           = 11000118
local MRKR_FSH_TRIGGER        = 11000119

-- Quest Data
local CNTR_SEQ7_CUL		= 1
local CNTR_SEQ7_MSK		= 2
local CNTR_SEQ40_FSH		= 3
local CNTR_LS_MSG			= 4

local ITEM_BADERONS_RECOMMENDATION = 11000125
local GIL_CUL_PAID		= 2000
local GIL_FSH_PAID		= 3000

local TEXT_LINKPEARL_TUTORIAL		= 333
local TEXT_LINKPEARL_MENU_HINT	= 334

-- Msg packs for the Npc LS
NPCLS_MSGS = {
	{339},
	{80, 81, 82},
	{131, 326, 132},
	{161, 162, 163, 164}
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)

	callClientFunction(player, "delegateEvent", player, quest, "processEvent010")
	player:SendGameMessage(quest, 320, 0x20)
	player:SendGameMessage(quest, 321, 0x20)
	player:EndEvent()
	GetWorldManager():DoZoneChange(player, 133, "PrivateAreaMasterPast", 2, 15, -459.619873, 40.0005722, 196.370377, 2.010813)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	local data = quest:GetData()

	if sequence == SEQ_000 then
		quest:SetENpc(YSHTOLA)
		quest:SetENpc(CRAPULOUS_ADVENTURER)
		quest:SetENpc(DUPLICITOUS_TRADER)
		quest:SetENpc(DEBONAIR_PIRATE)
		quest:SetENpc(ONYXHAIRED_ADVENTURER)
		quest:SetENpc(SKITTISH_ADVENTURER)
		quest:SetENpc(RELAXING_ADVENTURER)
		quest:SetENpc(BADERON, QFLAG_TALK)
		quest:SetENpc(MYTESYN)
		quest:SetENpc(COCKAHOOP_COCKSWAIN)
		quest:SetENpc(SENTENIOUS_SELLSWORD)
		quest:SetENpc(SOLICITOUS_SELLSWORD)
	elseif sequence == SEQ_003 then
		quest:SetENpc(BADERON)
	elseif sequence == SEQ_005 then
		quest:SetENpc(BADERON, QFLAG_TALK)
	elseif sequence == SEQ_006 then
		quest:SetENpc(BADERON, QFLAG_TALK)
	elseif sequence == SEQ_007 then
		local subseqCul = data:GetCounter(CNTR_SEQ7_CUL)
		local subseqMsk = data:GetCounter(CNTR_SEQ7_MSK)
		-- Always active in this seqence
		quest:SetENpc(BADERON)
		quest:SetENpc(CHARLYS, subseqCul == 0 and QFLAG_TALK or QFLAG_OFF)
		-- Down and Up the MSK guild
		quest:SetENpc(ISANDOREL, (subseqMsk == 0 or subseqMsk == 2) and QFLAG_TALK or QFLAG_OFF)
		if subseqMsk == 1 then
			quest:SetENpc(MSK_TRIGGER, QFLAG_PUSH, false, true)
		elseif subseqMsk == 2 then
			quest:SetENpc(MERLZIRN)
		end
		-- In Echo
		quest:SetENpc(NERVOUS_BARRACUDA)
		quest:SetENpc(INTIMIDATING_BARRACUDA)
		quest:SetENpc(OVEREAGER_BARRACUDA)
		quest:SetENpc(SOPHISTICATED_BARRACUDA)
		quest:SetENpc(SMIRKING_BARRACUDA)
		quest:SetENpc(MANNSKOEN)
		quest:SetENpc(TOTORUTO)
		quest:SetENpc(ADVENTURER1)
		quest:SetENpc(ADVENTURER2)
		quest:SetENpc(ADVENTURER3)
		quest:SetENpc(ECHO_EXIT_TRIGGER, subseqMsk == 3 and QFLAG_PUSH or QFLAG_OFF, false, subseqMsk == 3)
	elseif sequence == SEQ_035 then
		quest:SetENpc(NNMULIKA, QFLAG_TALK)
	elseif sequence == SEQ_040 then
		quest:SetENpc(SISIPU_EMOTE, QFLAG_TALK, true, false, true)
		quest:SetENpc(NNMULIKA)
	elseif sequence == SEQ_048 then
		quest:SetENpc(BADERON)
		quest:SetENpc(ZEPHYR_TRIGGER, QFLAG_PUSH, false, true)
		quest:SetENpc(NNMULIKA)
	elseif sequence == SEQ_050 then
		quest:SetENpc(ZEPHYR_TRIGGER, QFLAG_PUSH, false, true)
	elseif sequence == SEQ_055 then
		quest:SetENpc(WINDWORN_CORPSE, QFLAG_TALK)
		quest:SetENpc(GLASSYEYED_CORPSE)
		quest:SetENpc(FEARSTRICKEN_CORPSE)
		quest:SetENpc(SISIPU)
	elseif sequence == SEQ_060 then
		quest:SetENpc(SISIPU, QFLAG_TALK)
		quest:SetENpc(WINDWORN_CORPSE)
		quest:SetENpc(GLASSYEYED_CORPSE)
		quest:SetENpc(FEARSTRICKEN_CORPSE)
	elseif sequence == SEQ_065 then
		quest:SetENpc(FSH_TRIGGER, QFLAG_PUSH, false, true)
	elseif sequence == SEQ_075 then
		quest:SetENpc(BODENOLF, QFLAG_TALK)
	elseif sequence == SEQ_080 then
		quest:SetENpc(HNAANZA, QFLAG_TALK)
		quest:SetENpc(TATTOOED_PIRATE)
		quest:SetENpc(IOFA)
		quest:SetENpc(BODENOLF)
		quest:SetENpc(MIMIDOA)
		quest:SetENpc(JOELLAUT)
		quest:SetENpc(WERNER)
		quest:SetENpc(HIHINE)
		quest:SetENpc(TRINNE)
	elseif sequence == SEQ_085 then
		quest:SetENpc(HNAANZA)
		quest:SetENpc(TATTOOED_PIRATE)
		quest:SetENpc(WERNER)
		quest:SetENpc(HIHINE)
		quest:SetENpc(TRINNE)
		quest:SetENpc(ECHO_EXIT_TRIGGER2, QFLAG_PUSH, false, true)
	elseif sequence == SEQ_092 then
		quest:SetENpc(BADERON, QFLAG_REWARD)
	end

end

local function delegate(event)
	return function(player, quest)
		callClientFunction(player, "delegateEvent", player, quest, event)
	end
end

-- Inside these steps every talk closes the event once more before the usual ending.
local function endEvent(player)
	player:EndEvent()
end

local function delegateAndEnd(event)
	return function(player, quest)
		callClientFunction(player, "delegateEvent", player, quest, event)
		player:EndEvent()
	end
end

local function bsmEchoTalk(player, quest, npc)
	seq080085OnTalk(player, quest, npc, npc:GetActorClassId())
end

local function sisipuEmoteTalk(player, quest)
	local emoteTestStep = quest:GetData():GetCounter(CNTR_SEQ40_FSH)
	if emoteTestStep == 0 or emoteTestStep == 1 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent601_1")
		player:SendGameMessage(GetWorldMaster(), 25083, MESSAGE_TYPE_SYSTEM, 1)
		if emoteTestStep == 0 then
			saveCounter(quest, CNTR_SEQ40_FSH, 1)
		end
	elseif emoteTestStep == 2 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent601_2")
		player:SendGameMessage(GetWorldMaster(), 25083, MESSAGE_TYPE_SYSTEM, 1)
	elseif emoteTestStep == 3 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent601_3")
		player:SendGameMessage(GetWorldMaster(), 25083, MESSAGE_TYPE_SYSTEM, 1)
	elseif emoteTestStep == 4 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent601_4")
		player:SendGameMessage(GetWorldMaster(), 25083, MESSAGE_TYPE_SYSTEM, 1)
	elseif emoteTestStep == 5 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent601_5")
		player:SendGameMessage(GetWorldMaster(), 25083, MESSAGE_TYPE_SYSTEM, 1)
	elseif emoteTestStep == 6 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent601_6")
		player:SendGameMessage(GetWorldMaster(), 25083, MESSAGE_TYPE_SYSTEM, 1)
	end
	player:EndEvent()
end

local talk = {
	[SEQ_000] = {
		other = function(player, quest, npc)
			return seq000OnTalk(player, quest, npc, npc:GetActorClassId()) == true
		end,
	},
	[SEQ_003] = { [BADERON] = delegateAndEnd("processEvent020_2") },
	[SEQ_005] = {
		[BADERON] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent026")
			player:EndEvent()
			quest:StartSequence(SEQ_006)
		end,
	},
	[SEQ_006] = {
		[BADERON] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent027")
			player:EndEvent()
			local keyItems = player:GetItemPackage(INVENTORY_KEYITEMS)
			if not keyItems:HasItem(ITEM_BADERONS_RECOMMENDATION) then
				keyItems:AddItem(ITEM_BADERONS_RECOMMENDATION, 1, 1)
				player:SendGameMessage(GetWorldMaster(), 25117, 0x20, ITEM_BADERONS_RECOMMENDATION) -- You obtain Baderon's Recommendation
			end
			quest:StartSequence(SEQ_007)
		end,
	},
	[SEQ_007] = {
		other = function(player, quest, npc)
			return seq007OnTalk(player, quest, npc, npc:GetActorClassId()) == true
		end,
	},
	[SEQ_035] = {
		[NNMULIKA] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent600")
			quest:StartSequence(SEQ_040)
			player:EndEvent()
			warpToEcho(player, 230, 5)
			return true
		end,
	},
	[SEQ_040] = {
		[SISIPU_EMOTE] = sisipuEmoteTalk,
		[NNMULIKA] = delegateAndEnd("processEvent600_2"),
		other = endEvent,
	},
	[SEQ_048] = {
		[BADERON] = delegateAndEnd("processEvent602_3"),
		[NNMULIKA] = delegateAndEnd("processEvent602_2"),
		other = endEvent,
	},
	[SEQ_055] = {
		[SISIPU] = delegateAndEnd("processEvent605_2"),
		[WINDWORN_CORPSE] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent610")
			player:EndEvent()
			quest:StartSequence(SEQ_060)
			return true
		end,
		[FEARSTRICKEN_CORPSE] = delegateAndEnd("processEvent610_2"),
		[GLASSYEYED_CORPSE] = delegateAndEnd("processEvent610_2"),
		other = endEvent,
	},
	[SEQ_060] = {
		[SISIPU] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent615")
			quest:StartSequence(SEQ_065)
			player:EndEvent()
			GetWorldManager():DoZoneChange(player, 128, nil, 0, 15, -42.0, 37.678, 155.694, -1.25)
			return true
		end,
		[WINDWORN_CORPSE] = delegateAndEnd("processEvent610_2"),
		[FEARSTRICKEN_CORPSE] = delegateAndEnd("processEvent610_2"),
		[GLASSYEYED_CORPSE] = delegateAndEnd("processEvent610_2"),
		other = endEvent,
	},
	[SEQ_070] = {
		[BADERON] = delegateAndEnd("processEvent615_2"),
		other = endEvent,
	},
	[SEQ_075] = {
		[BODENOLF] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent630")
			player:EndEvent()
			quest:StartSequence(SEQ_080)
			GetWorldManager():DoZoneChange(player, 230, "PrivateAreaMasterPast", 4, 15, -504.985, 42.490, 433.712, 2.35)
			return true
		end,
	},
	[SEQ_080] = {
		[HNAANZA] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent632")
			player:EndEvent()
			quest:StartSequence(SEQ_085)
			return true
		end,
		other = bsmEchoTalk,
	},
	[SEQ_085] = {
		[HNAANZA] = delegate("processEvent632_2"),
		other = bsmEchoTalk,
	},
	[SEQ_092] = {
		[BADERON] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEventComplete")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 300, 1, 1, 2)
			player:EndEvent()
			player:CompleteQuest(quest)
			return true
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

function seq000OnTalk(player, quest, npc, classId)
	if     classId == CRAPULOUS_ADVENTURER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010_2")
	elseif classId == SKITTISH_ADVENTURER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010_3")
	elseif classId == DUPLICITOUS_TRADER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010_4")
	elseif classId == DEBONAIR_PIRATE then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010_5")
	elseif classId == ONYXHAIRED_ADVENTURER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010_6")
	elseif classId == RELAXING_ADVENTURER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010_7")
	elseif classId == YSHTOLA then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010_8")
	elseif classId == BADERON then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020")
		quest:NewNpcLsMsg(1)
		quest:StartSequence(SEQ_003)
		player:EndEvent()

		-- The linkpearl tutorial plays from the after-warp notice once the player is out of the echo.
		local director = GetWorldManager():GetArea(133):CreateDirector("AfterQuestWarpDirector", false)
		player:AddDirector(director)
		director:StartDirector(true)
		player:SetLoginDirector(director)
		player:KickEvent(director, "noticeEvent", true)

		GetWorldManager():DoZoneChange(player, 133, nil, 0, 15, player.positionX, player.positionY, player.positionZ, player.rotation)
		return true
	elseif classId == MYTESYN then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010_7")
	elseif classId == COCKAHOOP_COCKSWAIN then
		callClientFunction(player, "delegateEvent", player, quest, "processEtc001")
	elseif classId == SOLICITOUS_SELLSWORD then
		callClientFunction(player, "delegateEvent", player, quest, "processEtc002")
	elseif classId == SENTENIOUS_SELLSWORD then
		callClientFunction(player, "delegateEvent", player, quest, "processEtc003")
	end
end

function seq007OnTalk(player, quest, npc, classId)
	local data = quest:GetData()
	local subseqCul = data:GetCounter(CNTR_SEQ7_CUL)
	local subseqMsk = data:GetCounter(CNTR_SEQ7_MSK)

	if classId == BADERON then
		if subseqCul == 1 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent027_3")
		elseif subseqMsk == 4 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent027_4")
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent027_2")
		end
		-- Reading the pearl moves to SEQ_035; this covers a pearl already read.
		if subseqCul >= 1 and subseqMsk >= 4 and data:GetNpcLsFrom() == 0 then
			player:EndEvent()
			quest:StartSequence(SEQ_035)
			return true
		end
	elseif classId == CHARLYS then
		if subseqCul == 0 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030")
			saveCounter(quest, CNTR_SEQ7_CUL, 1)
			player:GetItemPackage(INVENTORY_CURRENCY):AddItem(1000001, GIL_CUL_PAID, 1)
			if subseqMsk >= 4 then
				seq007EndSequence(player, quest)
			end
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030_2")
		end
	elseif classId == ISANDOREL then
		if subseqMsk == 2 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050")
			saveCounter(quest, CNTR_SEQ7_MSK, 3)
			player:EndEvent()
			quest:UpdateENPCs()
			warpToEcho(player, 230, 3)
			return true
		elseif subseqMsk == 0 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent035")
			saveCounter(quest, CNTR_SEQ7_MSK, 1)
		elseif subseqMsk == 1 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent035_2")
		end
	elseif classId == MERLZIRN then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent40_2")
	elseif classId == INTIMIDATING_BARRACUDA then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_2")
	elseif classId == TOTORUTO then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_4")
	elseif classId == MANNSKOEN then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_6")
	elseif classId == NERVOUS_BARRACUDA then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_7")
	elseif classId == OVEREAGER_BARRACUDA then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_8")
	elseif classId == SOPHISTICATED_BARRACUDA then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_9")
	elseif classId == SMIRKING_BARRACUDA then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_10")
	elseif classId == ADVENTURER2 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_13")
	elseif classId == ADVENTURER3 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_14")
	elseif classId == ADVENTURER1 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_15")
	end
end

-- Both errands in: the linkpearl lesson lines, then Baderon's call.
function seq007EndSequence(player, quest)
	player:SendGameMessage(quest, TEXT_LINKPEARL_TUTORIAL, 0x20)
	player:SendGameMessage(quest, TEXT_LINKPEARL_MENU_HINT, 0x20)
	quest:NewNpcLsMsg(1)
end

function seq080085OnTalk(player, quest, npc, classId)
	if classId == IOFA then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent630_2")
	elseif classId == TRINNE then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent630_3")
	elseif classId == HIHINE then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent630_4")
	elseif classId == MIMIDOA then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent630_5")
	elseif classId == WERNER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent630_6")
	elseif classId == TATTOOED_PIRATE then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent630_7")
	elseif classId == JOELLAUT then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent630_8")
	elseif classId == BODENOLF then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent630_9")
	end
end

local function zephyrPush(player, quest)
	local result = callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass")
	if result == 1 then
		startMan0l1Content(player, quest)
		return true
	end
end
local push = {
	[SEQ_007] = {
		[MSK_TRIGGER] = function(player, quest)
			if quest:GetData():GetCounter(CNTR_SEQ7_MSK) ~= 1 then
				return
			end
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040")
			saveCounter(quest, CNTR_SEQ7_MSK, 2)
			player:EndEvent()
			quest:UpdateENPCs()
			GetWorldManager():DoZoneChange(player, 230, nil, 0, 15, -620.0, 29.476, -70.050, 0.791)
			return true
		end,
		[ECHO_EXIT_TRIGGER] = function(player, quest)
			local data = quest:GetData()
			if data:GetCounter(CNTR_SEQ7_MSK) ~= 3 then
				return
			end
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060")
			saveCounter(quest, CNTR_SEQ7_MSK, 4)
			if data:GetCounter(CNTR_SEQ7_CUL) >= 1 then
				seq007EndSequence(player, quest)
			end
			player:EndEvent()
			quest:UpdateENPCs()
			GetWorldManager():DoZoneChange(player, 230, nil, 0, 15, player.positionX, player.positionY, player.positionZ, player.rotation)
			return true
		end,
	},
	[SEQ_048] = { [ZEPHYR_TRIGGER] = zephyrPush },
	[SEQ_050] = { [ZEPHYR_TRIGGER] = zephyrPush },
	[SEQ_065] = {
		[FSH_TRIGGER] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent620")
			player:GetItemPackage(INVENTORY_CURRENCY):AddItem(1000001, GIL_FSH_PAID, 1)
			player:EndEvent()
			quest:NewNpcLsMsg(1)
			quest:StartSequence(SEQ_070)
			return true
		end,
	},
	[SEQ_085] = {
		[ECHO_EXIT_TRIGGER2] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent635")
			player:EndEvent()
			quest:NewNpcLsMsg(1)
			quest:StartSequence(SEQ_090)
			GetWorldManager():DoZoneChange(player, 230, nil, 0, 15, player.positionX, player.positionY, player.positionZ, player.rotation)
			return true
		end,
	},
}

function onPush(player, quest, npc)
	if runQuestHandler(push, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

local function sisipuEmote(player, quest, npc, eventName)
	local data = quest:GetData()

	if eventName == "emoteDefault1" then 		-- Bow
		player:DoEmote(npc.Id, 5, 21041)
	elseif eventName == "emoteDefault2" then	-- Clap
		player:DoEmote(npc.Id, 7, 21061)
	elseif eventName == "emoteDefault3" then	-- Congratulate
		player:DoEmote(npc.Id, 29, 21281)
	elseif eventName == "emoteDefault4" then	-- Poke
		player:DoEmote(npc.Id, 28, 21271)
	elseif eventName == "emoteDefault5" then	-- Joy
		player:DoEmote(npc.Id, 18, 21171)
	elseif eventName == "emoteDefault6" then	-- Wave
		player:DoEmote(npc.Id, 16, 21151)
	end
	wait(2.5)

	local emoteTestStep = data:GetCounter(CNTR_SEQ40_FSH)
	-- Bow
	if emoteTestStep == 1 then
		if eventName == "emoteDefault1" then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_7")
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_2")
			player:SendGameMessage(GetWorldMaster(), 25083, MESSAGE_TYPE_SYSTEM, 1)
			saveCounter(quest, CNTR_SEQ40_FSH, emoteTestStep + 1)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_8")
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_1")
		end
	-- Clap
	elseif emoteTestStep == 2 then
		if eventName == "emoteDefault2" then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_7")
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_3")
			player:SendGameMessage(GetWorldMaster(), 25083, MESSAGE_TYPE_SYSTEM, 1)
			saveCounter(quest, CNTR_SEQ40_FSH, emoteTestStep + 1)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_8")
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_2")
		end
	-- Congratulate
	elseif emoteTestStep == 3 then
		if eventName == "emoteDefault3" then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_7")
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_4")
			player:SendGameMessage(GetWorldMaster(), 25083, MESSAGE_TYPE_SYSTEM, 1)
			saveCounter(quest, CNTR_SEQ40_FSH, emoteTestStep + 1)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_8")
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_3")
			player:SendGameMessage(GetWorldMaster(), 25083, MESSAGE_TYPE_SYSTEM, 1)
		end
	-- Poke
	elseif emoteTestStep == 4 then
		if eventName == "emoteDefault4" then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_7")
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_5")
			player:SendGameMessage(GetWorldMaster(), 25083, MESSAGE_TYPE_SYSTEM, 1)
			saveCounter(quest, CNTR_SEQ40_FSH, emoteTestStep + 1)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_8")
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_4")
		end
	-- Joy
	elseif emoteTestStep == 5 then
		if eventName == "emoteDefault5" then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_7")
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_6")
			player:SendGameMessage(GetWorldMaster(), 25083, MESSAGE_TYPE_SYSTEM, 1)
			saveCounter(quest, CNTR_SEQ40_FSH, emoteTestStep + 1)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_8")
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_5")
		end
	-- Wave
	elseif emoteTestStep == 6 then
		if eventName == "emoteDefault6" then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent602")
			player:EndEvent()
			quest:StartSequence(SEQ_048)
			GetWorldManager():DoZoneChange(player, 230, nil, 0, 15, player.positionX, player.positionY, player.positionZ, player.rotation)
			return true
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_8")
			callClientFunction(player, "delegateEvent", player, quest, "processEvent601_6")
		end
	end

	player:EndEvent()
	quest:UpdateENPCs()
	return true
end

local emote = {
	[SEQ_040] = { [SISIPU_EMOTE] = sisipuEmote },
}

function onEmote(player, quest, npc, eventName)
	if runQuestHandler(emote, player, quest, npc, eventName) then return end
	player:EndEvent()
end

function onNotice(player, quest, target)
	if quest:GetSequence() == SEQ_003 then
		callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting")
		callClientFunction(player, "delegateEvent", player, quest, "processEventTu_001")
	end
	player:EndEvent()
	quest:UpdateENPCs()
end

function onNpcLS(player, quest, from, msgStep)
	local sequence = quest:GetSequence()
	local data = quest:GetData()
	local errandsDone = data:GetCounter(CNTR_SEQ7_CUL) >= 1 and data:GetCounter(CNTR_SEQ7_MSK) >= 4
	local msgPack

	if from == 1 then
		-- Get the right msg pack
		if sequence == SEQ_003 or sequence == SEQ_005 or sequence == SEQ_006 or (sequence == SEQ_007 and not errandsDone) then
			msgPack = 1
		elseif sequence == SEQ_007 or sequence == SEQ_035 then
			msgPack = 2
		elseif sequence == SEQ_070 or sequence == SEQ_075 then
			msgPack = 3
		elseif sequence == SEQ_090 or sequence == SEQ_092 then
			msgPack = 4
		end

		if msgPack == nil then
			player:EndEvent()
			return
		end

		-- Quick way to handle all msgs nicely.
		local msgs = NPCLS_MSGS[msgPack]
		local step = math.max(1, math.min(msgStep, #msgs))
		player:SendGameMessageLocalizedDisplayName(quest, msgs[step], MESSAGE_TYPE_NPC_LINKSHELL, 1000015)
		if step >= #msgs then
			quest:EndOfNpcLsMsgs()
		else
			quest:ReadNpcLsMsg()
		end

		-- Handle anything else
		if msgPack == 1 then
			if sequence ~= SEQ_007 then
				showTutorialSuccessWidget(player, 9080)
				closeTutorialWidget(player)
				endTutorialMode(player)
			end
		elseif sequence == SEQ_007 then
			quest:StartSequenceForNpcLs(SEQ_035)
		elseif sequence == SEQ_070 then
			quest:StartSequenceForNpcLs(SEQ_075)
		elseif sequence == SEQ_090 then
			quest:StartSequenceForNpcLs(SEQ_092)
		end
	end

	player:EndEvent()
end

function startMan0l1Content(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent604")
	if quest:GetSequence() ~= SEQ_050 then
		quest:StartSequence(SEQ_050)
	end

	local contentArea = GetWorldManager():GetZone(128):CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "simplecontentman0l101", "SimpleContentMan0l101", "Quest/QuestDirectorMan0l101")

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
	GetWorldManager():DoZoneChangeContent(player, contentArea, -63.25, 33.15, 164.51, 0.8, 15)
end

local function endMan0l1Content(player, duty, contentArea)
	player:SetMod(Modifier.MinimumHpLock, 0)
	player:EndEvent()
	if duty ~= nil then
		duty:Close()
	end
	if contentArea ~= nil then
		pcall(function() contentArea:ContentFinished() end)
	end
end

-- QuestDirectorMan0l101, Sisipu brought to Oschon's Torch, with its noticeEvent open.
function finishEscort(player, quest, duty, contentArea)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent605", nil, nil, nil)
	quest:StartSequence(SEQ_055)
	endMan0l1Content(player, duty, contentArea)
	GetWorldManager():DoZoneChange(player, 128, "PrivateAreaMasterPast", 2, 15, 137.44, 60.33, 1322.0, -1.60)
end

function failEscort(player, quest, duty, contentArea)
	quest:StartSequence(SEQ_048)
	player:SetHP(player:GetMaxHP())
	endMan0l1Content(player, duty, contentArea)
	GetWorldManager():DoZoneChange(player, 128, nil, 0, 15, -63.25, 33.15, 164.51, 0.8)
end

function warpToEcho(player, zoneId, privateAreaType)
	GetWorldManager():DoZoneChange(player, zoneId, "PrivateAreaMasterPast", privateAreaType, 15, player.positionX, player.positionY, player.positionZ, player.rotation)
end

function saveCounter(quest, counter, value)
	local data = quest:GetData()
	data:SetCounter(counter, value)
	data:Save()
end

function getJournalInformation(player, quest)
	local data = quest:GetData()
	return 0, math.min(data:GetCounter(CNTR_SEQ7_CUL), 1) * 5, math.min(data:GetCounter(CNTR_SEQ7_MSK), 4) * 5
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	local data = quest:GetData()
	local possibleMarkers = {}

	if sequence == SEQ_000 then
		table.insert(possibleMarkers, MRKR_BADERON)
	elseif sequence == SEQ_003 then
		table.insert(possibleMarkers, MRKR_BEARDED_ROCK)
	elseif sequence == SEQ_005 or sequence == SEQ_006 then
		table.insert(possibleMarkers, MRKR_BADERON2)
	elseif sequence == SEQ_007 then
		local subseqCul = data:GetCounter(CNTR_SEQ7_CUL)
		local subseqMsk = data:GetCounter(CNTR_SEQ7_MSK)
		if subseqCul == 0 then
			table.insert(possibleMarkers, MRKR_CHARLYS)
		end
		if subseqMsk == 0 then
			table.insert(possibleMarkers, MRKR_ISANDOREL)
		elseif subseqMsk == 1 then
			table.insert(possibleMarkers, MRKR_MSK_TRIGGER)
		elseif subseqMsk == 2 then
			table.insert(possibleMarkers, MRKR_ISANDOREL2)
		elseif subseqMsk == 3 then
			table.insert(possibleMarkers, MRKR_ECHO_EXIT)
		end
	elseif sequence == SEQ_035 then
		table.insert(possibleMarkers, MRKR_NNMULIKA)
	elseif sequence == SEQ_040 then
		table.insert(possibleMarkers, MRKR_SISIPU_EMOTE)
	elseif sequence == SEQ_048 then
		table.insert(possibleMarkers, MRKR_ZEPHYR_TRIGGER)
	elseif sequence == SEQ_050 then
		table.insert(possibleMarkers, MRKR_OSCHONS_TORCH)
	elseif sequence == SEQ_055 then
		table.insert(possibleMarkers, MRKR_WINDWORN_CORPSE)
	elseif sequence == SEQ_060 then
		table.insert(possibleMarkers, MRKR_SISIPU)
	elseif sequence == SEQ_065 then
		table.insert(possibleMarkers, MRKR_FSH_TRIGGER)
	elseif sequence == SEQ_075 then
		table.insert(possibleMarkers, MRKR_BODENOLF)
	elseif sequence == SEQ_080 then
		table.insert(possibleMarkers, MRKR_HNAANZA)
	elseif sequence == SEQ_085 then
		table.insert(possibleMarkers, MRKR_ECHO_EXIT2)
	elseif sequence == SEQ_092 then
		table.insert(possibleMarkers, MRKR_BADERON3)
	end

	return unpack(possibleMarkers)
end