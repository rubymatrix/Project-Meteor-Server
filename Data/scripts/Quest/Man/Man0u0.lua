require("Global")
require("Quest")
require("Tutorial")

--[[
Flowers for All (Man0u0, 110009). Given at character creation: the Ul'dah opening tutorial.
Rururaji's chocobo lending is in PopulaceChocoboLender.lua. The Seq 000 crowd and the Seq 010
Adventurers' Guild NPCs have no talk yet. Notes: Data/Docs/Scripts/Quest/Man/Man0u0.md.
--]]

local areLessonsDone, saveFlag, doExitTrigger

local SEQ_000 = 0  -- On the Merchant Strip in Ul'dah; contains the basic tutorial.
SEQ_005 = 5  -- Combat on the Sapphire Avenue Exchange
local SEQ_010 = 10 -- Back on the Merchant Strip in Ul'dah

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


local MRKR_YAYATOKI               = 11000901
local MRKR_ASCILIA                = 11000902
local MRKR_FRETFUL_FARMHAND       = 11000903
local MRKR_GIL_DIGGING_MISTRESS   = 11000904
local MRKR_COMBAT_TUTORIAL        = 11000905
local MRKR_ADV_GUILD              = 11000906


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

local function say(fn)
	return function(player, quest)
		callClientFunction(player, "delegateEvent", player, quest, fn)
	end
end

local function lesson(flag, fnFirst, fn)
	return function(player, quest)
		if not quest:GetData():GetFlag(flag) then
			callClientFunction(player, "delegateEvent", player, quest, fnFirst)
			saveFlag(quest, flag)
		else
			callClientFunction(player, "delegateEvent", player, quest, fn)
		end
	end
end

local talk = {
	[SEQ_000] = {
		[ASCILIA] = function(player, quest)
			local data = quest:GetData()
			if not data:GetFlag(FLAG_SEQ000_MINITUT0) then
				if data:GetFlag(FLAG_SEQ000_PUSHTUT) then
					callClientFunction(player, "delegateEvent", player, quest, "processTtrNomal003")
					saveFlag(quest, FLAG_SEQ000_MINITUT0) -- Turns her push off and opens her next talk.
				end
			else
				callClientFunction(player, "delegateEvent", player, quest, "processTtrMini001")
				saveFlag(quest, FLAG_SEQ000_MINITUT1)
			end
		end,
		[FRETFUL_FARMHAND] = lesson(FLAG_SEQ000_MINITUT2, "processTtrMini002_first", "processTtrMini002"),
		[GIL_DIGGING_MISTRESS] = lesson(FLAG_SEQ000_MINITUT3, "processTtrMini003_first", "processTtrMini003"),
		[WARBURTON] = say("processEvent000_3"),
		[RURURAJI] = say("processEvent000_13"),
		[BIG_BELLIED_BARKER] = say("processEvent000_6"),
		[DEBAUCHED_DEMONESS] = say("processEvent000_8"),
		[DAPPER_DAN] = say("processEvent000_9"),
		[LOUTISH_LAD] = say("processEvent000_10"),
		[TWITTERING_TOMBOY] = say("processEvent000_12"),
		[STOCKY_STRANGER] = say("processEvent000_6_2"),
	},
	[SEQ_010] = {
		[KEEN_EYED_MERCHANT] = say("processEvent020_2"),
		[HIGH_SPIRITED_FELLOW] = say("processEvent020_3"),
		[DISREPUTABLE_MIDLANDER] = say("processEvent020_4"),
		[LONG_LEGGED_LADY] = say("processEvent000_14"),
		[LARGE_LUNGED_LABORER] = say("processEtc003"),
		[TOOTH_GRINDING_TRAVELER] = say("processEtc001"),
		[FULL_LIPPED_FILLE] = say("processEtc002"),
		[YAYATOKI] = lesson(FLAG_SEQ010_TALK0, "processEvent020_8", "processEvent020_8"),
	},
}

function onTalk(player, quest, npc)
	local inTown = talk[quest:GetSequence()] ~= nil
	runQuestHandler(talk, player, quest, npc)
	if inTown then
		player:EndEvent()
	end
	quest:UpdateENPCs()
end

local push = {
	[SEQ_000] = {
		[ASCILIA] = function(player, quest)
			local data = quest:GetData()
			if data:GetFlag(FLAG_SEQ000_PUSHTUT) or data:GetFlag(FLAG_SEQ000_MINITUT0) then return end
			-- A click on Ascilia during the tutorial reaches the server as the tutorial ends and leaves
			-- the client locked, so her talk stays off until it is over.
			quest:SetENpc(ASCILIA, QFLAG_TALK, false, false)
			callClientFunction(player, "delegateEvent", player, quest, "processTtrNomal002")
			saveFlag(quest, FLAG_SEQ000_PUSHTUT)
		end,
		[EXIT_TRIGGER] = function(player, quest, npc)
			if areLessonsDone(quest:GetData()) then
				doExitTrigger(player, quest, npc)
				return true
			end
			callClientFunction(player, "delegateEvent", player, quest, "processTtrBlkNml001")
			player:EndEvent()
			GetWorldManager():DoPlayerMoveInZone(player, -22, 196, 87, 2.4)
			return true
		end,
	},
	[SEQ_010] = {
		[BLOCKER] = function(player, quest)
			if player.positionZ >= 71 and player.positionZ <= 95 then
				callClientFunction(player, "delegateEvent", player, quest, "processTtrBlkNml002")
				player:EndEvent()
				GetWorldManager():DoPlayerMoveInZone(player, -22.81, 196, 87.82, 2.98)
			else
				callClientFunction(player, "delegateEvent", player, quest, "processTtrBlkNml003")
				player:EndEvent()
				GetWorldManager():DoPlayerMoveInZone(player, -0.3, 196, 116, -2.7)
			end
			return true
		end,
		-- Court in the Sands plays its opening inside this event and warps to the guild echo.
		[ULDAH_OPENING_EXIT] = function(player, quest)
			player:ReplaceQuest(quest, "Man0u1")
			return true
		end,
	},
}

function onPush(player, quest, npc)
	if runQuestHandler(push, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

function onNotice(player, quest, target)
	callClientFunction(player, "delegateEvent", player, quest, "processTtrNomal001withHQ")
	player:EndEvent()
	quest:UpdateENPCs()
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
