--[[

LinkshellAppointCommand Script

--]]

function onEventStarted(player, actor, eventType, eventName, linkshellName, memberName, rank)

	GetWorldManager():RequestWorldLinkshellRankChange(player, linkshellName, memberName, rank)
	player:EndEvent()

end