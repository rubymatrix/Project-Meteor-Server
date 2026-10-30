require("Global")
require("Quest")

--[[

Quest Script

Name: 	Whispers in the Wood
Code: 	Man1g0
Id: 	110007
Prereq: Souls Gone Wild (Man0g1 - 110006), Level 8

]]

-- Sequence Numbers
local SEQ_000	= 0  	-- Visit the CRP guild.
local SEQ_005	= 5  	-- Go to Acorn Orchard in echo.
local SEQ_010	= 10  	-- Speak to Fye in echo.
local SEQ_015	= 15  	-- Return to CRP guild in echo.
local SEQ_020	= 20  	-- Talk to Miounne on the LS.
local SEQ_025	= 25	-- Go to BTN guild.
local SEQ_030	= 30	-- Go to the Moogle in the South Shroud.
local SEQ_035	= 35	-- Move to the Moogle in echo.
local SEQ_040	= 40	-- Return to the BTN guild.
local SEQ_045	= 45	-- Talk to Miounne on the LS.
local SEQ_050	= 50	-- Visit the ARC guild.
local SEQ_055	= 55	-- Go deeper into the ARC guild.
local SEQ_060	= 60	-- Talk to Miounne on the LS.
local SEQ_065	= 65	-- Return to Miounne.

-- Actor Class Ids
local MIOUNNE 					= 1000230

-- CRP Guild Echo
local ZEZEKUTA					= 1000240
local ANAIDJAA					= 1000465
local CAPLAN						= 1000822
local FRANCES						= 1000466
local ULMHYLT						= 1000823
local DECIMA						= 1000622
local CHALYO_TAMLYO				= 1000623
local PLAYGROUND_TRIGGER			= 1090204

-- Acorn Orchard Echo
local FYE							= 1000014
local TROUBLESOME_TOMBOY			= 1000828
local DESERTED_DAUGHTER			= 1000827
local PLAYGROUND_EXIT_TRIGGER		= 1090205

-- West Gridania Echo + BTN
local BTN_TRIGGER					= 1090046
local WEST_SHROUD_TRIGGER			= 1090067
local PUDGY_MOOGLE				= 1000328
local SHROUD_ECHO_TRIGGER			= 0
local OPYLTYL						= 1000236

-- ARC Guild
local NONOLATO					= 1000463
local GUILD_ARC_INSIDE_TRIGGER	= 1090068

-- Msg packs for the Npc LS
local NPCLS_MSGS = {
	{96, 97, 98},		-- SEQ_020
	{170, 171, 172},	-- SEQ_045
	{231, 232}			-- SEQ_060
}

-- Quest Markers
local MRKR_STEP1				= 11000701
local MRKR_STEP2				= 11000702
local MRKR_STEP3				= 11000703
local MRKR_STEP4				= 11000704
local MRKR_STEP5				= 11000705
local MRKR_STEP6				= 11000706
local MRKR_STEP7				= 11000707
local MRKR_STEP8				= 11000708
local MRKR_STEP9				= 11000709
local MRKR_STEP10				= 11000710
local MRKR_STEP11				= 11000711
local MRKR_STEP12				= 11000712

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	local data = quest:GetData()
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(MIOUNNE, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ANAIDJAA, QFLAG_TALK)
		quest:SetENpc(MIOUNNE)
	elseif sequence == SEQ_005 then
		quest:SetENpc(ANAIDJAA)
		quest:SetENpc(CAPLAN)
		quest:SetENpc(FRANCES)
		quest:SetENpc(ULMHYLT)
		quest:SetENpc(DECIMA)
		quest:SetENpc(CHALYO_TAMLYO)
		quest:SetENpc(PLAYGROUND_TRIGGER, QFLAG_PUSH, false, true)
	elseif sequence == SEQ_010 then
		quest:SetENpc(FYE, QFLAG_TALK)
		quest:SetENpc(TROUBLESOME_TOMBOY)
		quest:SetENpc(DESERTED_DAUGHTER)
	elseif sequence == SEQ_015 then
		quest:SetENpc(TROUBLESOME_TOMBOY)
		quest:SetENpc(DESERTED_DAUGHTER)
		quest:SetENpc(PLAYGROUND_EXIT_TRIGGER, QFLAG_PUSH, false, true)
	elseif sequence == SEQ_020 then
	elseif sequence == SEQ_025 then
		quest:SetENpc(BTN_TRIGGER, QFLAG_PUSH, false, true)
		quest:SetENpc(MIOUNNE)
	elseif sequence == SEQ_030 then
		quest:SetENpc(MIOUNNE)
	elseif sequence == SEQ_035 then
	elseif sequence == SEQ_040 then
		quest:SetENpc(OPYLTYL, QFLAG_TALK)
	elseif sequence == SEQ_045 then
	elseif sequence == SEQ_050 then
		quest:SetENpc(NONOLATO, QFLAG_TALK)
		quest:SetENpc(MIOUNNE)
	elseif sequence == SEQ_055 then
		quest:SetENpc(GUILD_ARC_INSIDE_TRIGGER, QFLAG_PUSH, false, true)
		quest:SetENpc(NONOLATO)
	elseif sequence == SEQ_065 then
		quest:SetENpc(MIOUNNE, QFLAG_REWARD)
		quest:SetENpc(NONOLATO)
	end

end

local talk = {
	[SEQ_ACCEPT] = {
		[MIOUNNE] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEventMiounneStart")
			player:EndEvent()
			player:AcceptQuest(quest, true)
			return true
		end,
	},
	[SEQ_000] = {
		[ANAIDJAA] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010")
			player:EndEvent()
			quest:StartSequence(SEQ_005)
			GetWorldManager():WarpToPrivateArea(player, "PrivateAreaMasterPast", 7)
			return true
		end,
		[MIOUNNE] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2")
		end,
	},
	[SEQ_005] = {
		[ZEZEKUTA] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_2")
		end,
		[ANAIDJAA] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_3")
		end,
		[FRANCES] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_4")
		end,
		[CAPLAN] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_5")
		end,
		[ULMHYLT] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_6")
		end,
		[DECIMA] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_7")
		end,
		[CHALYO_TAMLYO] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_8")
		end,
	},
	[SEQ_010] = {
		[ZEZEKUTA] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_2")
		end,
		[DESERTED_DAUGHTER] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_3")
		end,
		[TROUBLESOME_TOMBOY] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_4")
		end,
		[FYE] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030")
			player:EndEvent()
			quest:StartSequence(SEQ_015)
			GetWorldManager():DoZoneChange(player, 206, "PrivateAreaMasterPast", 9, 15, -35.566, 7.845, -1250.233, 0.842)
		end,
	},
	[SEQ_015] = {
		[DESERTED_DAUGHTER] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_3")
		end,
		[TROUBLESOME_TOMBOY] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_4")
		end,
	},
	[SEQ_025] = {
		[MIOUNNE] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040_2")
		end,
	},
	[SEQ_030] = {
		[MIOUNNE] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050_2")
		end,
	},
	[SEQ_035] = {
		[MIOUNNE] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050_2")
		end,
	},
	[SEQ_040] = {
		[OPYLTYL] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent080")
			quest:NewNpcLsMsg(1)
			quest:StartSequence(SEQ_045)
		end,
	},
	[SEQ_050] = {
		[NONOLATO] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent090")
			quest:StartSequence(SEQ_055)
		end,
		[MIOUNNE] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent080_3")
		end,
	},
	[SEQ_055] = {
		[NONOLATO] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent090_2")
		end,
	},
	[SEQ_065] = {
		[MIOUNNE] = function(player, quest, npc)
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

function onPush(player, quest, npc)
	local data = quest:GetData()
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if sequence == SEQ_005 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020")
		player:EndEvent()
		quest:StartSequence(SEQ_010)
		GetWorldManager():DoZoneChange(player, 206, "PrivateAreaMasterPast", 8, 15, -35.452, 7.845, -1250.145, 0.777)
	elseif sequence == SEQ_015 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040")
		player:EndEvent()
		quest:NewNpcLsMsg(1)
		quest:StartSequence(SEQ_020)
		GetWorldManager():DoZoneChange(player, 206, nil, 0, 15, 15.593, 8.75, -1266.0, -1.322)
	elseif sequence == SEQ_020 then
	elseif sequence == SEQ_025 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050")
		quest:StartSequence(SEQ_030)
	elseif sequence == SEQ_030 then
		-- Go to west shroud
		callClientFunction(player, "delegateEvent", player, quest, "processEvent060")
		quest:StartSequence(SEQ_035)
	elseif sequence == SEQ_035 then
		-- Go to moogle
		callClientFunction(player, "delegateEvent", player, quest, "processEvent070")
		quest:StartSequence(SEQ_040)
	elseif sequence == SEQ_055 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent100")
		quest:NewNpcLsMsg(1)
		quest:StartSequence(SEQ_060)
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onNpcLS(player, quest, from, msgStep)
	local sequence = quest:GetSequence()
	local msgPack

	if from == 1 then
		-- Get the right msg pack
		if sequence == SEQ_020 or sequence == SEQ_025 then
			msgPack = 1
		elseif sequence == SEQ_045 or sequence == SEQ_050 then
			msgPack = 2
		elseif sequence == SEQ_060 or sequence == SEQ_065 then
			msgPack = 3
		end

		-- Quick way to handle all msgs nicely.
		player:SendGameMessageLocalizedDisplayName(quest, NPCLS_MSGS[msgPack][msgStep], MESSAGE_TYPE_NPC_LINKSHELL, 1000015)
		if msgStep >= #NPCLS_MSGS[msgPack] then
			quest:EndOfNpcLsMsgs()
		else
			quest:ReadNpcLsMsg()
		end

		-- Handle anything else
		if sequence == SEQ_020 then
			quest:StartSequenceForNpcLs(SEQ_025)
		elseif sequence == SEQ_045 then
			quest:StartSequenceForNpcLs(SEQ_050)
		elseif sequence == SEQ_060 then
			quest:StartSequenceForNpcLs(SEQ_065)
		end
	end

	player:EndEvent()
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_STEP1
	elseif sequence == SEQ_005 then
		return MRKR_STEP2
	elseif sequence == SEQ_010 then
		return MRKR_STEP3
	elseif sequence == SEQ_015 then
		return MRKR_STEP4
	elseif sequence == SEQ_025 then
		return MRKR_STEP6
	elseif sequence == SEQ_030 then
		return MRKR_STEP7
	elseif sequence == SEQ_035 then
		return MRKR_STEP8
	elseif sequence == SEQ_040 then
		return MRKR_STEP9
	elseif sequence == SEQ_050 then
		return MRKR_STEP11
	elseif sequence == SEQ_055 then
		return MRKR_STEP12
	elseif sequence == SEQ_065 then
		return MRKR_STEP13
	end
end