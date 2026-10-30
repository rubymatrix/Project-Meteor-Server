require("Global")
require("Quest")

--[[
Fade to White (Man200, 110013). Prereq: Etc2l0 or Etc2g0 or Etc2u0. Level 18, any class.
--]]

local seq000OnTalkOtherNpcs, seq010OnTalkOtherNpcs, startMan20001Content

-- Sequence Numbers
local SEQ_000	= 0  	-- Go to the event door
local SEQ_005	= 5  	-- Talk to Minfilia to use the echo on her.
local SEQ_010	= 10  	-- Talk to Minfilia to join the Path of the Twelve.
local SEQ_020	= 20  	-- Path companion selection sequence.
local SEQ_025	= 25  	-- Wait for the linkpearl message.
local SEQ_027	= 27	-- Pray return to the Waking Sands

-- Quest Actors
local MINFILIA				= 1000843
local TATARU					= 1001046
local SATZFLOH				= 1001228
local PERCEVAINS				= 1001229
local UNA_TAYUUN				= 1001230
local ROUGH_SPOKEN_FELLOW		= 1001274
local RED_SHOED_RASCAL		= 1001275
local ABSTRACTED_GLADIATOR	= 1001276
local CHAPEAUED_CHAP			= 1001277
local BARRATROUS_BUCCANEER	= 1001278
local SOFTHEARTED_SEPTUAGEN	= 1001279
local INDIGO_EYED_ARCHER		= 1001280
local LOAM_SCENETED_LADY		= 1001281
local UNCOMFORTABLE_BRUTE		= 1001282
local SAHJA_ZHWAN				= 1001373
local NENEKANI				= 1001374
local GODFREY					= 1001375
local FENANA					= 1001376
local NONORU					= 1001377
local SERANELIEN				= 1001378

local SNPC_START				= 1070001
local SNPC_END				= 1070166

local MARKET_ENTRENCE			= 1090265
local EVENT_DOOR_EXIT			= 1090160
local EVENT_DOOR_OFFICE_W		= 1090161
local EVENT_DOOR_OFFICE_E		= 1090162

local MOMODI					= 1000841

-- Quest Markers
local MRKR_STEP1				= 11001301
local MRKR_STEP2				= 11001302
local MRKR_STEP3				= 11001303
local MRKR_STEP4				= 11001304
local MRKR_STEP5				= 11001305
local MRKR_STEP6				= 11001306

-- Quest Flags
local FLAG_VISITED			= 0
local FLAG_TALKED_TATARU		= 1
local FLAG_DUTY_COMPLETE		= 2

-- Other
local MIN_TATARU_WAIT_TIME 	= 20

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	local data = quest:GetData()
	quest:SetTimeUpdate(false)

	-- Sequence changing ENpcs
	if sequence == SEQ_000 then
		quest:SetENpc(EVENT_DOOR_OFFICE_W, QFLAG_PUSH, false, true)
		quest:SetENpc(TATARU)
	elseif sequence == SEQ_005 then
		quest:SetENpc(MINFILIA, QFLAG_TALK)
		quest:SetENpc(EVENT_DOOR_OFFICE_W, QFLAG_PUSH, false, true)
		quest:SetENpc(EVENT_DOOR_OFFICE_E, QFLAG_OFF, false, true)
		quest:SetENpc(TATARU)
	elseif sequence == SEQ_010 then
		quest:SetENpc(MINFILIA, QFLAG_TALK)
		quest:SetENpc(EVENT_DOOR_OFFICE_W, QFLAG_PUSH, false, true)
		quest:SetENpc(EVENT_DOOR_OFFICE_E, QFLAG_OFF, false, true)
		quest:SetENpc(TATARU)
	elseif sequence == SEQ_020 then
		quest:SetENpc(TATARU, QFLAG_TALK)
		quest:SetENpc(MINFILIA)
	elseif sequence == SEQ_025 then
		quest:SetENpc(TATARU)
		quest:GetData():SetTimeNow()
		quest:SetTimeUpdate(true)
	elseif sequence == SEQ_027 then
		if quest:GetData():GetFlag(FLAG_DUTY_COMPLETE) then
			quest:SetENpc(MOMODI, QFLAG_TALK)
			quest:SetENpc(TATARU)
		else
			quest:SetENpc(TATARU, QFLAG_TALK)
			quest:SetENpc(SNPC_START + player:GetSNpcSkin())
		end
	end

	-- All the other ENpcs in the Waking Sands
	quest:SetENpc(MARKET_ENTRENCE, QFLAG_OFF, false, true)
	quest:SetENpc(EVENT_DOOR_EXIT, QFLAG_PUSH, false, true)
	quest:SetENpc(SATZFLOH)
	quest:SetENpc(PERCEVAINS)
	quest:SetENpc(UNA_TAYUUN)
	quest:SetENpc(ROUGH_SPOKEN_FELLOW)
	quest:SetENpc(RED_SHOED_RASCAL)
	quest:SetENpc(ABSTRACTED_GLADIATOR)
	quest:SetENpc(CHAPEAUED_CHAP)
	quest:SetENpc(BARRATROUS_BUCCANEER)
	quest:SetENpc(SOFTHEARTED_SEPTUAGEN)
	quest:SetENpc(INDIGO_EYED_ARCHER)
	quest:SetENpc(LOAM_SCENETED_LADY)
	quest:SetENpc(UNCOMFORTABLE_BRUTE)
	quest:SetENpc(SAHJA_ZHWAN)
	quest:SetENpc(NENEKANI)
	quest:SetENpc(GODFREY)
	quest:SetENpc(FENANA)
	quest:SetENpc(NONORU)
	quest:SetENpc(SERANELIEN)

end

local function playEvent(name)
	return function(player, quest)
		callClientFunction(player, "delegateEvent", player, quest, name)
	end
end

local talk = {
	[SEQ_000] = { [TATARU] = playEvent("processEvent000_2") },
	[SEQ_005] = {
		[MINFILIA] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "pE20", "???", 1, 1, 1, player:GetInitialTown())
			quest:StartSequence(SEQ_010)
		end,
		[TATARU] = playEvent("processEvent000_2"),
	},
	[SEQ_010] = {
		[MINFILIA] = function(player, quest)
			local didJoinPoT = callClientFunction(player, "delegateEvent", player, quest, "pE25", "???", 1, 1, 1, player:GetInitialTown())
			if didJoinPoT == 1 then
				player:EndEvent()
				GetWorldManager():WarpToPosition(player, -142.75, 1, -160, -1.6)
				quest:StartSequence(SEQ_020)
				return true
			end
		end,
		[TATARU] = playEvent("processEvent020_2"),
	},
	[SEQ_020] = {
		-- Selecting a Path Companion
		[TATARU] = function(player, quest)
			local sNpcActorClassId, sNpcPersonality = callClientFunction(player, "delegateEvent", player, quest, "processSnpcSelect", "???", 1, 1, 1, player:GetInitialTown())
			if sNpcActorClassId ~= -1 and sNpcPersonality ~= -1 then
				player:SetSNpc("???", sNpcActorClassId, sNpcPersonality)
				player:AddNpcLs(6)
				quest:StartSequence(SEQ_025)
			end
			player:EndEvent()
			return true
		end,
	},
	[SEQ_025] = {
		[TATARU] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040_2")
			quest:NewNpcLsMsg(6)
		end,
	},
	[SEQ_027] = {
		[MOMODI] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "pE25", "???", 1, 1, 1, player:GetInitialTown())
		end,
		[TATARU] = function(player, quest)
			if not quest:GetData():GetFlag(FLAG_DUTY_COMPLETE) then
				startMan20001Content(player, quest)
				return true
			end
			callClientFunction(player, "delegateEvent", player, quest, "pE050_2", player:GetSNpcNickname(), player:GetSNpcSkin(), player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown())
		end,
		-- The player's companion, any of the companion classes.
		other = function(player, quest, npc)
			local classId = npc:GetActorClassId()
			if classId > SNPC_START and classId < SNPC_END then
				local name = callClientFunction(player, "delegateEvent", player, quest, "pEN", player:GetSNpcPersonality())
				if not name == nil then
					player:SetSNpc(name, player:GetSNpcSkin(), player:GetSNpcPersonality())
					--player:GetDirector("QuestEventMan20001"):SetData("NameSet", true);
				end
			end
		end,
	},
}

-- The Waking Sands crowd, played after the quest's own lines.
local chatter = {
	always = {
		[NONORU] = playEvent("processEvent000_8"),
		[CHAPEAUED_CHAP] = playEvent("processEvent000_9"),
		[ROUGH_SPOKEN_FELLOW] = playEvent("processEvent000_10"),
		[SATZFLOH] = playEvent("processEvent000_18"),
		[PERCEVAINS] = playEvent("processEvent000_19"),
		[UNA_TAYUUN] = playEvent("processEvent000_20"),
	},
	-- The crowd has new lines from SEQ_010, when Minfilia offers the Path of the Twelve.
	other = function(player, quest, npc)
		if quest:GetSequence() < SEQ_010 then
			seq000OnTalkOtherNpcs(player, quest, npc)
		else
			seq010OnTalkOtherNpcs(player, quest, npc)
		end
	end,
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	runQuestHandler(chatter, player, quest, npc)
	player:EndEvent()
	quest:UpdateENPCs()
end

function seq000OnTalkOtherNpcs(player, quest, npc)
	local classId = npc:GetActorClassId()

	if classId == SERANELIEN then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_3")
	elseif classId == SAHJA_ZHWAN then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_4")
	elseif classId == NENEKANI then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_5")
	elseif classId == GODFREY then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_6")
	elseif classId == FENANA then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_7")
	elseif classId == LOAM_SCENETED_LADY then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_11")
	elseif classId == SOFTHEARTED_SEPTUAGEN then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_12")
	elseif classId == INDIGO_EYED_ARCHER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_13")
	elseif classId == BARRATROUS_BUCCANEER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_14")
	elseif classId == UNCOMFORTABLE_BRUTE then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_15")
	elseif classId == RED_SHOED_RASCAL then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_16")
	elseif classId == ABSTRACTED_GLADIATOR then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_17")
	end
end

function seq010OnTalkOtherNpcs(player, quest, npc)
	local classId = npc:GetActorClassId()

	if classId == SERANELIEN then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_3")
	elseif classId == SAHJA_ZHWAN then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_4")
	elseif classId == NENEKANI then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_5")
	elseif classId == GODFREY then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_6")
	elseif classId == FENANA then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_7")
	elseif classId == LOAM_SCENETED_LADY then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_8")
	elseif classId == SOFTHEARTED_SEPTUAGEN then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_9")
	elseif classId == INDIGO_EYED_ARCHER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_10")
	elseif classId == BARRATROUS_BUCCANEER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_11")
	elseif classId == UNCOMFORTABLE_BRUTE then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_12")
	elseif classId == RED_SHOED_RASCAL then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_13")
	elseif classId == ABSTRACTED_GLADIATOR then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_14")
	end
end

local function enterPast(player)
	player:EndEvent()
	GetWorldManager():DoZoneChange(player, 181, "PrivateAreaMasterPast", 0, 15, -205.25, 0, -160, 1.55)
	return true
end

local function enterOffice(player)
	player:EndEvent()
	GetWorldManager():WarpToPosition(player, -126.2, 1.2, -160, 1.6)
	return true
end

local push = {
	[SEQ_000] = {
		[MARKET_ENTRENCE] = function(player, quest, npc, data)
			if not data:GetFlag(FLAG_VISITED) then
				data:SetFlag(FLAG_VISITED)
				callClientFunction(player, "delegateEvent", player, quest, "pE00", "???", 1, 1, 1, player:GetInitialTown())
			end
			return enterPast(player)
		end,
		[EVENT_DOOR_OFFICE_W] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "pE10", "???", 1, 1, 1, player:GetInitialTown())
			quest:StartSequence(SEQ_005)
			return enterOffice(player)
		end,
	},
	always = {
		[MARKET_ENTRENCE] = enterPast,
		[EVENT_DOOR_EXIT] = function(player)
			player:EndEvent()
			GetWorldManager():DoZoneChange(player, 175, nil, 0, 15, -216.52, 190, 30.5, 2.32)
		end,
		[EVENT_DOOR_OFFICE_W] = enterOffice,
		[EVENT_DOOR_OFFICE_E] = function(player)
			player:EndEvent()
			GetWorldManager():WarpToPosition(player, -142.75, 1, -160, -1.6)
			return true
		end,
	},
}

function onPush(player, quest, npc)
	if runQuestHandler(push, player, quest, npc, quest:GetData()) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

function onTimeUpdate(player, quest, currentTime)
	local seqStartTime = quest:GetData():GetTime()
	local sequence = quest:GetSequence()

	if sequence == SEQ_025 then
		if currentTime - seqStartTime > MIN_TATARU_WAIT_TIME then
			quest:SetTimeUpdate(false)
			quest:NewNpcLsMsg(6)
		end
	end
end

function onNpcLS(player, quest, from, msgStep)
	local sequence = quest:GetSequence()

	if from == 6 then
		player:SendGameMessageLocalizedDisplayName(quest, 435, MESSAGE_TYPE_NPC_LINKSHELL, 1500054)
		quest:EndOfNpcLsMsgs()
		quest:StartSequence(SEQ_027)
	end

	player:EndEvent()
end

function getJournalInformation(player, quest)
	if quest:GetData():GetFlag(FLAG_DUTY_COMPLETE) then
		return 1, 0, 0, 0, 0, player:GetSNpcNickname()
	end
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_STEP1
	elseif sequence == SEQ_005 then
		return MRKR_STEP2
	elseif sequence == SEQ_010 then
		return MRKR_STEP3
	elseif sequence == SEQ_020 then
		return MRKR_STEP4
	elseif sequence == SEQ_025 then
		return MRKR_STEP5
	elseif sequence == SEQ_027 then
		return MRKR_STEP6
	end
end

function startMan20001Content(player, quest)
	local result = callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass")
	if result == 1 then
		callClientFunction(player, "delegateEvent", player, quest, "pE050", player:GetSNpcNickname(), player:GetSNpcSkin(), player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown())
		-- DO NAMING DUTY HERE
		-- For now just skip the sequence
		player:EndEvent()
		GetWorldManager():DoZoneChange(player, 230, nil, 0, 0, -639.325, 1, 403.967, 1.655)

		local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "man20001", "SimpleContent30002", "Quest/QuestDirectorEventMan20001")

		if contentArea == nil then
			return
		end

		director = contentArea:GetContentDirector()
		player:AddDirector(director)
		director:StartDirector(false)
		GetWorldManager():DoZoneChangeContent(player, contentArea, -200, 0 -160, -1.6, 2)
		return
	end
	player:EndEvent()
end