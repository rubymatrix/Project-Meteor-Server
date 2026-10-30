--[[

PartyResignCommand Script

Handles leaving a party

--]]

function onEventStarted(player, actor, eventType, eventName)
	player:PartyLeave()
	player:EndEvent()
end