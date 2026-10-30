require("Global")
require("Quest")
require("Tutorial")

--[[

Quest Script

Name: 	Shapeless Melody
Code: 	Man0l0
Id: 	110001
Prereq: None (Given on chara creation)

]]

local seq000_onTalk, seq010_onTalk, isRostnsthalMarked, isVixenMarked, isBabyfacedMarked, areLessonsDone, saveFlag, doExitDoor

-- Sequence Numbers
local SEQ_000	= 0  -- On the boat interior; contains the basics tutorial.
SEQ_005	= 5  -- Combat on the top of the boat.
local SEQ_010	= 10 -- In Limsa Lominsa's port.

-- Actor Class Ids
local WELLTRAVELED_MERCHANT 	= 1000438
local TIPSY_ADVENTURER 		= 1000439
local CULTIVATED_TENDER 		= 1000440
local ANXIOUS_ADVENTURER 		= 1000441
local BABYFACED_ADVENTURER 	= 1000442
local AUSTERE_ADVENTURER 		= 1000443
local UNDIGNIFIED_ADVENTURER 	= 1000444
local SHADOWY_TRAVELER 		= 1000445
local ASTUTE_MERCHANT 		= 1000446
local VOLUPTUOUS_VIXEN 		= 1000447
local INDIFFERENT_PASSERBY 	= 1000448
local PRATTLING_ADVENTURER 	= 1000449
local LANKY_TRAVELER 			= 1000450
local GRINNING_ADVENTURER 	= 1000451
local ROSTNSTHAL 				= 1001652
local EXIT_TRIGGER 			= 1090025

local HOB						= 1000151
local GERT					= 1500004
local LORHZANT				= 1500005
local MUSCLEBOUND_DECKHAND	= 1000261
local PEARLYTOOTHED_PORTER	= 1000260
--PASTYFACED_ADVENTURER	= 1000264; -- Missing?
local PRIVAREA_PAST_EXIT		= 1290002

-- Quest Markers
local MRKR_HOB					= 11000202
local MRKR_ROSTNSTHAL 			= 11000203
local MRKR_VOLUPTUOUS_VIXEN 		= 11000204
local MRKR_BABYFACED_ADVENTURER 	= 11000205
local MRKR_TRIGGER_DOOR			= 11000206

-- Quest Flags
local FLAG_SEQ000_MINITUT0	= 0 -- Rostnsthal's talk tutorial.
local FLAG_SEQ000_MINITUT1	= 1 -- Rostnsthal's lesson.
local FLAG_SEQ000_MINITUT2	= 2 -- The vixen's lesson.
local FLAG_SEQ000_MINITUT3	= 3 -- The baby-faced adventurer's lesson.
local FLAG_SEQ000_PUSHTUT		= 4 -- Saw the targeting tutorial Rostnsthal's push plays.

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_000 then
		-- Setup states incase we loaded in.
		local data = quest:GetData()

		local rostnsthalFlag = isRostnsthalMarked(data) and QFLAG_TALK or QFLAG_OFF
		local vixenFlag = isVixenMarked(data) and QFLAG_TALK or QFLAG_OFF
		local babyfaceFlag = isBabyfacedMarked(data) and QFLAG_TALK or QFLAG_OFF
		local rostnsthalCanPush = not data:GetFlag(FLAG_SEQ000_MINITUT0)
		local exitCanPush = areLessonsDone(data)
		local exitFlag = exitCanPush and QFLAG_PUSH or QFLAG_OFF

		quest:SetENpc(WELLTRAVELED_MERCHANT)
		quest:SetENpc(TIPSY_ADVENTURER)
		quest:SetENpc(CULTIVATED_TENDER)
		quest:SetENpc(ANXIOUS_ADVENTURER)
		quest:SetENpc(BABYFACED_ADVENTURER, babyfaceFlag)
		quest:SetENpc(AUSTERE_ADVENTURER)
		quest:SetENpc(UNDIGNIFIED_ADVENTURER)
		quest:SetENpc(SHADOWY_TRAVELER)
		quest:SetENpc(ASTUTE_MERCHANT)
		quest:SetENpc(VOLUPTUOUS_VIXEN, vixenFlag)
		quest:SetENpc(INDIFFERENT_PASSERBY)
		quest:SetENpc(PRATTLING_ADVENTURER)
		quest:SetENpc(LANKY_TRAVELER)
		quest:SetENpc(GRINNING_ADVENTURER)
		quest:SetENpc(ROSTNSTHAL, rostnsthalFlag, true, rostnsthalCanPush)
		quest:SetENpc(EXIT_TRIGGER, exitFlag, false, exitCanPush)
	elseif sequence == SEQ_005 then
	elseif sequence == SEQ_010 then
		quest:SetENpc(HOB, QFLAG_TALK)
		quest:SetENpc(GERT)
		quest:SetENpc(LORHZANT)
		quest:SetENpc(MUSCLEBOUND_DECKHAND)
		quest:SetENpc(PEARLYTOOTHED_PORTER)
		quest:SetENpc(UNDIGNIFIED_ADVENTURER)
		quest:SetENpc(WELLTRAVELED_MERCHANT)
		quest:SetENpc(VOLUPTUOUS_VIXEN)
		quest:SetENpc(LANKY_TRAVELER)
		quest:SetENpc(PRIVAREA_PAST_EXIT, QFLAG_OFF, false, true)
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if sequence == SEQ_000 then
		seq000_onTalk(player, quest, npc, classId)
	elseif sequence == SEQ_010 then
		seq010_onTalk(player, quest, npc, classId)
	end

	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	local data = quest:GetData()

	if sequence == SEQ_000 then
		if classId == EXIT_TRIGGER and areLessonsDone(data) then
			doExitDoor(player, quest, npc)
			return
		elseif classId == ROSTNSTHAL and not data:GetFlag(FLAG_SEQ000_PUSHTUT) and not data:GetFlag(FLAG_SEQ000_MINITUT0) then
			-- A click on Rostnsthal during the tutorial reaches the server as the tutorial ends and
			-- leaves the client locked, so his talk stays off until it is over.
			quest:SetENpc(ROSTNSTHAL, QFLAG_TALK, false, false)
			callClientFunction(player, "delegateEvent", player, quest, "processTtrNomal002")
			saveFlag(quest, FLAG_SEQ000_PUSHTUT)
		end
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onNotice(player, quest, target)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		callClientFunction(player, "delegateEvent", player, quest, "processTtrNomal001withHQ")
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function seq000_onTalk(player, quest, npc, classId)
	local data = quest:GetData()

	if classId == WELLTRAVELED_MERCHANT then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_4")
	elseif classId == TIPSY_ADVENTURER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_5")
	elseif classId == CULTIVATED_TENDER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_6")
	elseif classId == ANXIOUS_ADVENTURER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_7")
	elseif classId == BABYFACED_ADVENTURER then
		if isBabyfacedMarked(data) then
			callClientFunction(player, "delegateEvent", player, quest, "processTtrMini003")
			saveFlag(quest, FLAG_SEQ000_MINITUT3)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_8")
		end
	elseif classId == AUSTERE_ADVENTURER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_9")
	elseif classId == UNDIGNIFIED_ADVENTURER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_10")
	elseif classId == SHADOWY_TRAVELER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_11")
	elseif classId == ASTUTE_MERCHANT then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_12")
	elseif classId == VOLUPTUOUS_VIXEN then
		if isVixenMarked(data) then
			callClientFunction(player, "delegateEvent", player, quest, "processTtrMini002")
			saveFlag(quest, FLAG_SEQ000_MINITUT2)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_13")
		end
	elseif classId == INDIFFERENT_PASSERBY then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_14")
	elseif classId == PRATTLING_ADVENTURER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_15")
	elseif classId == LANKY_TRAVELER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_16")
	elseif classId == GRINNING_ADVENTURER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_17")
	elseif classId == ROSTNSTHAL then
		-- Handle the talk tutorial after the push one.
		if not data:GetFlag(FLAG_SEQ000_MINITUT0) then
			if data:GetFlag(FLAG_SEQ000_PUSHTUT) then
				callClientFunction(player, "delegateEvent", player, quest, "processTtrNomal003")
				saveFlag(quest, FLAG_SEQ000_MINITUT0)
			end
		else
			callClientFunction(player, "delegateEvent", player, quest, "processTtrMini001")
			if not data:GetFlag(FLAG_SEQ000_MINITUT1) then
				saveFlag(quest, FLAG_SEQ000_MINITUT1)
			end
		end
	end

	player:EndEvent()
end

function seq010_onTalk(player, quest, npc, classId)
	local data = quest:GetData()

	if classId == MUSCLEBOUND_DECKHAND then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_2")
	elseif classId == PEARLYTOOTHED_PORTER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_3")
	elseif classId == UNDIGNIFIED_ADVENTURER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_5")
	elseif classId == VOLUPTUOUS_VIXEN then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_6")
	elseif classId == WELLTRAVELED_MERCHANT then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_7")
	elseif classId == LANKY_TRAVELER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_8")
	elseif classId == HOB then
		local choice = callClientFunction(player, "delegateEvent", player, quest, "processEvent020_9")
		if choice == 1 then
			-- Treasures of the Main plays its opening inside this event and warps to the guild echo.
			player:ReplaceQuest(quest, "Man0l1")
			return
		end
	elseif classId == GERT then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_10")
	elseif classId == LORHZANT then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_11")
	end

	player:EndEvent()
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	local data = quest:GetData()
	local possibleMarkers = {}

	if sequence == SEQ_000 then
		if isRostnsthalMarked(data) then
			table.insert(possibleMarkers, MRKR_ROSTNSTHAL)
		end
		if isVixenMarked(data) then
			table.insert(possibleMarkers, MRKR_VOLUPTUOUS_VIXEN)
		end
		if isBabyfacedMarked(data) then
			table.insert(possibleMarkers, MRKR_BABYFACED_ADVENTURER)
		end
		if areLessonsDone(data) then
			table.insert(possibleMarkers, MRKR_TRIGGER_DOOR)
		end
	elseif sequence == SEQ_010 then
		table.insert(possibleMarkers, MRKR_HOB)
	end

	return unpack(possibleMarkers)
end

function isRostnsthalMarked(data)
	return not data:GetFlag(FLAG_SEQ000_MINITUT1)
end

function isVixenMarked(data)
	return not data:GetFlag(FLAG_SEQ000_MINITUT2)
end

function isBabyfacedMarked(data)
	return not data:GetFlag(FLAG_SEQ000_MINITUT3)
end

function areLessonsDone(data)
	return data:GetFlag(FLAG_SEQ000_MINITUT0) and data:GetFlag(FLAG_SEQ000_MINITUT1)
		and data:GetFlag(FLAG_SEQ000_MINITUT2) and data:GetFlag(FLAG_SEQ000_MINITUT3)
end

function saveFlag(quest, flag)
	local data = quest:GetData()
	data:SetFlag(flag)
	data:Save()
end

function doExitDoor(player, quest, npc)
	local choice = callClientFunction(player, "delegateEvent", player, quest, "processEventNewRectAsk", nil)
	if choice == 1 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2", nil)

		quest:GetData():ClearData()
		quest:StartSequence(SEQ_005)

		local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "man0l01", "SimpleContent30002", "Quest/QuestDirectorMan0l001")

		if contentArea == nil then
			player:EndEvent()
			return
		end

		local director = contentArea:GetContentDirector()
		player:AddDirector(director)
		director:StartDirector(false)
		player:SetLoginDirector(director)

		-- The talk event ends before the kick: a notice kicked inside it is corrupted on the client.
		player:EndEvent()
		player:KickEvent(director, "noticeEvent", true)

		GetWorldManager():DoZoneChangeContent(player, contentArea, -5, 16.35, 6, 0.5, 16)
		return
	else
		player:EndEvent()
	end
end

-- QuestDirectorMan0l001, the deck battle over, with its noticeEvent open: the landing scene, then
-- the docks echo.
function finishDeckBattle(player, quest, duty, contentArea)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent000_3")
	quest:StartSequence(SEQ_010)
	endTutorialMode(player)
	player:EndEvent()
	if duty ~= nil then
		duty:Close()
	end
	if contentArea ~= nil then
		contentArea:ContentFinished()
	end
	GetWorldManager():DoZoneChange(player, 230, "PrivateAreaMasterPast", 1, 15, -826.868469, 6, 193.745865, -0.008368492)
end
