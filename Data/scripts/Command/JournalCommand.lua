require("Global")

--[[
Abandons a quest from the journal.
--]]

function onEventStarted(player, command, eventType, eventName, questId)

	player:AbandonQuest(questId)
	player:EndEvent()

end