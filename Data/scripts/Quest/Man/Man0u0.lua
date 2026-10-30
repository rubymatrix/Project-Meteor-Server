require("Global")
require("Quest")
require("Tutorial")

--[[

Quest Script

Name:   Flowers for All
Code:   Man0u0
Id:     110009
Prereq: None (Given on chara creation)
Notes: RURURAJI scripting handled via PopulaceChocoboLender.lua
TO-DO: Sequence 000 - Crowd NPCs.
       Sequence 010 - Adv. Guild NPCs


https://www.youtube.com/watch?v=XXGrSFrfYo4

]]

local seq000_onTalk, seq010_onTalk, areLessonsDone, saveFlag, doExitTrigger

-- Sequence Numbers
local SEQ_000 = 0  -- On the Merchant Strip in Ul'dah; contains the basic tutorial.
SEQ_005 = 5  -- Combat on the Sapphire Avenue Exchange
local SEQ_010 = 10 -- Back on the Merchant Strip in Ul'dah

-- Actor Class Ids
local ASCILIA                 = 1000042
local WARBURTON               = 1000186
local RURURAJI                = 1000840
local BIG_BELLIED_BARKER      = 1001490
local FRETFUL_FARMHAND        = 1001491
local DEBAUCHED_DEMONESS      = 1001492
local DAPPER_DAN              = 1001493
local LOUTISH_LAD             = 1001494
local GIL_DIGGING_MISTRESS    = 1001495
local TWITTERING_TOMBOY       = 1001496
local STOCKY_STRANGER         = 1001644
local EXIT_TRIGGER            = 1090372
local OPENING_STOPER_ULDAH    = 1090373



local KEEN_EYED_MERCHANT      = 1000401
--MUMPISH_MIQOTE          = 1000992; -- Unused on this client version.  Calls processEvent020_6
local HIGH_SPIRITED_FELLOW    = 1001042
local DISREPUTABLE_MIDLANDER  = 1001044
local LONG_LEGGED_LADY        = 1001112
local LARGE_LUNGED_LABORER    = 1001645
local TOOTH_GRINDING_TRAVELER = 1001646
local FULL_LIPPED_FILLE       = 1001647
local YAYATOKI                = 1500129

local BLOCKER                 = 1090372
local ULDAH_OPENING_EXIT      = 1099046

-- Non-interactive NPCs
local CROWD_HYUR_M            = 1001114
local CROWD_HYUR_F            = 1001115
local CROWD_ELEZEN_M          = 1001116
local CROWD_ELEZEN_F          = 1001117
local CROWD_LALAFELL_M        = 1001118
local CROWD_LALAFELL_F        = 1001119
local CROWD_MIQOTE            = 1001120
local CROWD_ROEGADYN          = 1001121
local GUILD_KIORA             = 1000780
local GUILD_OPONDHAO          = 1000781
local GUILD_BERTRAM           = 1000782
local GUILD_MINERVA           = 1000783
local GUILD_ZOENGTERBIN       = 1000784
local GUILD_STYRMOEYA         = 1000785
local GUILD_YHAH_AMARIYO      = 1000786
local GUILD_HILDIE            = 1000787
local GUILD_LETTICE           = 1000788
local GUILD_TYON              = 1000789
local GUILD_OTOPA_POTTOPA     = 1000864
local GUILD_THAISIE           = 1000865
local GUILD_SESEBARU          = 1001182
local GUILD_TOTONAWA          = 1001371
local GUILD_EUSTACE           = 1001372


-- Quest Markers
local MRKR_YAYATOKI               = 11000901
local MRKR_ASCILIA                = 11000902
local MRKR_FRETFUL_FARMHAND       = 11000903
local MRKR_GIL_DIGGING_MISTRESS   = 11000904
local MRKR_COMBAT_TUTORIAL        = 11000905
local MRKR_ADV_GUILD              = 11000906


-- Quest Flags
local FLAG_SEQ000_MINITUT0    = 0 -- PushEvent ASCILIA
local FLAG_SEQ000_MINITUT1    = 1 -- TalkEvent ASCILIA
local FLAG_SEQ000_MINITUT2    = 2 -- TalkEvent FRETFUL_FARMHAND
local FLAG_SEQ000_MINITUT3    = 3 -- TalkEvent GIL_DIGGING_MISTRESS
local FLAG_SEQ000_PUSHTUT     = 4 -- Saw the targeting tutorial Ascilia's push plays.

local FLAG_SEQ010_TALK0       = 0 -- TalkEvent YAYATOKI


function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	local data = quest:GetData()

	if sequence == SEQ_000 then
		-- Setup states incase we loaded in.
		local asciliaCanPush = not data:GetFlag(FLAG_SEQ000_MINITUT0)
		local asciliaFlag = data:GetFlag(FLAG_SEQ000_MINITUT1) and QFLAG_OFF or QFLAG_TALK
		local fretfulfarmhandFlag = data:GetFlag(FLAG_SEQ000_MINITUT2) and QFLAG_OFF or QFLAG_TALK
		local gildiggingmistressFlag = data:GetFlag(FLAG_SEQ000_MINITUT3) and QFLAG_OFF or QFLAG_TALK

		local exitFlag = areLessonsDone(data) and QFLAG_PUSH or QFLAG_OFF

		if asciliaCanPush then
			fretfulfarmhandFlag = QFLAG_OFF
			gildiggingmistressFlag = QFLAG_OFF
		end

		--SetENpc(classId, byte flagType=0,isTalkEnabled, isPushEnabled, isEmoteEnabled, isSpawned)
		quest:SetENpc(ASCILIA, asciliaFlag, true, asciliaCanPush)
		quest:SetENpc(WARBURTON)
		quest:SetENpc(RURURAJI)
		quest:SetENpc(BIG_BELLIED_BARKER)
		quest:SetENpc(FRETFUL_FARMHAND, fretfulfarmhandFlag)
		quest:SetENpc(DEBAUCHED_DEMONESS)
		quest:SetENpc(DAPPER_DAN)
		quest:SetENpc(LOUTISH_LAD)
		quest:SetENpc(GIL_DIGGING_MISTRESS, gildiggingmistressFlag)
		quest:SetENpc(TWITTERING_TOMBOY)
		quest:SetENpc(STOCKY_STRANGER)
		quest:SetENpc(EXIT_TRIGGER, exitFlag, false, true)
		quest:SetENpc(OPENING_STOPER_ULDAH, QFLAG_OFF, false, false, true)

	elseif sequence == SEQ_010 then
		local yayatokiFlag = data:GetFlag(FLAG_SEQ010_TALK0) and QFLAG_OFF or QFLAG_TALK
		local uldahopeningexitFlag = QFLAG_PUSH
		quest:SetENpc(KEEN_EYED_MERCHANT)
		quest:SetENpc(HIGH_SPIRITED_FELLOW)
		quest:SetENpc(DISREPUTABLE_MIDLANDER)
		quest:SetENpc(LONG_LEGGED_LADY)
		quest:SetENpc(LARGE_LUNGED_LABORER)
		quest:SetENpc(TOOTH_GRINDING_TRAVELER)
		quest:SetENpc(FULL_LIPPED_FILLE)
		quest:SetENpc(YAYATOKI, yayatokiFlag)
		quest:SetENpc(BLOCKER, QFLAG_OFF, false, true)
		quest:SetENpc(ULDAH_OPENING_EXIT, uldahopeningexitFlag, false, true)
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
		if classId == ASCILIA and not data:GetFlag(FLAG_SEQ000_PUSHTUT) and not data:GetFlag(FLAG_SEQ000_MINITUT0) then
			-- A click on Ascilia during the tutorial reaches the server as the tutorial ends and leaves
			-- the client locked, so her talk stays off until it is over.
			quest:SetENpc(ASCILIA, QFLAG_TALK, false, false)
			callClientFunction(player, "delegateEvent", player, quest, "processTtrNomal002")
			saveFlag(quest, FLAG_SEQ000_PUSHTUT)
		elseif classId == EXIT_TRIGGER then
			if areLessonsDone(data) then
				doExitTrigger(player, quest, npc)
				return
			else
				callClientFunction(player, "delegateEvent", player, quest, "processTtrBlkNml001")
				player:EndEvent()
				GetWorldManager():DoPlayerMoveInZone(player, -22, 196, 87, 2.4)
				return
			end
		end
	elseif sequence == SEQ_010 then
		if classId == BLOCKER then
			if player.positionZ >= 71 and player.positionZ <= 95 then
				callClientFunction(player, "delegateEvent", player, quest, "processTtrBlkNml002")
				player:EndEvent()
				GetWorldManager():DoPlayerMoveInZone(player, -22.81, 196, 87.82, 2.98)
			else
				callClientFunction(player, "delegateEvent", player, quest, "processTtrBlkNml003")
				player:EndEvent()
				GetWorldManager():DoPlayerMoveInZone(player, -0.3, 196, 116, -2.7)
			end
			return
		elseif classId == ULDAH_OPENING_EXIT then
			-- Court in the Sands plays its opening inside this event and warps to the guild echo.
			player:ReplaceQuest(quest, "Man0u1")
			return
		end
	end
	player:EndEvent()
	quest:UpdateENPCs()
end

function onNotice(player, quest, target)
	callClientFunction(player, "delegateEvent", player, quest, "processTtrNomal001withHQ")
	player:EndEvent()
	quest:UpdateENPCs()
end

function seq000_onTalk(player, quest, npc, classId)
	local data = quest:GetData()

	if classId == ASCILIA then
		if not data:GetFlag(FLAG_SEQ000_MINITUT0) then -- If Talk tutorial
			if data:GetFlag(FLAG_SEQ000_PUSHTUT) then
				callClientFunction(player, "delegateEvent", player, quest, "processTtrNomal003")
				saveFlag(quest, FLAG_SEQ000_MINITUT0) -- Used to disable her PushEvent / Allow for her next TalkEvent
			end
		else
			callClientFunction(player, "delegateEvent", player, quest, "processTtrMini001")
			saveFlag(quest, FLAG_SEQ000_MINITUT1)
		end

	elseif classId == FRETFUL_FARMHAND then
		if not data:GetFlag(FLAG_SEQ000_MINITUT2) then
			callClientFunction(player, "delegateEvent", player, quest, "processTtrMini002_first")
			saveFlag(quest, FLAG_SEQ000_MINITUT2)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processTtrMini002")
		end

	elseif classId == GIL_DIGGING_MISTRESS then
		if not data:GetFlag(FLAG_SEQ000_MINITUT3) then
			callClientFunction(player, "delegateEvent", player, quest, "processTtrMini003_first")
			saveFlag(quest, FLAG_SEQ000_MINITUT3)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processTtrMini003")
		end

	elseif classId == WARBURTON then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_3")
	elseif classId == RURURAJI then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_13")
	elseif classId == BIG_BELLIED_BARKER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_6")
	elseif classId == DEBAUCHED_DEMONESS then
		 callClientFunction(player, "delegateEvent", player, quest, "processEvent000_8")
	elseif classId == DAPPER_DAN then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_9")
	elseif classId == LOUTISH_LAD then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_10")
	elseif classId == TWITTERING_TOMBOY then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_12")
	elseif classId == STOCKY_STRANGER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_6_2")
	end

	player:EndEvent()
end

function seq010_onTalk(player, quest, npc, classId)
	if classId == KEEN_EYED_MERCHANT then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_2")
	elseif classId == HIGH_SPIRITED_FELLOW then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_3")
	elseif classId == DISREPUTABLE_MIDLANDER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_4")
	elseif classId == LONG_LEGGED_LADY then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_14")
	elseif classId == LARGE_LUNGED_LABORER then
		callClientFunction(player, "delegateEvent", player, quest, "processEtc003")
	elseif classId == TOOTH_GRINDING_TRAVELER then
		callClientFunction(player, "delegateEvent", player, quest, "processEtc001")
	elseif classId == FULL_LIPPED_FILLE then
		callClientFunction(player, "delegateEvent", player, quest, "processEtc002")
	elseif classId == YAYATOKI then
		if not quest:GetData():GetFlag(FLAG_SEQ010_TALK0) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_8")
			saveFlag(quest, FLAG_SEQ010_TALK0)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_8")
		end
	end

	player:EndEvent()
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	local data = quest:GetData()
	local possibleMarkers = {}

	if sequence == SEQ_000 then
		if data:GetFlag(FLAG_SEQ000_MINITUT0) then
			if not data:GetFlag(FLAG_SEQ000_MINITUT1) then table.insert(possibleMarkers, MRKR_ASCILIA) end
			if not data:GetFlag(FLAG_SEQ000_MINITUT2) then table.insert(possibleMarkers, MRKR_FRETFUL_FARMHAND) end
			if not data:GetFlag(FLAG_SEQ000_MINITUT3) then table.insert(possibleMarkers, MRKR_GIL_DIGGING_MISTRESS) end
		end
	elseif sequence == SEQ_005 then
		table.insert(possibleMarkers, MRKR_COMBAT_TUTORIAL)

	elseif sequence == SEQ_010 then
		if not data:GetFlag(FLAG_SEQ010_TALK0) then
			table.insert(possibleMarkers, MRKR_YAYATOKI)
		end
			table.insert(possibleMarkers, MRKR_ADV_GUILD)
	end

	return unpack(possibleMarkers)
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

function doExitTrigger(player, quest, npc)
	quest:GetData():ClearData()
	quest:StartSequence(SEQ_005)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "man0u01", "SimpleContent30079", "Quest/QuestDirectorMan0u001")

	if contentArea == nil then
		player:EndEvent()
		return
	end

	local director = contentArea:GetContentDirector()
	player:AddDirector(director)
	director:StartDirector(false)
	player:SetLoginDirector(director)

	-- The push event ends before the kick: a notice kicked inside it is corrupted on the client.
	player:EndEvent()
	player:KickEvent(director, "noticeEvent", true)

	GetWorldManager():DoZoneChangeContent(player, contentArea, -24.34, 192, 34.22, 0.78, 16)
end

-- Called by QuestDirectorMan0u001 from its noticeEvent.
function finishSkirmish(player, quest, duty, contentArea)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent020", nil, nil, nil)
	quest:StartSequence(SEQ_010)
	endTutorialMode(player)
	player:EndEvent()
	if duty ~= nil then
		duty:Close()
	end
	if contentArea ~= nil then
		contentArea:ContentFinished()
	end
	GetWorldManager():DoZoneChange(player, 175, "PrivateAreaMasterPast", 3, 15, -22.81, 196, 87.82, 2.98)
end
