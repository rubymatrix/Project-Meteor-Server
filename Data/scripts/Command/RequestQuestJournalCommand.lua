require("Global")

--[[
Fires when the player opens a quest's journal entry or its map. Valid entries come from the quest
and quest_marker sheets.
--]]

function onEventStarted(player, command, eventType, eventName, questId, mapCode)
	local quest = player:GetQuest(questId)

	if quest ~= nil then
		if mapCode == nil then
			-- Get Quest Journal Data
			local journalInfo = quest:GetJournalInformation()
			player:SendDataPacket("requestedData", "qtdata", quest:GetQuestId(), quest:GetSequence(), unpack(arrayToTable(journalInfo)))
		else
			-- Get Quest Map Data
			local mapMarkers = quest:GetJournalMapMarkerList()
			player:SendDataPacket("requestedData", "qtmap", quest:GetQuestId(), unpack(arrayToTable(mapMarkers)))
		end
	end

	player:EndEvent()
end
