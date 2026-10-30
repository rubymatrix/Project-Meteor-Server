require("Global")

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, eventType, eventName)
	player:EndEvent()
end