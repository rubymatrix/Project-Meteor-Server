--[[

LinkshellKickCommand Script

--]]

function onEventStarted(player, actor, eventType, eventName, linkshellName, kickedName)

	GetWorldManager():RequestWorldLinkshellKick(player, linkshellName, kickedName)
	player:EndEvent()

end