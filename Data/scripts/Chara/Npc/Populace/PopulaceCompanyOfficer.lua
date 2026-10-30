require("Global")

--[[

PopulaceCompanyOfficer Script

xtx_gcRank for GC Rank values

Functions:

eventTalkWelcome()                              - Welcome dialog
eventTalkWelcomeQuest()                         - Same as Welcome dialog?
eventTalkPreJoin()                              - Dialog for starting GC rank?
eventTalkExclusive()                            - Dialog to play when you're not of that GC?
eventTalkJoinedOnly()                           - Reads like chat-end dialog for your GC.
eventTalkJoined(gcRank, gcRank,  isCanAfford, isShowPromotion)  - Menu to ask about/for promotion

eventDoRankUp(gcRank, gcRank)                   - Plays rank-up animation and opens GC window. 
eventRankUpDone(???, ???)                       - Has your character do the GC salute?  Values seem to do nothing?
eventRankCategoryUpBefore(gcRank)               - 11/21/31  - Mentions which GC quest you need to clear to continue promotion
eventRankCategoryUpAfter()                      - Follow-up dialog after ranking up
eventTalkQuestUncomplete()                      - Quest prerequisite dialog for ranking up to Second Lieutenant (1.23b rank cap)
eventTalkFestival()                             - Foundation Day 2011 event dialog.  Server needs to reward 1000 GC seals after.
eventTalkFestival2()                            - Foundation Day 2011 event dialog.  Seems to reward more seals, unsure how many.
eventTalkFestival2012(value)                    - Foundation Day 2012 event dialog.  Rewards amount of seals dictated by value, retail used 5000.

eventTalkStepBreak()                            - Resets NPC target/facing
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
				-- Show Promotion window, allow paying
				local choice = callClientFunction(player, "eventTalkJoined", playerCurrentRank, playerNextRank, true, true)

				-- If promotion accepted
				if choice == 1 then
					callClientFunction(player, "eventDoRankUp", playerNextRank, playerNextRank)
				   -- TODO: Table GC info or get it in source/sql.  Handle actual upgrade of GC rank/seal cap/cost/etc.
				end

			else
				-- Show Promotion window, show dialog you can't afford promotion
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