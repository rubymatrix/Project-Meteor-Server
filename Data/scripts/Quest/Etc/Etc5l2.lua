require("Global")
require("Quest")

local giveWantedItem

--[[

Quest Script

Name:   Mysteries of the Red Moon
Code:   Etc5l2
Id:     110840
Prereq: Level 20.  Man5l1 (Private Eyes) complete.  [110839]
Notes: 

]]

-- Sequence Numbers
local SEQ_000 = 0  -- Investigate the room.
local SEQ_005 = 5  -- Head to the Arrzaneth Ossuary

-- Actor Class Ids
local KOPURU_FUPURU           = 1002047
local BOOK                    = 1200412
local INN_EXIT                = 1090089
local CUTSCENE_PUSH_TRIGGER   = 1090253 -- Already had from capture

-- Quest Markers
local MRKR_KOPURU_FUPURU      = 11072201
local MRKR_BOOK               = 11072202
local MRKR_CUTSCENE           = 11072203

-- Quest Item
local ITEM_HIDLIBRAND_DOSSIER = 10011252

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end


function onStateChange(player, quest, sequence)

	if sequence == SEQ_ACCEPT then
		quest:SetENpc(KOPURU_FUPURU, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(KOPURU_FUPURU, QFLAG_TALK)
		quest:SetENpc(BOOK, QFLAG_TALK)
		quest:SetENpc(INN_EXIT, QFLAG_PUSH, false, true, false, true)
	elseif sequence == SEQ_005 then
		quest:SetENpc(BOOK)
		quest:SetENpc(KOPURU_FUPURU)
		quest:SetENpc(INN_EXIT, QFLAG_PUSH, false, true, false, true)
		quest:SetENpc(CUTSCENE_PUSH_TRIGGER, QFLAG_PUSH,false, true, false, true)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		-- Offer the quest
		[KOPURU_FUPURU] = function(player, quest, npc)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart")
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	-- Quest Progress
	[SEQ_000] = {
		[KOPURU_FUPURU] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_KOPURU")
			GetWorldManager():DoZoneChange(player, 181, "PrivateAreaMasterPast", 5, 15, 0,0,0, player.rotation)
		end,
		[BOOK] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000")
			quest:UpdateENPCs() -- Band-aid for a QFLAG_TALK issue
			quest:StartSequence(SEQ_005)
		end,
	},
	[SEQ_005] = {
		[KOPURU_FUPURU] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_KOPURU")
			GetWorldManager():DoZoneChange(player, 181, "PrivateAreaMasterPast", 5, 15, 0,0,0, player.rotation)
		end,
		[BOOK] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_BOOK")
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end

	player:EndEvent()
	quest:UpdateENPCs()
end



function onPush(player, quest, npc)
	local classId = npc:GetActorClassId()


	if classId == INN_EXIT then
		choice = callClientFunction(player, "delegateEvent", player, quest, "processEventExit")
		if choice == 1 then
		  player:EndEvent()
		  GetWorldManager():DoZoneChange(player, 209, "", 0, 15, -104.296, 203, 162.257, -0.4)
		end
	-- Quest Complete
	elseif classId == CUTSCENE_PUSH_TRIGGER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent005_NQ")
		--TO-DO: Get the scaled EXP for this sqrwa figured out
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 1000, 1, 1, 9)

		player:SendGameMessage(player, GetWorldMaster(), 51149, MESSAGE_TYPE_SYSTEM, ITEM_HIDLIBRAND_DOSSIER)
		local itemCheck = giveWantedItem(player)
		if itemCheck == true then
			player:CompleteQuest(quest)
		end
	end
	player:EndEvent()
end


function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_KOPURU_FUPURU
		-- TO-DO: Check for private area and use MRKR_BOOK in place of this
	elseif sequence == SEQ_005 then
		return MRKR_CUTSCENE
	end
end


function giveWantedItem(player)

	local invCheck = player:GetItemPackage(INVENTORY_NORMAL):AddItem(ITEM_HIDLIBRAND_DOSSIER, 1, 1)

	if invCheck == INV_ERROR_SUCCESS then
		player:SendGameMessage(player, GetWorldMaster(), 25246, MESSAGE_TYPE_SYSTEM_ERROR, ITEM_HIDLIBRAND_DOSSIER, 1)
		return true
	end
end