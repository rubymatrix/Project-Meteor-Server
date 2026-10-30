--[[

LinkshellLeaveCommand Script

--]]

function onEventStarted(player, actor, eventType, eventName, linkshellName)

	GetWorldManager():RequestWorldLinkshellLeave(player, linkshellName)
	player:EndEvent()

end