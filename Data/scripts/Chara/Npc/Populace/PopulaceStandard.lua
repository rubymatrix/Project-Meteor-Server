require("Global")

local doQuestEvent

--[[

Populace Standard Script

Functions: 

eventSwitch(questId1, questId2, questId3, questId4, currentPage, maxPages, titleId)	- Shows a dialog box with which quest to trigger 
																					  when more than one quest is active for this npc.

Notes:

This scripts fires for all normal standard ENpcs in the world. Because of how the FFXIV dialog system works, everything is technically
a quest; including the DefaultTalk responses. This script checks both static default quests and any relevant ones for that actor class
id. If only one exists; it is automatically triggered otherwise a dialog box will appear for the player to choose what quest to do.

--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, eventType, eventName)
	local chosenQuest = nil

	if eventName == "talkDefault" and eventType ~= ETYPE_TALK then
		printf("PopulaceStandard: talkDefault on %s arrived with event type %s; closed without a scene.", tostring(npc:GetActorClassId()), tostring(eventType))
		player:EndEvent()
		return
	end

	if eventType == 1 then
		local defaultTalk = player:GetDefaultTalkQuest(npc)
		local tutorialTalk = player:GetTutorialQuest(npc)
		local activeQuests = arrayToTable(player:GetQuestsForNpc(npc))
		local possibleQuests = {}

		-- Create the switch table for this npc
		if defaultTalk ~= nil and eventType == ETYPE_TALK then
			table.insert(possibleQuests, defaultTalk)
		end
		if tutorialTalk ~= nil and eventType == ETYPE_TALK then
			table.insert(possibleQuests, tutorialTalk)
		end
		if activeQuests ~= nil then
			for i=1,#activeQuests do
				table.insert(possibleQuests, activeQuests[i])
			end
		end

		-- Either let the player choose the quest or start it if it's the only one.
		if #activeQuests > 0 and npc.CurrentArea:IsPrivate() then
			chosenQuest = activeQuests[1]
		elseif #possibleQuests > 1 then
			local currentPage = 0
			local numPages = math.floor((#possibleQuests-1)/4) + 1

			while true do
				local page, index = callClientFunction(player, "switchEvent", possibleQuests[currentPage * 4 + 1], possibleQuests[currentPage * 4 + 2], possibleQuests[currentPage * 4 + 3], possibleQuests[currentPage * 4 + 4], currentPage + 1, numPages, 0x3F1)

				if page == 0 then
					chosenQuest = possibleQuests[(currentPage * 4) + index]
					break
				elseif page > 0 then
					currentPage = page - 1
				else
					player:EndEvent()
					return
				end
			end
		elseif #possibleQuests == 1 then
			chosenQuest = possibleQuests[1]
		end
	else
		local activeQuests = arrayToTable(player:GetQuestsForNpc(npc))
		if #activeQuests ~= 0 then
			chosenQuest = activeQuests[1]
		end
	end

	-- Run the quest event or tell the devs it's missing.
	if chosenQuest ~= nil then
		doQuestEvent(player, npc, chosenQuest, eventType, eventName)
	else
		local msg = string.format("ERROR: This PopulaceStandard actor has no defaultTalk or quest set. \nActor Class Id: %s\nEvent Name: %s", tostring(npc:GetActorClassId()), eventName)
		printf(msg)
		player:SendMessage(0x20, "", msg)
		player:EndEvent()
	end
end

function doQuestEvent(player, npc, quest, eventType, eventName)
	if eventType == 0 then
		quest:OnCommand(player, npc, eventName)
	elseif eventType == 1 then
		quest:OnTalk(player, npc)
	elseif eventType == 2 then
		quest:OnPush(player, npc, eventName)
	elseif eventType == 3 then
		quest:OnEmote(player, npc, eventName)
	elseif eventType == 5 then
		quest:OnNotice(player, eventName)
	end
end