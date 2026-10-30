require("Global")
require("Quest")

--[[
In Plain Sight (Etc5g1, 110829). Prereq: The Usual Suspect (Etc5u1); level 15.
Otopa Pottopa hands over the wanted poster; Nicoliaux is in a private area entered near the Acorn Orchard.
--]]

local giveWantedItem

local SEQ_000 = 0
local SEQ_010 = 10

local OTOPA_POTTOPA           = 1000864
local VKOROLON                = 1000458
local THE_ROOST_BED           = 1200379
local NICOLIAUX               = 1002071 -- 1000409: Can't use his public area id, otherwise a ! shows on him there also
local POWLE                   = 1000238
local AUNILLIE                = 1000410
local GAUWYN_THE_GANNET       = 1002065
local HILDIBRAND              = 1002067
local NASHU_MHAKARACCA        = 1001996
local PRIVATE_AREA_ENTRANCE   = 1090086
local PRIVATE_AREA_EXIT       = 1290002

local SANSA                   = 1000239
local ELYN                    = 1000411
local RYD                     = 1000412

local ITEM_WANTED_GAUWYN      = 10011243

local MRKR_ACORN_ORCHARD      = 11082101
local MRKR_NICOLIAUX          = 11082102
local MRKR_VKOROLON           = 11082103


function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end


function onStateChange(player, quest, sequence)

	if sequence == SEQ_ACCEPT then
		local hasQuestItem = player:GetItemPackage(INVENTORY_NORMAL):HasItem(ITEM_WANTED_GAUWYN)

		if hasQuestItem == false then
			quest:SetENpc(OTOPA_POTTOPA, QFLAG_TALK)
		end
		quest:SetENpc(THE_ROOST_BED, 5)
		quest:SetENpc(VKOROLON, QFLAG_TALK) -- Always shows despite interaction

	elseif sequence == SEQ_000 then
		quest:SetENpc(VKOROLON)
		quest:SetENpc(NICOLIAUX, QFLAG_TALK)
		quest:SetENpc(POWLE)
		quest:SetENpc(AUNILLIE)
		quest:SetENpc(GAUWYN_THE_GANNET)
		quest:SetENpc(HILDIBRAND)
		quest:SetENpc(NASHU_MHAKARACCA)
		quest:SetENpc(PRIVATE_AREA_ENTRANCE, QFLAG_PUSH, false, true, false, true)

	elseif sequence == SEQ_010 then
		quest:SetENpc(VKOROLON, QFLAG_REWARD)
		quest:SetENpc(NICOLIAUX)
		quest:SetENpc(POWLE)
		quest:SetENpc(AUNILLIE)
		quest:SetENpc(GAUWYN_THE_GANNET)
		quest:SetENpc(HILDIBRAND)
		quest:SetENpc(NASHU_MHAKARACCA)
	end
end

local function talkVkorolonEarly(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent_000_1") -- Educated guess
end

local function talkVkorolonDone(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent_020")
	callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 500, 1, 1)
	player:CompleteQuest(quest)
	-- Log out in Mizzenmast Inn w/ item.
	player:SendGameMessage(player, GetWorldMaster(), 51148, MESSAGE_TYPE_SYSTEM, 10011243, 1070)
end

local function talkNicoliauxFound(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent_010")
	attentionMessage(player, 25225, quest:GetQuestId()) -- objectives complete!
	quest:UpdateENPCs() -- Band-aid for a QFLAG_TALK issue
	quest:StartSequence(SEQ_010)
end

local function talkNicoliauxAfter(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_1") -- Educated guess
end

local talk = {
	[SEQ_ACCEPT] = {
		[OTOPA_POTTOPA] = function(player, quest, npc)
			local hasQuestItem = player:GetItemPackage(INVENTORY_NORMAL):HasItem(ITEM_WANTED_GAUWYN)

			if not hasQuestItem then
				callClientFunction(player, "delegateEvent", player, quest, "processEventOTOPAPOTTOPAStart")
				giveWantedItem(player)
				npc:SetQuestGraphic(player, QFLAG_OFF)
			else
				callClientFunction(player, "delegateEvent", player, quest, "processEventOTOPAPOTTOPAStart_2")
			end
			player:SendGameMessage(player, GetWorldMaster(), 51148, MESSAGE_TYPE_SYSTEM, 10011243, 2075) -- Log out in The Roost w/ item.
		end,
		-- He only gives the log-out hint; no dialog plays.
		[VKOROLON] = function(player)
			player:SendGameMessage(player, GetWorldMaster(), 51148, MESSAGE_TYPE_SYSTEM, 10011243, 2075)
		end,
	},
	[SEQ_010] = {
		[VKOROLON] = talkVkorolonDone,
		[NICOLIAUX] = talkNicoliauxAfter,
	},
}

local function chatter(event)
	return function(player, quest)
		callClientFunction(player, "delegateEvent", player, quest, event)
	end
end

local tavernTalk = {
	[VKOROLON] = talkVkorolonEarly,
	[NICOLIAUX] = talkNicoliauxFound,
}

for _, byNpc in ipairs({ tavernTalk, talk[SEQ_010] }) do
	byNpc[POWLE] = chatter("processEvent_010_5")
	byNpc[AUNILLIE] = chatter("processEvent_010_6")
	byNpc[GAUWYN_THE_GANNET] = chatter("processEvent_010_2")
	byNpc[HILDIBRAND] = chatter("processEvent_010_3")
	byNpc[NASHU_MHAKARACCA] = chatter("processEvent_010_4")
end

-- Every sequence after the offer but SEQ_010 talks as SEQ_000 does.
talk.other = function(player, quest, npc)
	if quest:GetSequence() == SEQ_ACCEPT then
		return
	end
	local handler = tavernTalk[npc:GetActorClassId()]
	if handler ~= nil then
		handler(player, quest, npc)
	end
end

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	local npcClassId = npc:GetActorClassId()

	player:EndEvent()
	if npcClassId == PRIVATE_AREA_ENTRANCE then
		GetWorldManager():WarpToPrivateArea(player, "PrivateAreaMasterPast", 5, -33.709, 7.810, -1272.337, -0.810)
	end
end






function getJournalInformation(player, quest)
end


function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_ACORN_ORCHARD -- TO-DO: Check for private area and use MRKR_NICOLIAUX in place of this
	elseif sequence == SEQ_010 then
		return MRKR_VKOROLON
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