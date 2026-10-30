--[[

LinkshellChangeCommand Script

--]]

function onEventStarted(player, actor, eventType, eventName, linkshellName, arg1, arg2)

	if linkshellName == nil then
		linkshellName = ""
	end
	GetWorldManager():RequestWorldLinkshellChangeActive(player, linkshellName)
	player:EndEvent()

end