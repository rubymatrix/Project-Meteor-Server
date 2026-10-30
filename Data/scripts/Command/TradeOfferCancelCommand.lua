--[[
Cancels the player's open trade.
--]]

function onEventStarted(player, actor, eventType, eventName, commandId, result)

	GetWorldManager():CancelTrade(player)
	player:EndEvent()

end