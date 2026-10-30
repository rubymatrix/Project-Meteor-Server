require("Global")

--[[
Grand Company officer: runs the player's GC quests first, then the promotion menu. Rank and cost are
placeholders and a promotion doesn't change the rank yet.
Client functions: Data/Docs/Scripts/Chara/Npc/Populace/PopulaceCompanyOfficer.md.
--]]

function init(npc)
	return false, false, 0, 0
end

local gcOfficer = {
[1500199] = 1, -- Limsa Officer
[1500200] = 2, -- Grid Officer
[1500198] = 3, -- Flame Officer
}

local function doQuestEvent(player, npc, quest, eventType, eventName)
	if eventType == ETYPE_COMMAND then
		quest:OnCommand(player, npc, eventName)
	elseif eventType == ETYPE_TALK then
		quest:OnTalk(player, npc)
	elseif eventType == ETYPE_PUSH then
		quest:OnPush(player, npc, eventName)
	elseif eventType == ETYPE_EMOTE then
		quest:OnEmote(player, npc, eventName)
	elseif eventType == ETYPE_NOTICE then
		quest:OnNotice(player, eventName)
	end
end

local function chooseQuest(player, quests)
	if #quests == 1 then
		return quests[1]
	end
	local currentPage = 0
	local numPages = math.floor((#quests - 1) / 4) + 1
	while true do
		local page, index = callClientFunction(player, "switchEvent", quests[currentPage * 4 + 1], quests[currentPage * 4 + 2], quests[currentPage * 4 + 3], quests[currentPage * 4 + 4], currentPage + 1, numPages, 0x3F1)
		if page == 0 then
			return quests[currentPage * 4 + index]
		elseif page > 0 then
			currentPage = page - 1
		else
			return nil
		end
	end
end

-- Officers give the Grand Company quests, so a quest event comes before the officer menu.
function onEventStarted(player, npc, eventType, eventName)
	local activeQuests = arrayToTable(player:GetQuestsForNpcEvent(npc, eventType))
	if #activeQuests > 0 then
		local quest = chooseQuest(player, activeQuests)
		if quest ~= nil then
			doQuestEvent(player, npc, quest, eventType, eventName)
		else
			player:EndEvent()
		end
		return
	end

	local playerGc = player.gcCurrent
	local playerGcSeal = 1000200 + playerGc
	local playerCurrentRank = 13
	local playerRankUpCost = 1500
	local playerNextRank = 15
	local currentRankCap = 31 -- Second Lieutenant
	local npcId = npc:GetActorClassId()

	if playerGc == gcOfficer[npcId] then
		callClientFunction(player, "eventTalkWelcome")
		if playerCurrentRank < currentRankCap then
			if player:GetItemPackage(INVENTORY_CURRENCY):HasItem(playerGcSeal, playerRankUpCost) then
				local choice = callClientFunction(player, "eventTalkJoined", playerCurrentRank, playerNextRank, true, true)

				if choice == 1 then
					callClientFunction(player, "eventDoRankUp", playerNextRank, playerNextRank)
				end

			else
				callClientFunction(player, "eventTalkJoined", playerCurrentRank, playerNextRank, false, true)
			end
		else
			callClientFunction(player, "eventTalkJoined", playerCurrentRank, playerNextRank)
		end

		callClientFunction(player, "eventTalkJoinedOnly")
	else
		callClientFunction(player, "eventTalkExclusive")
	end
	callClientFunction(player, "eventTalkStepBreak")
	player:EndEvent()
end