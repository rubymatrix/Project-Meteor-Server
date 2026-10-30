require("Global")
require("Quest")
require("QuestFlow")

--[[
Showdown (Cul200, 110440). Culinarian level 20; offered by Charlys at the Bismarck.
The player helps one chef, and only that chef's dish counts. Each baseline counter holds the dishes
owned at the offer, so only a dish cooked afterwards counts. Walkthrough: Data/Docs/Scripts/Quest/Cul/Cul200.md.
--]]

local SEQ_005 = 5

local CHARLYS         = 1000138
local PRUDENTIA       = 1000168
local PULMIA          = 1000169
local FINALE_TRIGGER  = 1090008 -- spawn cul200_finale_trigger (Limsa Lominsa)

local MRKR_PRUDENTIA  = 11044001
local MRKR_PULMIA     = 11044002
local MRKR_PRUDENTIA2 = 11044003
local MRKR_PULMIA2    = 11044004
local MRKR_FINALE     = 11044007
local MRKR_PRUDENTIA4 = 11044008

local ITEM_PIPING_HOT_PIE_CRUST = 11000069
local ITEM_AROMATIC_PATE        = 11000070

local FLAG_CHOSE_CRUST    = 0
local FLAG_CHOSE_PATE     = 1
local FLAG_DISH_DELIVERED = 2

local CNTR_CRUST_BASELINE = 0
local CNTR_PATE_BASELINE  = 1

-- Completion pay: the client reward sheet has no row for this quest (questflow.lua turnInQuest).
local COMPLETION_REWARDS = { exp = 1760, gil = 15000 }

-- A synthesis result is quality 1 or 2. The phase-table test runs with a stand-in player that has no
-- inventory.
local function ownedCount(player, itemId)
	if player.GetItemPackage == nil then
		return 0
	end
	local bag = player:GetItemPackage(INVENTORY_NORMAL)
	local total = 0
	for quality = 1, 2 do
		local n = 0
		while n < 99 and bag:HasItem(itemId, n + 1, quality) do
			n = n + 1
		end
		total = total + n
	end
	return total
end

local function removeOne(player, itemId)
	local bag = player:GetItemPackage(INVENTORY_NORMAL)
	for quality = 1, 2 do
		if bag:HasItem(itemId, 1, quality) then
			bag:RemoveItem(itemId, 1, quality)
			return
		end
	end
end


local function isChoicePending(player, quest, data)
	return not data:GetFlag(FLAG_CHOSE_CRUST) and not data:GetFlag(FLAG_CHOSE_PATE)
end

local function isDishDelivered(player, quest, data)
	return data:GetFlag(FLAG_DISH_DELIVERED)
end

local function isCrustPending(player, quest, data)
	return data:GetFlag(FLAG_CHOSE_CRUST) and not data:GetFlag(FLAG_DISH_DELIVERED)
end

local function isPatePending(player, quest, data)
	return data:GetFlag(FLAG_CHOSE_PATE) and not data:GetFlag(FLAG_DISH_DELIVERED)
end

local function isPrudentiaWaiting(player, quest, data)
	return isChoicePending(player, quest, data) or isCrustPending(player, quest, data)
end

local function isPulmiaWaiting(player, quest, data)
	return isChoicePending(player, quest, data) or isPatePending(player, quest, data)
end

local function isCrustCooked(player, quest)
	return ownedCount(player, ITEM_PIPING_HOT_PIE_CRUST) > getQuestCounter(quest, CNTR_CRUST_BASELINE)
end

local function isPateCooked(player, quest)
	return ownedCount(player, ITEM_AROMATIC_PATE) > getQuestCounter(quest, CNTR_PATE_BASELINE)
end

local PHASES = {
	[SEQ_005] = {
		enpcs = {
			{ PRUDENTIA, QFLAG_TALK, when = isPrudentiaWaiting },
			{ PULMIA, QFLAG_TALK, when = isPulmiaWaiting },
			{ FINALE_TRIGGER, QFLAG_PUSH, when = isDishDelivered, talk = false, push = isDishDelivered, spawn = true },
		},
		markers = {
			{ MRKR_PRUDENTIA, when = isChoicePending },
			{ MRKR_PULMIA, when = isChoicePending },
			{ MRKR_PRUDENTIA2, when = isCrustPending },
			{ MRKR_PULMIA2, when = isPatePending },
			{ MRKR_FINALE, when = isDishDelivered },
			{ MRKR_PRUDENTIA4, when = isDishDelivered },
		},
	},
}

-- The challenge opens at once, so the dishes held now are the baselines.
function onStart(player, quest)
	local data = quest:GetData()
	data:SetCounter(CNTR_CRUST_BASELINE, ownedCount(player, ITEM_PIPING_HOT_PIE_CRUST))
	data:SetCounter(CNTR_PATE_BASELINE, ownedCount(player, ITEM_AROMATIC_PATE))
	quest:StartSequence(SEQ_005)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(CHARLYS, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

-- Each chef's first talk carries the question, and only a yes picks that chef.
local function chefTalk(player, quest, data, classId)
	if data == nil then
		return
	end
	if isChoicePending(player, quest, data) then
		if classId == PRUDENTIA and delegateEvent(player, quest, "processEvent015") == 1 then
			setQuestFlagOn(quest, FLAG_CHOSE_CRUST)
		elseif classId == PULMIA and delegateEvent(player, quest, "processEvent017") == 1 then
			setQuestFlagOn(quest, FLAG_CHOSE_PATE)
		end
	elseif classId == PRUDENTIA and isCrustPending(player, quest, data) and isCrustCooked(player, quest) then
		delegateEvent(player, quest, "processEvent010")
		if isCrustCooked(player, quest) then
			removeOne(player, ITEM_PIPING_HOT_PIE_CRUST)
			setQuestFlagOn(quest, FLAG_DISH_DELIVERED)
		end
	elseif classId == PULMIA and isPatePending(player, quest, data) and isPateCooked(player, quest) then
		delegateEvent(player, quest, "processEvent020")
		if isPateCooked(player, quest) then
			removeOne(player, ITEM_AROMATIC_PATE)
			setQuestFlagOn(quest, FLAG_DISH_DELIVERED)
		end
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[CHARLYS] = function(player, quest)
			local accepted = delegateEvent(player, quest, "processEventCharlysStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return true
		end,
	},
	[SEQ_005] = {
		[PRUDENTIA] = function(player, quest, npc, data) chefTalk(player, quest, data, PRUDENTIA) end,
		[PULMIA] = function(player, quest, npc, data) chefTalk(player, quest, data, PULMIA) end,
		other = function(player, quest, npc, data) chefTalk(player, quest, data, nil) end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc, quest:GetData()) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc, eventName)
	local data = quest:GetData()
	if quest:GetSequence() == SEQ_005 and data ~= nil and data:GetFlag(FLAG_DISH_DELIVERED)
		and npcName(npc) == "cul200_finale_trigger" then
		turnInQuest(player, quest, "processEvent030", COMPLETION_REWARDS)
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onNotice(player, quest, target)
	player:EndEvent()
	quest:UpdateENPCs()
end

-- The journal counts the delivery, never a stored copy of the dish.
-- A craft or a catch shows on the icons and markers at once (the server's inventory hook); the talks and
-- pushes still read the inventory, so a missed call changes nothing.
function onItemGained(player, quest, itemId, quantity, quality)
	for _, watched in ipairs({ ITEM_PIPING_HOT_PIE_CRUST, ITEM_AROMATIC_PATE }) do
		if itemId == watched then
			quest:UpdateENPCs()
			return
		end
	end
end

function getJournalInformation(player, quest)
	if quest:GetSequence() ~= SEQ_005 then
		return 0, 0, 0, 0, 0
	end
	return getQuestFlag(quest, FLAG_DISH_DELIVERED) and 1 or 0, 0, 0, 0, 1
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
