require("Global")
--[[

RequestQuestJournalCommand Script

Functions: None

Notes:

Fires when the player looks at a quest's journal entry and the map section. Check the quest sheet and quest_marker sheet
for valid entries for your quest.

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
