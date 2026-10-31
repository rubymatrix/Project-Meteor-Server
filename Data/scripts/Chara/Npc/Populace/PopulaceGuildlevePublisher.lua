require("Global")
require("Guildleve")

--[[
Regional leve counter (Limsa, Gridania, Ul'dah): battlecraft and fieldcraft region packs, their
leve cards and the tutorial leve. Faction credits and history evaluation aren't implemented.
Client functions: Data/Docs/Scripts/Chara/Npc/Populace/PopulaceGuildlevePublisher.md.
--]]

local ACCEPT_OK = 0
local ACCEPT_INVALID = 1
local ACCEPT_ALREADY_HELD = 2
local ACCEPT_JOURNAL_FULL = 3
local ACCEPT_NO_ALLOWANCE = 4

local CLASSTYPE_BATTLECRAFT = 1
local CLASSTYPE_FIELDCRAFT = 2

local MENU_BATTLECRAFT = 1
local MENU_FIELD_MIN = 21
local MENU_FIELD_FSH = 23
local MENU_HISTORY = 5
local MENU_TUTORIAL = 6
local MENU_INFO = 7
local MENU_NOTHING = 8

-- The Tutorial menu is shown while the player's battle level is at most this.
local TUTORIAL_MAX_LEVEL = 10

-- Publisher text sheet lines, said as the NPC (log 0x23) around the cards. Retail says 13 and 14
-- before the first card list and detail of a visit only, and 20 on leaving.
local LOG_NPC_SAY = 0x23
local SAY_LEVES_AVAILABLE = 13
local SAY_THIS_ONE = 14
local SAY_FAREWELL = 20
local SAY_NO_MORE_LEVES = 21

local offerPacks, offerCards, tryAccept, npcSay, hasAnyCard, cardTable

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc)

	local city = GetLevePublisherCity(npc:GetActorClassId(), player.CurrentArea.ZoneId)
	local packBase = GetLeveCityPackBase(city)
	local sayIntro = true
	local visit = {saidCards = false, saidDetail = false, thanked = false}

	while true do
		local level = player:GetLeveBattleLevel()
		local showTutorial = level <= TUTORIAL_MAX_LEVEL

		local choice = callClientFunction(player, "eventTalkType", level, sayIntro, 0, 0, 0, showTutorial, 0, nil, player:GetLeveAllowances(), 0, 0, 0)
		sayIntro = false

		if choice == nil or choice == MENU_NOTHING then
			break
		elseif choice == MENU_BATTLECRAFT then
			-- guildlevePack N01-N07: the city's battlecraft camps.
			offerPacks(player, npc, visit, city, CLASSTYPE_BATTLECRAFT, 0, packBase + 1, packBase + 7)
		elseif choice >= MENU_FIELD_MIN and choice <= MENU_FIELD_FSH then
			-- Fieldcraft MIN 39 / BTN 40 / FSH 41: packs N31-N35, N41-N45, N51-N55. They can be
			-- taken but not started yet.
			local skill = 39 + (choice - MENU_FIELD_MIN)
			local first = packBase + 31 + (skill - 39) * 10
			offerPacks(player, npc, visit, city, CLASSTYPE_FIELDCRAFT, skill, first, first + 4)
		elseif choice == MENU_TUTORIAL then
			local tutorialLeve = GetLeveTutorialId(city)
			if tutorialLeve ~= 0 then
				local cards = function() return {tutorialLeve, 0, 0, 0, 0, 0, 0, 0} end
				offerCards(player, npc, visit, cards(), cards)
			end
		elseif choice == MENU_HISTORY then
			callClientFunction(player, "eventHistoryleveCannot")
		elseif choice == MENU_INFO then
			-- The client ran the info dialogue itself; back to the main menu.
		elseif choice > 40 and choice < 60 then
			player:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, "", "Faction levequests are not available yet.")
		end
	end

	npcSay(player, npc, SAY_FAREWELL)
	player:EndEvent()
end

-- Region (pack) menu, then that pack's cards.
function offerPacks(player, npc, visit, city, classType, skill, firstPack, lastPack)
	if city == 0 then
		return
	end

	while true do
		local packId = callClientFunction(player, "eventTalkPack", firstPack, lastPack)
		if packId == nil or packId < firstPack or packId > lastPack then
			break
		end

		local buildCards = function()
			return cardTable(player:GetRegionalGuildleveCards(packId, classType, skill))
		end

		offerCards(player, npc, visit, buildCards(), buildCards)
	end
end

-- Card list loop; taken cards drop out of the next list.
function offerCards(player, npc, visit, cards, buildCards)
	while true do
		if not hasAnyCard(cards) then
			npcSay(player, npc, SAY_NO_MORE_LEVES)
			break
		end

		if not visit.saidCards then
			npcSay(player, npc, SAY_LEVES_AVAILABLE)
			visit.saidCards = true
		end
		local chosen = callClientFunction(player, "eventTalkCard", cards[1], cards[2], cards[3], cards[4], cards[5], cards[6], cards[7], cards[8])
		if chosen == nil or chosen < 1 or chosen > 8 or cards[chosen] == 0 then
			break
		end

		local glId = cards[chosen]
		if not visit.saidDetail then
			npcSay(player, npc, SAY_THIS_ONE)
			visit.saidDetail = true
		end
		local accepted = callClientFunction(player, "eventTalkDetail", glId, getGuildleveEvaluation(player, glId), 1000001,
			player:GetGuildleveRewardGil(glId), 0, 0, 0, player:HasCompletedGuildleve(glId), nil)

		if accepted ~= nil and accepted ~= false then
			tryAccept(player, glId, visit)
		end

		cards = buildCards()
	end
end

-- Accepts one regional leve, handling a full journal and missing allowances. The first accept of a
-- visit gets the "view your Journal" line at once, before the journal update, as on retail.
function tryAccept(player, glId, visit)
	local worldMaster = GetWorldMaster()
	local result = player:AcceptRegionalGuildleve(glId)

	if result == ACCEPT_JOURNAL_FULL then
		-- Offer to return a held leve; only trust the answer when it names one.
		local toReturn = callClientFunction(player, "eventTalkChangeOne", false)
		if toReturn ~= nil and toReturn ~= 0 and player:HasGuildleve(toReturn) and player:GetGuildleveDirector() == nil then
			player:RemoveGuildleve(toReturn)
			result = player:AcceptRegionalGuildleve(glId)
		else
			player:SendGameMessage(worldMaster, 50143, 0x20)
			return false
		end
	end

	if result == ACCEPT_OK then
		if not visit.thanked then
			callClientFunction(player, "eventTalkAfterOffer")
			visit.thanked = true
		end
		return true
	elseif result == ACCEPT_NO_ALLOWANCE then
		player:SendGameMessage(worldMaster, 50142, 0x20)
	elseif result == ACCEPT_ALREADY_HELD then
		callClientFunction(player, "eventHistoryleveExist", glId)
	elseif result == ACCEPT_JOURNAL_FULL then
		player:SendGameMessage(worldMaster, 50143, 0x20)
	end
	return false
end

function npcSay(player, npc, line)
	if npc ~= nil and npc.LocalizedDisplayName ~= nil and npc.LocalizedDisplayName > 0 then
		player:SendGameMessageLocalizedDisplayName(npc, line, LOG_NPC_SAY, npc.LocalizedDisplayName)
	end
end

function hasAnyCard(cards)
	for i = 1, 8 do
		if cards[i] ~= nil and cards[i] ~= 0 then
			return true
		end
	end
	return false
end

function cardTable(clrArray)
	local t = arrayToTable(clrArray)
	for i = 1, 8 do
		t[i] = t[i] or 0
	end
	return t
end
