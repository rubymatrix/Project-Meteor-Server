require("Global")
require("Quest")

local giveWantedItem

--[[

Quest Script

Name:   Private Eyes 
Code:   Etc5l1
Id:     110839
Prereq: Level 15.  Man5g1 (In Plain Sight) complete.  [110829]
Notes: 

]]

-- Sequence Numbers
local SEQ_000 = 0  -- Talk to Bertrand
local SEQ_010 = 10 -- Head to the meeting point.

-- Actor Class Ids
local OTOPA_POTTOPA           = 1000864
local MYTESYN                 = 1000167
local MIZZENMAST_BED          = 1200378
local BERTRAND                = 1001903 -- 1060004 also a valid ID, but doesn't look like the NPC appeared anywhere else?
local ABRAHAM                 = 1002066
local PRIVATE_AREA_ENTRANCE   = 1090087 -- Check that this ID is free to use before merge
local PRIVATE_AREA_EXIT       = 1290002
local CUTSCENE_PUSH_TRIGGER   = 1090088 -- Check that this ID is free to use before merge

-- Prop Actor Ids (for documentation sake)
local BRONZE_CHEST            = 1080056 -- bgObj 20923 w/ body 1024
local GLASS_DRINK             = 1080057 -- bgObj 20901 w/ body 26624
local RECTANGULAR_BOX         = 1080058 -- bgObj 20951 w/ body 1024

-- Quest Items
local ITEM_WANTED_GAUWYN      = 10011243

-- Quest Markers
local MRKR_CAVE               = 11072101
local MRKR_BERTRAND           = 11072102
local MRKR_CUTSCENE           = 11072103



function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end


function onStateChange(player, quest, sequence)

	if sequence == SEQ_ACCEPT then
		local hasQuestItem = player:GetItemPackage(INVENTORY_NORMAL):HasItem(ITEM_WANTED_GAUWYN)
		local otopaFlag = 0

		if hasQuestItem == false then
			otopaFlag = 2
		end
		quest:SetENpc(OTOPA_POTTOPA, otopaFlag)
		quest:SetENpc(MYTESYN, QFLAG_TALK) -- Assuming this functions the same as it did in Etc5g1
		quest:SetENpc(MIZZENMAST_BED, 5)

	elseif sequence == SEQ_000 then
		quest:SetENpc(MYTESYN)
		quest:SetENpc(PRIVATE_AREA_ENTRANCE, QFLAG_PUSH, false, true, false, true)
		quest:SetENpc(BERTRAND, QFLAG_TALK)
		quest:SetENpc(ABRAHAM)
	elseif sequence == SEQ_010 then
		quest:SetENpc(CUTSCENE_PUSH_TRIGGER, QFLAG_PUSH,false, true, false, true)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		-- Am assuming this all functions the same as it did in Etc5g1
		[OTOPA_POTTOPA] = function(player, quest, npc)
			local hasQuestItem = player:GetItemPackage(INVENTORY_NORMAL):HasItem(ITEM_WANTED_GAUWYN)

			if not hasQuestItem then
				callClientFunction(player, "delegateEvent", player, quest, "processEventOTOPAPOTTOPAStart")
				giveWantedItem(player)
				npc:SetQuestGraphic(player, QFLAG_OFF)
			else
				callClientFunction(player, "delegateEvent", player, quest, "processEventOTOPAPOTTOPAStart_2")
			end
			player:SendGameMessage(player, GetWorldMaster(), 51148, MESSAGE_TYPE_SYSTEM, 10011243, 1070)  -- Log out in Mizzenmast Inn w/ item.
		end,
		[MYTESYN] = function(player, quest, npc)
			player:SendGameMessage(player, GetWorldMaster(), 51148, MESSAGE_TYPE_SYSTEM, 10011243, 1070)
		end,
	},
	[SEQ_000] = {
		[MYTESYN] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_000_1")
		end,
		[BERTRAND] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010")
			quest:UpdateENPCs() -- Band-aid for a QFLAG_TALK issue
			quest:StartSequence(SEQ_010)
			GetWorldManager():WarpToPublicArea(player)
		end,
		[ABRAHAM] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_1")
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end

	player:EndEvent()
	quest:UpdateENPCs()
end



function onPush(player, quest, npc)
	local choice
	local classId = npc:GetActorClassId()


	if classId == PRIVATE_AREA_ENTRANCE then
		choice = callClientFunction(player, "delegateEvent", player, quest, "instanceAreaJoinAskInBasaClass")
		if choice == 1 then
			GetWorldManager():WarpToPrivateArea(player, "PrivateAreaMasterPast", 5, -220.948, 16.603, -92.863, -2.090)
		end

	elseif classId == CUTSCENE_PUSH_TRIGGER then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_020")
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 500, 1, 1)
		player:CompleteQuest(quest)
	end
	player:EndEvent()
end



function getJournalInformation(player, quest)
end


function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_CAVE
		-- TO-DO: Check for private area and use MRKR_BERTRAND in place of this
	elseif sequence == SEQ_010 then
		return MRKR_CUTSCENE
	end
end


function giveWantedItem(player)

	local invCheck = player:GetItemPackage(INVENTORY_NORMAL):AddItem(ITEM_WANTED_GAUWYN, 1, 1)

	if invCheck == INV_ERROR_FULL then
		-- Your inventory is full.
		player:SendGameMessage(player, GetWorldMaster(), 60022, MESSAGE_TYPE_SYSTEM_ERROR)
	elseif invCheck == INV_ERROR_ALREADY_HAS_UNIQUE then
		-- You cannot have more than one <itemId> <quality> in your possession at any given time.
		player:SendGameMessage(player, GetWorldMaster(), 40279, MESSAGE_TYPE_SYSTEM_ERROR, ITEM_WANTED_GAUWYN, 1)
	elseif invCheck == INV_ERROR_SYSTEM_ERROR then
		player:SendMessage(MESSAGE_TYPE_SYSTEM, "", "[DEBUG] Server Error on adding item.")
	elseif invCheck == INV_ERROR_SUCCESS then
		player:SendGameMessage(player, GetWorldMaster(), 25246, MESSAGE_TYPE_SYSTEM_ERROR, ITEM_WANTED_GAUWYN, 1)
	end
end