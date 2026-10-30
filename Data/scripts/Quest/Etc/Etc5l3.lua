require("Global")
require("Quest")

--[[
Prophecy Inspection (Etc5l3, 110841). Prereq: Mysteries of the Red Moon (Man5l2); level 20.
--]]

local giveDossierItem

-- Sequence Numbers
local SEQ_000 = 0  -- Head to the Coffer & Coffin
local SEQ_005 = 5  -- Help out Alret
local SEQ_010 = 10 -- Talk to Alret

-- Actor Class Ids
local KOPURU_FUPURU           = 1002047
local VKOROLON                = 1000458
local MYTESYN                 = 1000167
local COFFER_AND_COFFIN_PUSH  = 1090090
local BED_LIMSA               = 1200378
local BED_GRIDANIA            = 1200379
local BED_ULDAH               = 1200380

local HILDIBRAND              = 1001995
local NASHU_MHAKARACCA        = 1001996
local ALRET                   = 1002114
local BOMB_BANE_1             = 1080090
local BOMB_BANE_2             = 1080091
local BOMB_BANE_3             = 1080092
local BOMB_BANE_4             = 1080093
local BOMB_BANE_5             = 1080094

-- Quest Markers
local MRKR_COFFIN             = 11072204
local MRKR_BANE_1             = 11072205
local MRKR_BANE_2             = 11072206
local MRKR_BANE_3             = 11072207
local MRKR_BANE_4             = 11072208
local MRKR_BANE_5             = 11072209
local MRKR_ALRET              = 11072210

-- Quest Flags
local FLAG_SEQ005_BANE_1      = 0
local FLAG_SEQ005_BANE_2      = 1
local FLAG_SEQ005_BANE_3      = 2
local FLAG_SEQ005_BANE_4      = 3
local FLAG_SEQ005_BANE_5      = 4

local COUNTER_BANE            = 0

local ITEM_HIDLIBRAND_DOSSIER = 10011252
local ITEM_BOMB_BANE          = 11000230



function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end


function onStateChange(player, quest, sequence)
	local data = quest:GetData()

	-- Quest not accepted:  Set up actors to let you retrieve the item & initiate the log-in check at the Inn
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(KOPURU_FUPURU, QFLAG_TALK)
		quest:SetENpc(VKOROLON, QFLAG_TALK)
		quest:SetENpc(MYTESYN, QFLAG_TALK)
		quest:SetENpc(BED_ULDAH, 5)
		quest:SetENpc(BED_GRIDANIA, 5)
		quest:SetENpc(BED_LIMSA, 5)
	-- Quest started
	elseif sequence == SEQ_000 then
		quest:SetENpc(COFFER_AND_COFFIN_PUSH, QFLAG_PUSH, false, true, false, true)
	elseif sequence == SEQ_005 then
		local bane1Flag = data:GetFlag(FLAG_SEQ005_BANE_1) and QFLAG_OFF or QFLAG_TALK
		local bane2Flag = data:GetFlag(FLAG_SEQ005_BANE_2) and QFLAG_OFF or QFLAG_TALK
		local bane3Flag = data:GetFlag(FLAG_SEQ005_BANE_3) and QFLAG_OFF or QFLAG_TALK
		local bane4Flag = data:GetFlag(FLAG_SEQ005_BANE_4) and QFLAG_OFF or QFLAG_TALK
		local bane5Flag = data:GetFlag(FLAG_SEQ005_BANE_5) and QFLAG_OFF or QFLAG_TALK

		quest:SetENpc(COFFER_AND_COFFIN_PUSH, QFLAG_PUSH, false, true, false, true)
		quest:SetENpc(HILDIBRAND)
		quest:SetENpc(NASHU_MHAKARACCA)
		quest:SetENpc(ALRET)
		quest:SetENpc(BOMB_BANE_1, bane1Flag)
		quest:SetENpc(BOMB_BANE_2, bane2Flag)
		quest:SetENpc(BOMB_BANE_3, bane3Flag)
		quest:SetENpc(BOMB_BANE_4, bane4Flag)
		quest:SetENpc(BOMB_BANE_5, bane5Flag)
	-- Quest finished
	elseif sequence == SEQ_010 then
		quest:SetENpc(HILDIBRAND)
		quest:SetENpc(NASHU_MHAKARACCA)
		quest:SetENpc(ALRET, QFLAG_REWARD)
	end
end

local function handOverDossier(player)
	giveDossierItem(player)
	player:SendGameMessage(player, GetWorldMaster(), 51149, MESSAGE_TYPE_SYSTEM, ITEM_HIDLIBRAND_DOSSIER)
end

local function dossierTalk(event)
	return function(player, quest)
		callClientFunction(player, "delegateEvent", player, quest, event)
		handOverDossier(player)
	end
end

local function baneTalk(flag)
	return function(player, quest)
		local data = quest:GetData()
		if data:GetFlag(flag) then
			return
		end
		data:SetFlag(flag)
		local counterAmount = data:IncCounter(COUNTER_BANE)
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_4", counterAmount, 5)
		wait(1)

		if counterAmount >= 5 then
			attentionMessage(player, 25225, quest:GetQuestId()) -- "Seeing the Seers" objectives complete!
			quest:GetData():ClearData()
			quest:UpdateENPCs() -- Band-aid for a QFLAG_TALK issue
			quest:StartSequence(SEQ_010)
		end
	end
end

local function hildibrandTalk(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_1")
end

local function nashuTalk(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_2")
end

local talk = {
	[SEQ_ACCEPT] = {
		[KOPURU_FUPURU] = dossierTalk("processEventKOPURUStart"),
		[VKOROLON] = dossierTalk("processEventKOROLONStart"),
		[MYTESYN] = dossierTalk("processEventMYTESYNStart"),
		other = handOverDossier,
	},
	[SEQ_005] = {
		[HILDIBRAND] = hildibrandTalk,
		[NASHU_MHAKARACCA] = nashuTalk,
		[ALRET] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_3")
		end,
		[BOMB_BANE_1] = baneTalk(FLAG_SEQ005_BANE_1),
		[BOMB_BANE_2] = baneTalk(FLAG_SEQ005_BANE_2),
		[BOMB_BANE_3] = baneTalk(FLAG_SEQ005_BANE_3),
		[BOMB_BANE_4] = baneTalk(FLAG_SEQ005_BANE_4),
		[BOMB_BANE_5] = baneTalk(FLAG_SEQ005_BANE_5),
	},
	[SEQ_010] = {
		[HILDIBRAND] = hildibrandTalk,
		[NASHU_MHAKARACCA] = nashuTalk,
		[ALRET] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_020")
			--TO-DO: Get the scaled EXP for this sqrwa figured out
			--TO-DO: Also confirm reward was issued before flagging quest as complete
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 1000, 1, 1, 9)
			GetWorldManager():WarpToPublicArea(player)
			player:CompleteQuest(quest)
		end,
	},
}

function onTalk(player, quest, npc)
	runQuestHandler(talk, player, quest, npc)
	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if classId == COFFER_AND_COFFIN_PUSH then
		if sequence == SEQ_000 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_005")
			player:EndEvent()
			attentionMessage(player, 25246, ITEM_BOMB_BANE, 1)
			quest:StartSequence(SEQ_005)
		end

		GetWorldManager():WarpToPrivateArea(player, "PrivateAreaMasterPast", 5, -1732.891, 56.119, -307.285, -2.785)
		actor = player.CurrentArea:FindActorInZoneByUniqueID("etc5l3_nashu")
		actor:ChangeState(ACTORSTATE_SITTING_ONFLOOR) -- Band-aid to get her sitting.
	end
	player:EndEvent()
end

function getJournalInformation(player, quest)
	-- Bugged on the client's end and never shows?
	return 0, ITEM_BOMB_BANE
end


function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	local data = quest:GetData()
	local possibleMarkers = {}

	if sequence == SEQ_000 then
		return MRKR_COFFIN

	elseif sequence == SEQ_005 then
		local data = quest:GetData()
		if not data:GetFlag(FLAG_SEQ005_BANE_1) then table.insert(possibleMarkers, MRKR_BANE_1) end
		if not data:GetFlag(FLAG_SEQ005_BANE_2) then table.insert(possibleMarkers, MRKR_BANE_2) end
		if not data:GetFlag(FLAG_SEQ005_BANE_3) then table.insert(possibleMarkers, MRKR_BANE_3) end
		if not data:GetFlag(FLAG_SEQ005_BANE_4) then table.insert(possibleMarkers, MRKR_BANE_4) end
		if not data:GetFlag(FLAG_SEQ005_BANE_5) then table.insert(possibleMarkers, MRKR_BANE_5) end
		return unpack(possibleMarkers)

	elseif sequence == SEQ_010 then
		return MRKR_ALRET
	end
end


function giveDossierItem(player)

	local invCheck = player:GetItemPackage(INVENTORY_NORMAL):AddItem(ITEM_HIDLIBRAND_DOSSIER, 1, 1)

	if invCheck == INV_ERROR_SUCCESS then
		player:SendGameMessage(player, GetWorldMaster(), 25246, MESSAGE_TYPE_SYSTEM_ERROR, ITEM_HIDLIBRAND_DOSSIER, 1)
		return true
	end
end