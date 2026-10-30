require("Global")

--[[

JournalCommand Script

Fired when you try to abandon a quest

--]]

function onEventStarted(player, command, eventType, eventName, questId)

	player:AbandonQuest(questId)
	player:EndEvent()

end