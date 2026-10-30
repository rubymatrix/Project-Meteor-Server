require("Global")
require("Quest")

--[[
Legends Adrift (Man1l0, 110003). Prereq: Treasures of the Main (Man0l1).
--]]

-- Sequence Numbers
local SEQ_000	= 0  	-- Echo intance with Y'shtola, Baderon, Etc. Talk to Y'shtola.
local SEQ_010	= 10  	-- Echo instance, talk with Baderon.
local SEQ_020	= 20  	-- Head to MRD guild and talk to Waekbyrt.
local SEQ_030	= 30  	-- Head down the Astalicia to the push trigger.
local SEQ_040	= 40  	-- Head up the Astalicia to the push trigger.
local SEQ_050	= 50	-- Contact Baderon on the Link Pearl.
local SEQ_060	= 60	-- Head to the FSH guild and push the trigger.
local SEQ_070	= 70	-- Head to a spot in Lower La Noscea.
local SEQ_080	= 80	-- Contact Baderon on the Link Pearl.
local SEQ_090	= 90	-- Speak to P'tahjha at the ACN guild.
local SEQ_100	= 100	-- Echo instance, head downstairs to push a trigger and cutscene.
local SEQ_110	= 110	-- Echo instance still, head upstairs to trigger a cutscene.
local SEQ_120	= 120	-- Contact Baderon on the Link Pearl.
local SEQ_122	= 122	-- Head back to Baderon to finish the quest.

-- Quest Actors
local BADERON 					= 1000137
local YSHTOLA 					= 1000001

-- ADV Guild Echo
local ADVENTURER					= 1000101
local WHISPERING_ADVENTURER		= 1000102
local UNAPPROACHABLE_ADVENTURER 	= 1000103
local FISH_SMELLING_ADVENTURER	= 1000104
local SPEAR_WIELDING_ADVENTURER	= 1000105
local TRIGGER_ADVGUILD			= 1090080

-- MRD Guild Echo
local WAEKBYRT					= 1000003
local HULKING_CUDA_KNIGHT			= 1000182
local SOPHISTICATED_CUDA_KNIGHT	= 1000108
local FRIGHTENED_CUDA_KNIGHT		= 1000110
local ZEALOUS_PIRATE				= 1000112
local ENRAGED_PIRATE				= 1000113
local TRIGGER_MRD					= 1090081

-- MRD Guild Echo 2
local DISGRUNTLED_PIRATE			= 1000087
local PINE_SCENTED_PIRATE			= 1000088
local BARITONE_PIRATE				= 1000089
local BAYARD						= 1000190

-- FSH Guild Sequences
local NNMULIKA					= 1000153
local SISIPU						= 1000156
local TRIGGER_FSH					= 1090006
local TRIGGER_SEAFLD				= 1090082

-- ACN Guild Echo
local ASSESSOR1			 		= 1000120
local ASSESSOR2			 		= 1000121
local PTAHJHA						= 1000150
local HALDBERK		 			= 1000160
local LILINA			 			= 1000178
local DODOROBA					= 1000196
local IVAN			 			= 1000197
local MERODAULYN		 			= 1000008
local COQUETTISH_PIRATE			= 1000868
local VOLUPTUOUS_PIRATE			= 1000115
local PEACOCKISH_PIRATE			= 1000118
local TRIGGER_ACN_LOWER			= 1090083
local TRIGGER_ACN_UPPER			= 1090084

-- Quest Markers
local MRKR_TRIGGER_FSH			= 11000306
local MRKR_TRIGGER_SEAFLD			= 11000307
local MRKR_TRIGGER_ANC_LOWER		= 11000308

-- Msg packs for the Npc LS
local NPCLS_MSGS = {
	{57, 58, 59}, 	-- SEQ_050
	{92, 93, 94}, 	-- SEQ_070
	{140, 141}		-- SEQ_120
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
	GetWorldManager():WarpToPrivateArea(player, "PrivateAreaMasterPast", 3, -430.55, 40.2, 185.41, 1.89)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	local data = quest:GetData()
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(BADERON, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(BADERON)
		quest:SetENpc(ADVENTURER)
		quest:SetENpc(WHISPERING_ADVENTURER)
		quest:SetENpc(UNAPPROACHABLE_ADVENTURER)
		quest:SetENpc(FISH_SMELLING_ADVENTURER)
		quest:SetENpc(SPEAR_WIELDING_ADVENTURER)
		quest:SetENpc(TRIGGER_ADVGUILD, QFLAG_PUSH, false, true)
	elseif sequence == SEQ_010 then
		quest:SetENpc(BADERON, QFLAG_TALK)
		quest:SetENpc(ADVENTURER)
		quest:SetENpc(WHISPERING_ADVENTURER)
		quest:SetENpc(UNAPPROACHABLE_ADVENTURER)
		quest:SetENpc(FISH_SMELLING_ADVENTURER)
		quest:SetENpc(SPEAR_WIELDING_ADVENTURER)
		quest:SetENpc(YSHTOLA)
	elseif sequence == SEQ_020 then
		quest:SetENpc(WAEKBYRT, QFLAG_TALK)
		quest:SetENpc(BADERON)
	elseif sequence == SEQ_030 then
		quest:SetENpc(TRIGGER_MRD, QFLAG_PUSH, false, true)
		quest:SetENpc(HULKING_CUDA_KNIGHT)
		quest:SetENpc(SOPHISTICATED_CUDA_KNIGHT)
		quest:SetENpc(FRIGHTENED_CUDA_KNIGHT)
		quest:SetENpc(ZEALOUS_PIRATE)
		quest:SetENpc(ENRAGED_PIRATE)
		quest:SetENpc(WAEKBYRT)
	elseif sequence == SEQ_040 then
		quest:SetENpc(TRIGGER_MRD, QFLAG_PUSH, false, true)
		quest:SetENpc(PINE_SCENTED_PIRATE)
		quest:SetENpc(BARITONE_PIRATE)
		quest:SetENpc(BAYARD)
		quest:SetENpc(DISGRUNTLED_PIRATE)
	elseif sequence == SEQ_060 then
		quest:SetENpc(TRIGGER_FSH, QFLAG_PUSH, false, true)
		quest:SetENpc(BADERON)
	elseif sequence == SEQ_070 then
		quest:SetENpc(TRIGGER_SEAFLD, QFLAG_PUSH, false, true)
		quest:SetENpc(NNMULIKA)
	elseif sequence == SEQ_090 then
		quest:SetENpc(PTAHJHA, QFLAG_TALK)
	elseif sequence == SEQ_100 then
		quest:SetENpc(TRIGGER_ACN_LOWER, QFLAG_PUSH, false, true)
		quest:SetENpc(ASSESSOR1)
		quest:SetENpc(ASSESSOR2)
		quest:SetENpc(HALDBERK)
		quest:SetENpc(LILINA)
		quest:SetENpc(VOLUPTUOUS_PIRATE)
		quest:SetENpc(PEACOCKISH_PIRATE)
		quest:SetENpc(MERODAULYN)
		quest:SetENpc(COQUETTISH_PIRATE)
		quest:SetENpc(IVAN)
	elseif sequence == SEQ_110 then
		quest:SetENpc(TRIGGER_ACN_UPPER, QFLAG_PUSH, false, true)
	elseif sequence == SEQ_122 then
		quest:SetENpc(BADERON, QFLAG_REWARD)
	end

end

local function say(event)
	return function(player, quest)
		callClientFunction(player, "delegateEvent", player, quest, event)
	end
end

local ADV_GUILD_ECHO = {
	[ADVENTURER] = say("processEvent200_2"),
	[WHISPERING_ADVENTURER] = say("processEvent200_3"),
	[UNAPPROACHABLE_ADVENTURER] = say("processEvent200_4"),
	[FISH_SMELLING_ADVENTURER] = say("processEvent200_5"),
	[SPEAR_WIELDING_ADVENTURER] = say("processEvent200_6"),
	[BADERON] = say("processEvent200_7"),
}

local MRD_ECHO = {
	[HULKING_CUDA_KNIGHT] = say("processEvent400_2"),
	[SOPHISTICATED_CUDA_KNIGHT] = say("processEvent400_3"),
	[FRIGHTENED_CUDA_KNIGHT] = say("processEvent400_4"),
	[ZEALOUS_PIRATE] = say("processEvent400_5"),
	[ENRAGED_PIRATE] = say("processEvent400_6"),
	[WAEKBYRT] = say("processEvent400_7"),
	[PINE_SCENTED_PIRATE] = say("processEvent410_2"),
	[BARITONE_PIRATE] = say("processEvent410_3"),
	[BAYARD] = say("processEvent410_4"),
	[DISGRUNTLED_PIRATE] = say("processEvent410_5"),
}

local ACN_ECHO = {
	[ASSESSOR1] = say("processEvent2000_2"),
	[ASSESSOR2] = say("processEvent2000_3"),
	[HALDBERK] = say("processEvent2000_4"),
	[LILINA] = say("processEvent2000_5"),
	[VOLUPTUOUS_PIRATE] = say("processEvent2000_6"),
	[PEACOCKISH_PIRATE] = say("processEvent2000_7"),
	[MERODAULYN] = say("processEvent2000_8"),
	[COQUETTISH_PIRATE] = say("processEvent2000_9"),
	-- processEvent2000_10 and _11 have no known speaker.
	[0] = say("processEvent2000_10"),
	[IVAN] = say("processEvent2000_12"),
}

local ADV_GUILD_ECHO_AFTER = {
	[BADERON] = function(player, quest)
		callClientFunction(player, "delegateEvent", player, quest, "processEvent215")
		player:EndEvent()
		quest:StartSequence(SEQ_020)
		GetWorldManager():WarpToPublicArea(player)
		return true
	end,
	[YSHTOLA] = say("processEvent200_8"),
}
for classId, handler in pairs(ADV_GUILD_ECHO) do
	ADV_GUILD_ECHO_AFTER[classId] = ADV_GUILD_ECHO_AFTER[classId] or handler
end

local talk = {
	[SEQ_ACCEPT] = {
		[BADERON] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent200")
			player:EndEvent()
			player:AcceptQuest(quest, true)
			return true
		end,
	},
	[SEQ_000] = ADV_GUILD_ECHO,
	[SEQ_010] = ADV_GUILD_ECHO_AFTER,
	[SEQ_020] = {
		[WAEKBYRT] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent400")
			quest:StartSequence(SEQ_030)
			player:EndEvent()
			GetWorldManager():WarpToPrivateArea(player, "PrivateAreaMasterPast", 6, -754.03, 7.352, 382.872, 3.133)
			return true
		end,
		[BADERON] = say("processEvent215_2"),
	},
	[SEQ_030] = MRD_ECHO,
	[SEQ_040] = MRD_ECHO,
	[SEQ_060] = {
		[NNMULIKA] = say("processEvent600"),
		[BADERON] = say("processEvent420_2"),
	},
	[SEQ_070] = {
		[NNMULIKA] = say("processEvent600_2"),
	},
	[SEQ_090] = {
		[PTAHJHA] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent2000")
			quest:StartSequence(SEQ_100)
			player:EndEvent()
			GetWorldManager():WarpToPrivateArea(player, "PrivateAreaMasterPast", 7)
		end,
		[BADERON] = say("processEvent610_2"),
	},
	[SEQ_100] = ACN_ECHO,
	[SEQ_122] = {
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

local push = {
	[SEQ_000] = {
		[TRIGGER_ADVGUILD] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent210")
			quest:StartSequence(SEQ_010)
		end,
	},
	[SEQ_030] = {
		[TRIGGER_MRD] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent410")
			quest:StartSequence(SEQ_040)
			player:EndEvent()
			GetWorldManager():WarpToPosition(player, -764.519, -3.146, 384.154, 1.575)
			return true
		end,
	},
	[SEQ_040] = {
		[TRIGGER_MRD] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent420")
			quest:NewNpcLsMsg(1)
			quest:StartSequence(SEQ_050)
			player:EndEvent()
			GetWorldManager():WarpToPublicArea(player)
			return true
		end,
	},
	[SEQ_060] = {
		[TRIGGER_FSH] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent600")
			quest:StartSequence(SEQ_070)
		end,
	},
	[SEQ_070] = {
		[TRIGGER_SEAFLD] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent610")
			quest:NewNpcLsMsg(1)
			quest:StartSequence(SEQ_080)
		end,
	},
	[SEQ_100] = {
		[TRIGGER_ACN_LOWER] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent2001")
			quest:StartSequence(SEQ_110)
			player:EndEvent()
			GetWorldManager():WarpToPosition(player, -785.938, -0.62, 189.044, 3.09)
			return true
		end,
	},
	[SEQ_110] = {
		[TRIGGER_ACN_UPPER] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent2002")
			quest:NewNpcLsMsg(1)
			quest:StartSequence(SEQ_120)
			player:EndEvent()
			GetWorldManager():WarpToPublicArea(player)
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
	local sequence = quest:GetSequence()
	local msgPack

	if from == 1 then
		if sequence == SEQ_050 or sequence == SEQ_060 then
			msgPack = 1
		elseif sequence == SEQ_080 or sequence == SEQ_090 then
			msgPack = 2
		elseif sequence == SEQ_120 or sequence == SEQ_122 then
			msgPack = 3
		end

		player:SendGameMessageLocalizedDisplayName(quest, NPCLS_MSGS[msgPack][msgStep], MESSAGE_TYPE_NPC_LINKSHELL, 1000015)
		if msgStep >= #NPCLS_MSGS[msgPack] then
			quest:EndOfNpcLsMsgs()
		else
			quest:ReadNpcLsMsg()
		end

		if sequence == SEQ_050 then
			quest:StartSequenceForNpcLs(SEQ_060)
		elseif sequence == SEQ_080 then
			quest:StartSequenceForNpcLs(SEQ_090)
		elseif sequence == SEQ_120 then
			quest:StartSequenceForNpcLs(SEQ_122)
		end
	end

	player:EndEvent()
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

end