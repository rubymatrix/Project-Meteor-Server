--[[
Leaves the player's party.
--]]

function onEventStarted(player, actor, eventType, eventName)
	player:PartyLeave()
	player:EndEvent()
end