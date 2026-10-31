require("Global")

--[[
Local levequest (crafting leve) publisher: turns in finished leves of this city, then offers class,
rank and leve cards. Client functions:
Data/Docs/Scripts/Chara/Npc/Populace/PopulacePassiveGLPublisher.md.
--]]

local ACCEPT_OK = 0
local ACCEPT_INVALID = 1
local ACCEPT_ALREADY_HELD = 2
local ACCEPT_JOURNAL_FULL = 3
local ACCEPT_NO_ALLOWANCE = 4

local LOCAL_LEVE_SLOTS = 8

local turnInLeves, offerLoop, offerCards, discardOne, toLocalQuestId, cardTable

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)

	local city = GetLevePublisherCity(npc:GetActorClassId(), player.CurrentArea.ZoneId)

	callClientFunction(player, "talkOfferWelcome", player, player:GetLeveAllowances())

	-- Leves that used up every attempt without meeting the objective become failed.
	for _, questId in ipairs(arrayToTable(player:GetLocalGuildlevesToFail())) do
		player:FailLocalGuildleve(questId)
	end

	turnInLeves(player, city)

	if city ~= 0 then
		offerLoop(player, city)
	end

	callClientFunction(player, "finishTalkTurn")
	player:EndEvent()
end

function turnInLeves(player, city)
	for _, questId in ipairs(arrayToTable(player:GetLocalGuildlevesToTurnIn(city))) do
		local progress = player:GetQuestGuildleve(questId)
		if progress ~= nil then
			local exchange = callClientFunction(player, "confirmJournal", questId, progress:GetCurrentDifficulty() + 1, 0,
				progress:GetCurrentCrafted(), progress:GetRemainingMaterials(), 1, 0)
			if exchange == true and not player:CompleteLocalGuildleve(questId) then
				player:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, "", "Your inventory is full. Make room to receive the reward.")
			end
		end
	end
end

function offerLoop(player, city)
	while true do
		local classChoice = callClientFunction(player, "askOfferPack", player)
		if classChoice == nil or classChoice < 1 or classChoice > 8 then
			break
		end

		while true do
			local rank = callClientFunction(player, "askOfferRank", player)
			if rank == nil or rank < 1 or rank > 3 then
				break
			end

			if not offerCards(player, city, classChoice, rank) then
				return
			end
		end
	end
end

-- Returns false to leave the whole menu (Cancel), true to go back to the rank menu.
function offerCards(player, city, classChoice, rank)
	local worldMaster = GetWorldMaster()

	while true do
		local count = player:GetLocalGuildleveCardCount(city, classChoice, rank)
		if count == 0 then
			player:SendMessage(MESSAGE_TYPE_SYSTEM, "", "There are currently no guildleves of this type available.")
			return true
		end

		-- The client fixes each slot's difficulty as 1,2,3,4,1,2,3,4, so each leve fills four slots.
		local cards = cardTable(player:GetLocalGuildleveCards(city, classChoice, rank))
		local chosen = callClientFunction(player, "askOfferQuest", player, count,
			cards[1], cards[2], cards[3], cards[4], cards[5], cards[6], cards[7], cards[8])

		if chosen == nil then
			return false
		elseif chosen < 1 or chosen > 8 or cards[chosen] == 0 then
			return true
		end

		local questId = cards[chosen]
		local tier = player:GetLocalGuildleveCardTier(chosen)

		if player:GetLocalGuildleveCount() >= LOCAL_LEVE_SLOTS and not discardOne(player) then
			callClientFunction(player, "talkOfferMaxOver")
			return true
		end

		if player:GetLeveAllowances() < 1 then
			player:SendGameMessage(worldMaster, 50142, 0x20)
			return true
		end

		local confirmed = true
		if player:GetLocalGuildleveCount() == LOCAL_LEVE_SLOTS - 1 then
			confirmed = callClientFunction(player, "confirmMaxOffer", player)
		end

		if confirmed == true then
			confirmed = callClientFunction(player, "confirmOffer", player, questId)
		end

		if confirmed == true then
			local result = player:AcceptLocalGuildleve(questId, tier)
			if result == ACCEPT_OK then
				callClientFunction(player, "talkOfferDecide")
				player:SendGameMessage(worldMaster, 50141, 0x20, player:GetLeveAllowances())
			elseif result == ACCEPT_NO_ALLOWANCE then
				player:SendGameMessage(worldMaster, 50142, 0x20)
			elseif result == ACCEPT_JOURNAL_FULL then
				callClientFunction(player, "talkOfferMaxOver")
			else
				player:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, "", "This levequest cannot be accepted.")
			end
			return true
		end
	end
end

-- Journal full: offer to return a held local leve. Returns true if one was returned.
function discardOne(player)
	if callClientFunction(player, "askDiscardGuildleve") ~= true then
		return false
	end

	local questId = toLocalQuestId(callClientFunction(player, "selectDiscardGuildleve", player))
	if questId == nil or not player:HasGuildleve(questId) then
		return false
	end

	if callClientFunction(player, "confirmDiscardGuildleve", nil, questId, nil) ~= true then
		return false
	end

	player:RemoveGuildleve(questId)
	return true
end

-- selectDiscardGuildleve returns the picked leve's quest actor; accept an actor, an actor id
-- (0xA0F00000 | questId) or a bare quest id.
function toLocalQuestId(value)
	if value == nil then
		return nil
	end
	if type(value) == "userdata" then
		local ok, id = pcall(function() return value.Id end)
		if not ok or id == nil then
			return nil
		end
		value = id
	end
	value = tonumber(value)
	if value == nil then
		return nil
	end
	if value >= 0xA0F00000 then
		value = value - 0xA0F00000
	end
	if value > 120000 and value < 130000 then
		return value
	end
	return nil
end

function cardTable(clrArray)
	local t = arrayToTable(clrArray)
	for i = 1, 8 do
		t[i] = t[i] or 0
	end
	return t
end
